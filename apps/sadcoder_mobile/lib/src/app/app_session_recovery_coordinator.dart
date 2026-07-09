import 'dart:async';

import '../session/codex_session_state_controller.dart';
import '../threads/thread_detail_controller.dart';
import '../threads/thread_list_controller.dart';
import '../turns/turn_controller.dart';

class AppSessionRecoveryCoordinator {
  AppSessionRecoveryCoordinator({
    required ThreadListController threadListController,
    required ThreadDetailController threadDetailController,
    required TurnController turnController,
  }) : _threadListController = threadListController,
       _threadDetailController = threadDetailController,
       _turnController = turnController;

  final ThreadListController _threadListController;
  final ThreadDetailController _threadDetailController;
  final TurnController _turnController;
  CodexSessionStatus? _lastStatus;

  void handleSessionStatus(CodexSessionStatus status) {
    final becameConnected =
        _lastStatus != CodexSessionStatus.connected &&
        status == CodexSessionStatus.connected;
    _lastStatus = status;
    if (!becameConnected) {
      return;
    }

    unawaited(_threadListController.refresh());
    final threadId = _threadIdToRecover();
    if (threadId != null) {
      unawaited(_threadDetailController.readThread(threadId));
    }
  }

  String? _threadIdToRecover() {
    return _normalized(_turnController.activeThreadId) ??
        _normalized(_threadDetailController.selectedThreadId);
  }
}

String? _normalized(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
