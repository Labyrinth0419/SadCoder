import 'dart:async';

import 'package:flutter/foundation.dart';

import '../approvals/approval_state_controller.dart';
import '../ssh/ssh_profile.dart';
import 'codex_session_state_controller.dart';

typedef HostSessionControllerFactory =
    CodexSessionStateController Function(
      ApprovalStateController approvalController,
    );

class HostSessionEntry {
  HostSessionEntry._({
    required this.profileId,
    required SshProfile profile,
    required this.approvalController,
    required this.sessionController,
  }) : _profile = profile;

  final String profileId;
  final ApprovalStateController approvalController;
  final CodexSessionStateController sessionController;
  SshProfile _profile;

  SshProfile get profile => sessionController.profile ?? _profile;

  CodexSessionStatus get status => sessionController.status;

  bool get isConnected => sessionController.isConnected;

  void updateProfile(SshProfile profile) {
    _profile = profile;
  }
}

class HostSessionManager extends ChangeNotifier {
  HostSessionManager({required HostSessionControllerFactory controllerFactory})
    : _controllerFactory = controllerFactory;

  final HostSessionControllerFactory _controllerFactory;
  final Map<String, HostSessionEntry> _sessions = {};
  final Map<String, Future<CodexSessionStateController>> _connectsByProfileId =
      {};
  String? _activeProfileId;
  bool _disposed = false;

  List<HostSessionEntry> get sessions => List.unmodifiable(_sessions.values);

  String? get activeProfileId => _activeProfileId;

  HostSessionEntry? get activeSession =>
      _activeProfileId == null ? null : _sessions[_activeProfileId];

  CodexSessionStateController? get activeSessionController =>
      activeSession?.sessionController;

  ApprovalStateController? get activeApprovalController =>
      activeSession?.approvalController;

  HostSessionEntry? sessionFor(String profileId) {
    return _sessions[profileId.trim()];
  }

  Future<CodexSessionStateController> connect(SshProfile profile) {
    _debugAssertNotDisposed();
    final profileId = hostSessionProfileId(profile);
    final entry = _sessionEntryFor(profileId, profile);
    entry.updateProfile(profile);
    _activeProfileId = profileId;
    notifyListeners();

    final pendingConnect = _connectsByProfileId[profileId];
    if (pendingConnect != null) {
      return pendingConnect;
    }

    final connectFuture = _connectEntry(entry, profile);
    _connectsByProfileId[profileId] = connectFuture;
    unawaited(
      connectFuture.then<void>(
        (_) => _clearPendingConnect(profileId, connectFuture),
        onError: (Object _) => _clearPendingConnect(profileId, connectFuture),
      ),
    );
    return connectFuture;
  }

  Future<CodexSessionStateController> _connectEntry(
    HostSessionEntry entry,
    SshProfile profile,
  ) async {
    await entry.sessionController.connect(profile);
    return entry.sessionController;
  }

  Future<CodexSessionStateController> connectOrSelect(SshProfile profile) {
    _debugAssertNotDisposed();
    final profileId = hostSessionProfileId(profile);
    final existing = _sessions[profileId];
    final pendingConnect = _connectsByProfileId[profileId];
    if (pendingConnect != null) {
      existing?.updateProfile(profile);
      if (existing != null) {
        select(profileId);
      }
      return pendingConnect;
    }
    if (existing != null &&
        existing.status != CodexSessionStatus.idle &&
        existing.status != CodexSessionStatus.failed) {
      existing.updateProfile(profile);
      select(profileId);
      return Future.value(existing.sessionController);
    }
    return connect(profile);
  }

  bool select(String profileId) {
    _debugAssertNotDisposed();
    final normalized = profileId.trim();
    if (!_sessions.containsKey(normalized)) {
      return false;
    }
    if (_activeProfileId == normalized) {
      return true;
    }
    _activeProfileId = normalized;
    notifyListeners();
    return true;
  }

  Future<bool> disconnect(String profileId) async {
    _debugAssertNotDisposed();
    final normalized = profileId.trim();
    final entry = _sessions[normalized];
    if (entry == null) {
      return false;
    }
    _connectsByProfileId.remove(normalized);
    await entry.sessionController.disconnect();
    _reconcileActiveSelection();
    return true;
  }

  Future<bool> disconnectActive() {
    final profileId = _activeProfileId;
    if (profileId == null) {
      return Future.value(false);
    }
    return disconnect(profileId);
  }

  Future<bool> closeSession(String profileId) async {
    _debugAssertNotDisposed();
    final normalized = profileId.trim();
    _connectsByProfileId.remove(normalized);
    final entry = _sessions.remove(normalized);
    if (entry == null) {
      return false;
    }
    await entry.sessionController.disconnect();
    entry.sessionController.removeListener(_handleManagedSessionChanged);
    entry.approvalController.removeListener(_handleManagedSessionChanged);
    entry.sessionController.dispose();
    entry.approvalController.dispose();
    if (!_reconcileActiveSelection()) {
      notifyListeners();
    }
    return true;
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final entry in _sessions.values) {
      entry.sessionController.removeListener(_handleManagedSessionChanged);
      entry.approvalController.removeListener(_handleManagedSessionChanged);
      entry.sessionController.dispose();
      entry.approvalController.dispose();
    }
    _sessions.clear();
    _connectsByProfileId.clear();
    _activeProfileId = null;
    super.dispose();
  }

  HostSessionEntry _sessionEntryFor(String profileId, SshProfile profile) {
    return _sessions.putIfAbsent(profileId, () {
      final approvalController = ApprovalStateController();
      approvalController.addListener(_handleManagedSessionChanged);
      final sessionController = _controllerFactory(approvalController)
        ..addListener(_handleManagedSessionChanged);
      return HostSessionEntry._(
        profileId: profileId,
        profile: profile,
        approvalController: approvalController,
        sessionController: sessionController,
      );
    });
  }

  void _clearPendingConnect(
    String profileId,
    Future<CodexSessionStateController> connectFuture,
  ) {
    if (identical(_connectsByProfileId[profileId], connectFuture)) {
      _connectsByProfileId.remove(profileId);
    }
  }

  void _handleManagedSessionChanged() {
    if (!_disposed) {
      if (!_reconcileActiveSelection()) {
        notifyListeners();
      }
    }
  }

  bool _reconcileActiveSelection() {
    final active = _activeProfileId == null
        ? null
        : _sessions[_activeProfileId];
    if (active != null && _isActiveCandidate(active)) {
      return false;
    }

    HostSessionEntry? next;
    for (final entry in _sessions.values) {
      if (_isActiveCandidate(entry)) {
        next = entry;
        break;
      }
    }
    final nextProfileId = next?.profileId;
    if (_activeProfileId == nextProfileId) {
      return false;
    }
    _activeProfileId = nextProfileId;
    notifyListeners();
    return true;
  }

  bool _isActiveCandidate(HostSessionEntry entry) {
    return switch (entry.status) {
      CodexSessionStatus.connected ||
      CodexSessionStatus.connecting ||
      CodexSessionStatus.reconnecting => true,
      CodexSessionStatus.idle ||
      CodexSessionStatus.disconnecting ||
      CodexSessionStatus.failed => false,
    };
  }

  void _debugAssertNotDisposed() {
    assert(!_disposed, 'HostSessionManager has been disposed.');
  }
}

String hostSessionProfileId(SshProfile profile) {
  final explicitId = profile.id.trim();
  if (explicitId.isNotEmpty && explicitId != 'manual') {
    return explicitId;
  }
  return sshProfileId(
    host: profile.host,
    port: profile.port,
    username: profile.username,
  );
}
