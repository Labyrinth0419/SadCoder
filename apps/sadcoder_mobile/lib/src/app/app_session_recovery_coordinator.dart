import 'dart:async';

import '../session/codex_session_state_controller.dart';
import '../threads/thread_detail_controller.dart';
import '../threads/thread_list_controller.dart';
import '../threads/thread_turn_list_reader.dart';
import '../turns/turn_controller.dart';

class AppSessionRecoveryCoordinator {
  AppSessionRecoveryCoordinator({
    required ThreadListController threadListController,
    required ThreadDetailController threadDetailController,
    required TurnController turnController,
    ThreadTurnListReader? Function()? threadTurnListReaderProvider,
  }) : _threadListController = threadListController,
       _threadDetailController = threadDetailController,
       _turnController = turnController,
       _threadTurnListReaderProvider = threadTurnListReaderProvider;

  final ThreadListController _threadListController;
  final ThreadDetailController _threadDetailController;
  final TurnController _turnController;
  final ThreadTurnListReader? Function()? _threadTurnListReaderProvider;
  CodexSessionStatus? _lastStatus;

  static const _turnBackfillLimit = 50;

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
      unawaited(_recoverThread(threadId));
    }
  }

  Future<void> _recoverThread(String threadId) async {
    final turnListReader = _threadTurnListReaderProvider?.call();
    if (turnListReader == null) {
      await _threadDetailController.readThread(threadId);
      return;
    }

    await _threadDetailController.readThread(threadId, includeTurns: false);
    if (_threadDetailController.selectedThreadId != threadId) {
      return;
    }
    try {
      final page = await turnListReader.listTurns(
        threadId: threadId,
        limit: _turnBackfillLimit,
        sortDirection: 'desc',
        itemsView: 'full',
      );
      _threadDetailController.backfillTurns(
        threadId: threadId,
        turns: page.turns.reversed.toList(growable: false),
      );
    } catch (_) {
      if (_threadDetailController.selectedThreadId == threadId) {
        await _threadDetailController.readThread(threadId);
      }
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
