import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../agent/agent_snapshot_reader.dart';
import '../approvals/approval_state_controller.dart';
import '../config/codex_config_snapshot_reader.dart';
import '../events/codex_event.dart';
import '../ssh/ssh_profile.dart';
import '../threads/thread_detail_reader.dart';
import '../threads/thread_list_reader.dart';
import '../threads/thread_mutation_runner.dart';
import '../turns/turn_runner.dart';
import 'codex_session_connector.dart';
import 'reconnect_policy.dart';

enum CodexSessionStatus {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnecting,
  failed,
}

class CodexSessionStateController extends ChangeNotifier {
  CodexSessionStateController({
    required CodexSessionConnectionStarter connector,
    required this.approvalController,
    ReconnectPolicy? reconnectPolicy,
    ReconnectDelayScheduler reconnectDelayScheduler =
        const TimerReconnectDelayScheduler(),
    bool autoReconnect = true,
    AgentSnapshotReader? snapshotReader,
  }) : _connector = connector,
       _reconnectPolicy = reconnectPolicy ?? ReconnectPolicy(),
       _reconnectDelayScheduler = reconnectDelayScheduler,
       _autoReconnect = autoReconnect,
       _snapshotReader = snapshotReader;

  final CodexSessionConnectionStarter _connector;
  final ReconnectPolicy _reconnectPolicy;
  final ReconnectDelayScheduler _reconnectDelayScheduler;
  final bool _autoReconnect;
  final AgentSnapshotReader? _snapshotReader;
  final ApprovalStateController approvalController;
  final StreamController<CodexEvent> _eventsController =
      StreamController.broadcast();
  final Set<String> _seenEventFingerprints = <String>{};
  final List<String> _seenEventOrder = <String>[];
  CodexSessionConnectionHandle? _connection;
  StreamSubscription<CodexEvent>? _eventSubscription;
  CodexSessionStatus _status = CodexSessionStatus.idle;
  SshProfile? _profile;
  Object? _error;
  int _generation = 0;
  int _reconnectAttempt = 0;
  Duration? _nextReconnectDelay;
  bool _disposed = false;

  CodexSessionStatus get status => _status;

  bool get isConnected => _status == CodexSessionStatus.connected;

  SshProfile? get profile => _profile;

  Object? get error => _error;

  ThreadListReader? get threadListReader => _connection?.threadListReader;

  ThreadDetailReader? get threadDetailReader => _connection?.threadDetailReader;

  CodexConfigSnapshotReader? get configSnapshotReader =>
      _connection?.configSnapshotReader;

  ThreadMutationRunner? get threadMutationRunner =>
      _connection?.threadMutationRunner;

  TurnRunner? get turnRunner => _connection?.turnRunner;

  Stream<CodexEvent>? get events => _eventsController.stream;

  int get reconnectAttempt => _reconnectAttempt;

  Duration? get nextReconnectDelay => _nextReconnectDelay;

