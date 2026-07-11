import 'dart:async';

import '../session/codex_session_state_controller.dart';
import '../threads/thread_detail_controller.dart';
import '../threads/thread_item_list_reader.dart';
import '../threads/thread_list_controller.dart';
import '../threads/thread_summary.dart';
import '../threads/thread_turn_list_reader.dart';
import '../turns/turn_controller.dart';

typedef ThreadItemRecoveryHandler =
    void Function({
      required String threadId,
      required List<ThreadItemSummary> items,
    });

class AppSessionRecoveryCoordinator {
  AppSessionRecoveryCoordinator({
    required ThreadListController threadListController,
    required ThreadDetailController threadDetailController,
    required TurnController turnController,
    ThreadTurnListReader? Function()? threadTurnListReaderProvider,
    ThreadItemListReader? Function()? threadItemListReaderProvider,
    ThreadItemRecoveryHandler? threadItemRecoveryHandler,
  }) : _threadListController = threadListController,
       _threadDetailController = threadDetailController,
       _turnController = turnController,
       _threadTurnListReaderProvider = threadTurnListReaderProvider,
       _threadItemListReaderProvider = threadItemListReaderProvider,
       _threadItemRecoveryHandler = threadItemRecoveryHandler;

  final ThreadListController _threadListController;
  final ThreadDetailController _threadDetailController;
  final TurnController _turnController;
  final ThreadTurnListReader? Function()? _threadTurnListReaderProvider;
  final ThreadItemListReader? Function()? _threadItemListReaderProvider;
  final ThreadItemRecoveryHandler? _threadItemRecoveryHandler;
  CodexSessionStatus? _lastStatus;

  static const _turnBackfillLimit = 50;
  static const _itemBackfillLimit = 200;
  static const _itemBackfillMaxPages = 3;

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
      final itemRecovered = await _recoverThreadWithItems(threadId);
      if (!itemRecovered) {
        await _threadDetailController.readThread(threadId);
      }
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
        final itemRecovered = await _recoverThreadItems(threadId);
        if (!itemRecovered) {
          await _threadDetailController.readThread(threadId);
        }
      }
    }
  }

  Future<bool> _recoverThreadWithItems(String threadId) async {
    final itemReader = _threadItemListReaderProvider?.call();
    if (itemReader == null || _threadItemRecoveryHandler == null) {
      return false;
    }
    await _threadDetailController.readThread(threadId, includeTurns: false);
    if (_threadDetailController.selectedThreadId != threadId) {
      return true;
    }
    return _recoverThreadItems(threadId);
  }

  Future<bool> _recoverThreadItems(String threadId) async {
    final itemReader = _threadItemListReaderProvider?.call();
    final recoveryHandler = _threadItemRecoveryHandler;
    if (itemReader == null || recoveryHandler == null) {
      return false;
    }
    try {
      final items = <ThreadItemSummary>[];
      String? cursor;
      for (var pageIndex = 0; pageIndex < _itemBackfillMaxPages; pageIndex++) {
        final page = await itemReader.listItems(
          threadId: threadId,
          cursor: cursor,
          limit: _itemBackfillLimit,
          sortDirection: 'asc',
        );
        if (_threadDetailController.selectedThreadId != threadId) {
          return true;
        }
        items.addAll(page.items);
        final nextCursor = _normalized(page.nextCursor);
        if (page.items.isEmpty || nextCursor == null || nextCursor == cursor) {
          break;
        }
        cursor = nextCursor;
      }
      if (items.isNotEmpty &&
          _threadDetailController.selectedThreadId == threadId) {
        recoveryHandler(threadId: threadId, items: items);
      }
      return true;
    } catch (_) {
      return false;
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
