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

  Future<CodexSessionStateController> connect(SshProfile profile) async {
    _debugAssertNotDisposed();
    final profileId = hostSessionProfileId(profile);
    final entry = _sessions.putIfAbsent(profileId, () {
      final approvalController = ApprovalStateController();
      final sessionController = _controllerFactory(approvalController)
        ..addListener(_handleManagedSessionChanged);
      return HostSessionEntry._(
        profileId: profileId,
        profile: profile,
        approvalController: approvalController,
        sessionController: sessionController,
      );
    });
    entry.updateProfile(profile);
    _activeProfileId = profileId;
    notifyListeners();
    await entry.sessionController.connect(profile);
    return entry.sessionController;
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
    final entry = _sessions[profileId.trim()];
    if (entry == null) {
      return false;
    }
    await entry.sessionController.disconnect();
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
    final entry = _sessions.remove(normalized);
    if (entry == null) {
      return false;
    }
    await entry.sessionController.disconnect();
    entry.sessionController.removeListener(_handleManagedSessionChanged);
    entry.sessionController.dispose();
    entry.approvalController.dispose();
    if (_activeProfileId == normalized) {
      _activeProfileId = _sessions.keys.firstOrNull;
    }
    notifyListeners();
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
      entry.sessionController.dispose();
      entry.approvalController.dispose();
    }
    _sessions.clear();
    _activeProfileId = null;
    super.dispose();
  }

  void _handleManagedSessionChanged() {
    if (!_disposed) {
      notifyListeners();
    }
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