  Future<void> connect(SshProfile profile) async {
    if (_status == CodexSessionStatus.connecting ||
        _status == CodexSessionStatus.disconnecting) {
      throw StateError('A session transition is already in progress');
    }

    final generation = ++_generation;
    final existingConnection = _connection;
    if (existingConnection != null) {
      _connection = null;
      _detachConnectionEvents();
      await existingConnection.close();
    }
    _clearSeenEvents();

    _reconnectAttempt = 0;
    _nextReconnectDelay = null;
    _setState(status: CodexSessionStatus.connecting, profile: profile);

    try {
      final connection = await _connector.connect(
        profile,
        approvalController: approvalController,
      );
      if (!_isCurrentGeneration(generation)) {
        await connection.close(notifyApprovalController: false);
        return;
      }
      _activateConnection(connection, profile, generation);
      if (!_isCurrentGeneration(generation) || _connection != connection) {
        return;
      }
      _setState(status: CodexSessionStatus.connected, profile: profile);
    } on Object catch (error) {
      if (!_isCurrentGeneration(generation)) {
        return;
      }
      _connection = null;
      _detachConnectionEvents();
      _setState(
        status: CodexSessionStatus.failed,
        profile: profile,
        error: error,
      );
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _generation++;
    final connection = _connection;
    if (connection == null) {
      _reconnectAttempt = 0;
      _nextReconnectDelay = null;
      _setState(status: CodexSessionStatus.idle);
      return;
    }

    _setState(status: CodexSessionStatus.disconnecting);
    try {
      _detachConnectionEvents();
      await connection.close();
    } finally {
      _connection = null;
      _reconnectAttempt = 0;
      _nextReconnectDelay = null;
      _setState(status: CodexSessionStatus.idle);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_eventSubscription?.cancel());
    unawaited(_connection?.close(notifyApprovalController: false));
    _connection = null;
    unawaited(_eventsController.close());
    super.dispose();
  }

  void _watchConnectionDone(
    CodexSessionConnectionHandle connection,
    int generation,
  ) {
    unawaited(
      connection.done.then(
        (_) => _handleConnectionDone(connection, generation),
        onError: (Object error, StackTrace stackTrace) =>
            _handleConnectionDone(connection, generation, error),
      ),
    );
  }

  Future<void> _handleConnectionDone(
    CodexSessionConnectionHandle connection,
    int generation, [
    Object? error,
  ]) async {
    if (!_isCurrentGeneration(generation) || _connection != connection) {
      return;
    }

    _connection = null;
    _detachConnectionEvents();
    await connection.close();
    if (!_isCurrentGeneration(generation)) {
      return;
    }

    final reconnectProfile = _profile;
    if (!_autoReconnect || reconnectProfile == null) {
      _setState(status: CodexSessionStatus.failed, error: error);
      return;
    }

    unawaited(_reconnect(reconnectProfile, generation, error));
  }

  Future<void> _reconnect(
    SshProfile profile,
    int generation,
    Object? error,
  ) async {
    var lastError = error;
    while (_isCurrentGeneration(generation)) {
      _reconnectAttempt++;
      final delay = _reconnectPolicy.delayForAttempt(_reconnectAttempt);
      _nextReconnectDelay = delay;
      _setState(
        status: CodexSessionStatus.reconnecting,
        profile: profile,
        error: lastError,
      );

      await _reconnectDelayScheduler.wait(delay);
      if (!_isCurrentGeneration(generation)) {
        return;
      }

      try {
        final connection = await _connector.connect(
          profile,
          approvalController: approvalController,
        );
        if (!_isCurrentGeneration(generation)) {
          await connection.close(notifyApprovalController: false);
          return;
        }
        _activateConnection(connection, profile, generation);
        if (!_isCurrentGeneration(generation) || _connection != connection) {
          return;
        }
        _reconnectAttempt = 0;
        _nextReconnectDelay = null;
        _setState(status: CodexSessionStatus.connected, profile: profile);
        return;
      } on Object catch (error) {
        lastError = error;
      }
    }
  }

  void _activateConnection(
    CodexSessionConnectionHandle connection,
    SshProfile profile,
    int generation,
  ) {
    _connection = connection;
    _attachConnectionEvents(connection);
    _watchConnectionDone(connection, generation);
    unawaited(_backfillAgentSnapshot(profile, generation, connection));
  }

  void _attachConnectionEvents(CodexSessionConnectionHandle connection) {
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = connection.events.listen(
      _emitLiveEvent,
      onError: _eventsController.addError,
    );
  }

  void _detachConnectionEvents() {
    final subscription = _eventSubscription;
    _eventSubscription = null;
    unawaited(subscription?.cancel());
  }

  Future<void> _backfillAgentSnapshot(
    SshProfile profile,
    int generation,
    CodexSessionConnectionHandle connection,
  ) async {
    final snapshotReader = _snapshotReader;
    if (snapshotReader == null) {
      return;
    }

    try {
      final snapshot = await snapshotReader.readSnapshot(profile);
      if (!_isCurrentGeneration(generation) || _connection != connection) {
        return;
      }
      approvalController.ingestServerRequests(snapshot.pendingApprovals);
      for (final cachedEvent in snapshot.recentEvents) {
        if (cachedEvent.method.isEmpty) {
          continue;
        }
        _emitSnapshotEvent(
          CodexEvent.fromNotification(cachedEvent.toNotification()),
        );
      }
    } on Object catch (_) {
      return;
    }
  }

  void _emitLiveEvent(CodexEvent event) {
    _rememberEvent(event);
    _eventsController.add(event);
  }

  void _emitSnapshotEvent(CodexEvent event) {
    if (!_rememberEvent(event)) {
      return;
    }
    _eventsController.add(event);
  }

  bool _rememberEvent(CodexEvent event) {
    final fingerprint = _eventFingerprint(event);
    if (fingerprint == null) {
      return true;
    }
    if (!_seenEventFingerprints.add(fingerprint)) {
      return false;
    }
    _seenEventOrder.add(fingerprint);
    const limit = 512;
    if (_seenEventOrder.length > limit) {
      final removed = _seenEventOrder.removeAt(0);
      _seenEventFingerprints.remove(removed);
    }
    return true;
  }

  String? _eventFingerprint(CodexEvent event) {
    try {
      return jsonEncode(event.raw);
    } on Object {
      return null;
    }
  }

  void _clearSeenEvents() {
    _seenEventFingerprints.clear();
    _seenEventOrder.clear();
  }

  bool _isCurrentGeneration(int generation) {
    return !_disposed && generation == _generation;
  }

  void _setState({
    required CodexSessionStatus status,
    SshProfile? profile,
    Object? error,
  }) {
    _status = status;
    _profile = profile ?? _profile;
    _error = error;
    notifyListeners();
  }
}
