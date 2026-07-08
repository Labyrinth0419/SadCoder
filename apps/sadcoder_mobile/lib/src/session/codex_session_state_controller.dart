import 'dart:async';

import 'package:flutter/foundation.dart';

import '../approvals/approval_state_controller.dart';
import '../ssh/ssh_profile.dart';
import 'codex_session_connector.dart';

enum CodexSessionStatus { idle, connecting, connected, disconnecting, failed }

class CodexSessionStateController extends ChangeNotifier {
  CodexSessionStateController({
    required CodexSessionConnectionStarter connector,
    required this.approvalController,
  }) : _connector = connector;

  final CodexSessionConnectionStarter _connector;
  final ApprovalStateController approvalController;
  CodexSessionConnection? _connection;
  CodexSessionStatus _status = CodexSessionStatus.idle;
  SshProfile? _profile;
  Object? _error;

  CodexSessionStatus get status => _status;

  bool get isConnected => _status == CodexSessionStatus.connected;

  SshProfile? get profile => _profile;

  Object? get error => _error;

  Future<void> connect(SshProfile profile) async {
    if (_status == CodexSessionStatus.connecting ||
        _status == CodexSessionStatus.disconnecting) {
      throw StateError('A session transition is already in progress');
    }

    if (_connection != null) {
      await disconnect();
    }

    _setState(
      status: CodexSessionStatus.connecting,
      profile: profile,
      error: null,
    );

    try {
      _connection = await _connector.connect(
        profile,
        approvalController: approvalController,
      );
      _setState(status: CodexSessionStatus.connected, profile: profile);
    } on Object catch (error) {
      _connection = null;
      _setState(
        status: CodexSessionStatus.failed,
        profile: profile,
        error: error,
      );
      rethrow;
    }
  }

  Future<void> disconnect() async {
    final connection = _connection;
    if (connection == null) {
      _setState(status: CodexSessionStatus.idle, error: null);
      return;
    }

    _setState(status: CodexSessionStatus.disconnecting, error: null);
    try {
      await connection.close();
    } finally {
      _connection = null;
      _setState(status: CodexSessionStatus.idle, error: null);
    }
  }

  @override
  void dispose() {
    unawaited(_connection?.close(notifyApprovalController: false));
    _connection = null;
    super.dispose();
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
