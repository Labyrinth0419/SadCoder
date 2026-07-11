import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../accounts/account_logout_runner.dart';
import '../accounts/account_snapshot_reader.dart';
import '../agent/agent_snapshot.dart';
import '../agent/agent_snapshot_reader.dart';
import '../apps/app_list_reader.dart';
import '../approvals/approval_state_controller.dart';
import '../background_terminals/thread_background_terminal_runner.dart';
import '../commands/slash_command_manifest_reader.dart';
import '../command_exec/command_exec_runner.dart';
import '../config/codex_config_snapshot_reader.dart';
import '../diffs/git_diff_reader.dart';
import '../events/codex_event.dart';
import '../feedback/feedback_upload_runner.dart';
import '../files/file_search_reader.dart';
import '../files/workspace_directory_reader.dart';
import '../files/workspace_file_reader.dart';
import '../goals/thread_goal_runner.dart';
import '../hooks/hook_list_reader.dart';
import '../mcp/mcp_server_config_runner.dart';
import '../mcp/mcp_server_oauth_runner.dart';
import '../mcp/mcp_server_status_reader.dart';
import '../models/model_list_reader.dart';
import '../permissions/permission_profile_list_reader.dart';
import '../plugins/plugin_detail_reader.dart';
import '../plugins/plugin_list_reader.dart';
import '../plugins/plugin_mutation_runner.dart';
import '../protocol/json_rpc_diagnostic_log.dart';
import '../reviews/thread_review_runner.dart';
import '../skills/skill_list_reader.dart';
import '../ssh/ssh_profile.dart';
import '../threads/thread_detail_reader.dart';
import '../threads/thread_item_list_reader.dart';
import '../threads/thread_list_reader.dart';
import '../threads/thread_mutation_runner.dart';
import '../threads/thread_shell_command_runner.dart';
import '../threads/thread_turn_list_reader.dart';
import '../turns/turn_runner.dart';
import '../usage/account_usage_snapshot_reader.dart';
import 'codex_session_connector.dart';
import 'reconnect_policy.dart';
import 'session_heartbeat.dart';

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
    List<SessionHeartbeatChannel> heartbeatChannels = const [],
    SessionHeartbeatScheduler heartbeatScheduler =
        const TimerSessionHeartbeatScheduler(),
  }) : _connector = connector,
       _reconnectPolicy = reconnectPolicy ?? ReconnectPolicy(),
       _reconnectDelayScheduler = reconnectDelayScheduler,
       _autoReconnect = autoReconnect,
       _snapshotReader = snapshotReader,
       _heartbeatChannels = List.unmodifiable(heartbeatChannels),
       _heartbeatScheduler = heartbeatScheduler;

  final CodexSessionConnectionStarter _connector;
  final ReconnectPolicy _reconnectPolicy;
  final ReconnectDelayScheduler _reconnectDelayScheduler;
  final bool _autoReconnect;
  final AgentSnapshotReader? _snapshotReader;
  final List<SessionHeartbeatChannel> _heartbeatChannels;
  final SessionHeartbeatScheduler _heartbeatScheduler;
  final ApprovalStateController approvalController;
  final StreamController<CodexEvent> _eventsController =
      StreamController.broadcast();
  final Set<String> _seenEventFingerprints = <String>{};
  final List<String> _seenEventOrder = <String>[];
  CodexSessionConnectionHandle? _connection;
  StreamSubscription<CodexEvent>? _eventSubscription;
  final List<SessionHeartbeatHandle> _heartbeatHandles = [];
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

  ThreadTurnListReader? get threadTurnListReader =>
      _connection?.threadTurnListReader;

  ThreadItemListReader? get threadItemListReader =>
      _connection?.threadItemListReader;

  CodexConfigSnapshotReader? get configSnapshotReader =>
      _connection?.configSnapshotReader;

  AccountSnapshotReader? get accountSnapshotReader =>
      _connection?.accountSnapshotReader;

  AccountLogoutRunner? get accountLogoutRunner =>
      _connection?.accountLogoutRunner;

  AccountUsageSnapshotReader? get accountUsageSnapshotReader =>
      _connection?.accountUsageSnapshotReader;

  FeedbackUploadRunner? get feedbackUploadRunner =>
      _connection?.feedbackUploadRunner;

  GitDiffReader? get gitDiffReader => _connection?.gitDiffReader;

  FileSearchReader? get fileSearchReader => _connection?.fileSearchReader;

  WorkspaceDirectoryReader? get workspaceDirectoryReader =>
      _connection?.workspaceDirectoryReader;

  WorkspaceFileReader? get workspaceFileReader =>
      _connection?.workspaceFileReader;

  McpServerConfigRunner? get mcpServerConfigRunner =>
      _connection?.mcpServerConfigRunner;

  McpServerOAuthRunner? get mcpServerOAuthRunner =>
      _connection?.mcpServerOAuthRunner;

  McpServerStatusReader? get mcpServerStatusReader =>
      _connection?.mcpServerStatusReader;

  ModelListReader? get modelListReader => _connection?.modelListReader;

  PermissionProfileListReader? get permissionProfileListReader =>
      _connection?.permissionProfileListReader;

  SkillListReader? get skillListReader => _connection?.skillListReader;

  PluginListReader? get pluginListReader => _connection?.pluginListReader;

  PluginDetailReader? get pluginDetailReader => _connection?.pluginDetailReader;

  PluginMutationRunner? get pluginMutationRunner =>
      _connection?.pluginMutationRunner;

  HookListReader? get hookListReader => _connection?.hookListReader;

  AppListReader? get appListReader => _connection?.appListReader;

  SlashCommandManifestReader? get slashCommandManifestReader =>
      _connection?.slashCommandManifestReader;

  ThreadMutationRunner? get threadMutationRunner =>
      _connection?.threadMutationRunner;

  ThreadShellCommandRunner? get threadShellCommandRunner {
    final connection = _connection;
    if (connection == null ||
        connection is! ThreadShellCommandConnectionHandle) {
      return null;
    }
    return (connection as ThreadShellCommandConnectionHandle)
        .threadShellCommandRunner;
  }

  CommandExecRunner? get commandExecRunner {
    final connection = _connection;
    if (connection == null || connection is! CommandExecConnectionHandle) {
      return null;
    }
    return (connection as CommandExecConnectionHandle).commandExecRunner;
  }

  ThreadBackgroundTerminalRunner? get threadBackgroundTerminalRunner =>
      _connection?.threadBackgroundTerminalRunner;

  ThreadGoalRunner? get threadGoalRunner => _connection?.threadGoalRunner;

  ThreadReviewRunner? get threadReviewRunner => _connection?.threadReviewRunner;

  TurnRunner? get turnRunner => _connection?.turnRunner;

  List<JsonRpcDiagnosticLogEntry> get diagnosticLogs =>
      _connection?.diagnosticLogs ?? const [];

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
      _stopHeartbeats();
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
      _stopHeartbeats();
      _detachConnectionEvents();
      await connection.close();
    } finally {
      _connection = null;
      _reconnectAttempt = 0;
      _nextReconnectDelay = null;
      _setState(status: CodexSessionStatus.idle);
    }
  }

  Future<void> resumeConnection() async {
    if (_status == CodexSessionStatus.connected ||
        _status == CodexSessionStatus.connecting ||
        _status == CodexSessionStatus.reconnecting) {
      return;
    }
    if (_status == CodexSessionStatus.disconnecting) {
      throw StateError('A session transition is already in progress');
    }
    final profile = _profile;
    if (profile == null) {
      return;
    }
    if (!_autoReconnect) {
      await connect(profile);
      return;
    }

    final generation = ++_generation;
    _reconnectAttempt = 0;
    _nextReconnectDelay = null;
    unawaited(_reconnect(profile, generation, _error));
  }

  Future<void> restartBackend() async {
    final connection = _connection;
    final profile = _profile;
    if (_status != CodexSessionStatus.connected ||
        connection == null ||
        profile == null) {
      throw StateError(
        'A connected session is required to restart the backend',
      );
    }

    final generation = ++_generation;
    _reconnectAttempt = 0;
    _nextReconnectDelay = null;
    _stopHeartbeats();
    _setState(status: CodexSessionStatus.reconnecting, profile: profile);

    try {
      await connection.restartBackend();
    } on Object catch (error) {
      if (!_isCurrentGeneration(generation) || _connection != connection) {
        return;
      }
      _watchConnectionDone(connection, generation);
      _startHeartbeats(connection, generation);
      _setState(
        status: CodexSessionStatus.connected,
        profile: profile,
        error: error,
      );
      rethrow;
    }

    if (!_isCurrentGeneration(generation) || _connection != connection) {
      return;
    }

    _connection = null;
    _detachConnectionEvents();
    try {
      await connection.close();
    } on Object {
      // The restarted backend invalidates the old proxy regardless of whether
      // local transport cleanup reports an error.
    }
    if (!_isCurrentGeneration(generation)) {
      return;
    }

    try {
      final replacement = await _connector.connect(
        profile,
        approvalController: approvalController,
      );
      if (!_isCurrentGeneration(generation)) {
        await replacement.close(notifyApprovalController: false);
        return;
      }
      _activateConnection(replacement, profile, generation);
      if (!_isCurrentGeneration(generation) || _connection != replacement) {
        return;
      }
      _reconnectAttempt = 0;
      _nextReconnectDelay = null;
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

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _stopHeartbeats();
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
    _stopHeartbeats();
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
    _startHeartbeats(connection, generation);
    unawaited(_backfillAgentSnapshot(profile, generation, connection));
  }

  void _startHeartbeats(
    CodexSessionConnectionHandle connection,
    int generation,
  ) {
    _stopHeartbeats();
    for (final channel in _heartbeatChannels) {
      if (!channel.isEnabled) {
        continue;
      }
      _heartbeatHandles.add(
        _heartbeatScheduler.start(
          interval: channel.interval,
          tick: () => _runHeartbeat(channel.runner, connection, generation),
        ),
      );
    }
  }

  Future<void> _runHeartbeat(
    SessionHeartbeatRunner runner,
    CodexSessionConnectionHandle connection,
    int generation,
  ) async {
    if (!_isCurrentGeneration(generation) || _connection != connection) {
      return;
    }
    try {
      await runner.ping(connection);
    } on Object catch (error) {
      if (!_isCurrentGeneration(generation) || _connection != connection) {
        return;
      }
      await _handleConnectionDone(connection, generation, error);
    }
  }

  void _stopHeartbeats() {
    final heartbeats = List<SessionHeartbeatHandle>.of(_heartbeatHandles);
    _heartbeatHandles.clear();
    for (final heartbeat in heartbeats) {
      heartbeat.stop();
    }
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

    try {
      final snapshot = await _readAgentSnapshot(
        profile,
        connection,
        snapshotReader,
      );
      if (snapshot == null) {
        return;
      }
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

  Future<AgentSnapshot?> _readAgentSnapshot(
    SshProfile profile,
    CodexSessionConnectionHandle connection,
    AgentSnapshotReader? fallbackReader,
  ) async {
    final connectionReader = connection is AgentSnapshotConnectionHandle
        ? (connection as AgentSnapshotConnectionHandle).agentSnapshotReader
        : null;
    if (connectionReader != null) {
      try {
        return await connectionReader.readSnapshot(profile);
      } on Object {
        if (fallbackReader == null) {
          rethrow;
        }
      }
    }
    return fallbackReader?.readSnapshot(profile);
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
