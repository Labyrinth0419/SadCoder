import 'dart:async';

import '../session/codex_session_state_controller.dart';
import '../threads/thread_detail_controller.dart';
import '../threads/thread_item_list_reader.dart';
import '../threads/thread_list_controller.dart';
import '../threads/thread_summary.dart';
import '../threads/thread_timeline_cursor_store.dart';
import '../threads/thread_turn_list_reader.dart';
import '../turns/turn_controller.dart';

typedef ThreadItemRecoveryHandler =
    void Function({
      required String threadId,
      required List<ThreadItemSummary> items,
    });
typedef ThreadTimelineCursorProvider =
    Future<ThreadTimelineCursorSnapshot?> Function(String threadId);
typedef ThreadRecoveryHintProvider =
    Future<ThreadRecoveryHint> Function(String threadId);

class ThreadRecoveryHint {
  const ThreadRecoveryHint({
    this.timelineCursor,
    this.forceConservativeBackfill = false,
  });

  static const empty = ThreadRecoveryHint();

  final ThreadTimelineCursorSnapshot? timelineCursor;
  final bool forceConservativeBackfill;
}

class AppSessionRecoveryCoordinator {
  AppSessionRecoveryCoordinator({
    required ThreadListController threadListController,
    required ThreadDetailController threadDetailController,
    required TurnController turnController,
    ThreadTurnListReader? Function()? threadTurnListReaderProvider,
    ThreadItemListReader? Function()? threadItemListReaderProvider,
    ThreadItemRecoveryHandler? threadItemRecoveryHandler,
    ThreadTimelineCursorProvider? threadTimelineCursorProvider,
    ThreadRecoveryHintProvider? threadRecoveryHintProvider,
  }) : _threadListController = threadListController,
       _threadDetailController = threadDetailController,
       _turnController = turnController,
       _threadTurnListReaderProvider = threadTurnListReaderProvider,
       _threadItemListReaderProvider = threadItemListReaderProvider,
       _threadItemRecoveryHandler = threadItemRecoveryHandler,
       _threadTimelineCursorProvider = threadTimelineCursorProvider,
       _threadRecoveryHintProvider = threadRecoveryHintProvider;

  final ThreadListController _threadListController;
  final ThreadDetailController _threadDetailController;
  final TurnController _turnController;
  final ThreadTurnListReader? Function()? _threadTurnListReaderProvider;
  final ThreadItemListReader? Function()? _threadItemListReaderProvider;
  final ThreadItemRecoveryHandler? _threadItemRecoveryHandler;
  final ThreadTimelineCursorProvider? _threadTimelineCursorProvider;
  final ThreadRecoveryHintProvider? _threadRecoveryHintProvider;
  CodexSessionStatus? _lastStatus;

  static const _turnBackfillLimit = 50;
  static const _turnBackfillMaxPages = 3;
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

  void recoverCurrentThread() {
    final threadId = _threadIdToRecover();
    if (threadId != null) {
      unawaited(_recoverThread(threadId));
    }
  }

  void recoverThread(String threadId) {
    final normalizedThreadId = _normalized(threadId);
    if (normalizedThreadId != null) {
      unawaited(_recoverThread(normalizedThreadId));
    }
  }

  Future<void> _recoverThread(String threadId) async {
    final recoveryHint = await _loadRecoveryHint(threadId);
    final turnListReader = _threadTurnListReaderProvider?.call();
    if (turnListReader == null) {
      final itemRecovered = await _recoverThreadWithItems(
        threadId,
        recoveryHint: recoveryHint,
      );
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
      final turns = <TurnSummary>[];
      final seenTurnIds = <String>{};
      final stopTurnId = recoveryHint.forceConservativeBackfill
          ? null
          : _normalized(recoveryHint.timelineCursor?.lastTurnId);
      String? cursor;
      for (var pageIndex = 0; pageIndex < _turnBackfillMaxPages; pageIndex++) {
        final page = await turnListReader.listTurns(
          threadId: threadId,
          cursor: cursor,
          limit: _turnBackfillLimit,
          sortDirection: 'desc',
          itemsView: 'full',
        );
        if (_threadDetailController.selectedThreadId != threadId) {
          return;
        }
        final reachedKnownTurn = _appendUniqueTurns(
          turns,
          seenTurnIds,
          page.turns,
          stopAfterTurnId: stopTurnId,
        );
        final nextCursor = _normalized(page.nextCursor);
        if (reachedKnownTurn ||
            page.turns.isEmpty ||
            nextCursor == null ||
            nextCursor == cursor) {
          break;
        }
        cursor = nextCursor;
      }
      _threadDetailController.backfillTurns(
        threadId: threadId,
        turns: turns.reversed.toList(growable: false),
      );
    } catch (_) {
      if (_threadDetailController.selectedThreadId == threadId) {
        final itemRecovered = await _recoverThreadItems(
          threadId,
          recoveryHint: recoveryHint,
        );
        if (!itemRecovered) {
          await _threadDetailController.readThread(threadId);
        }
      }
    }
  }

  Future<bool> _recoverThreadWithItems(
    String threadId, {
    required ThreadRecoveryHint recoveryHint,
  }) async {
    final itemReader = _threadItemListReaderProvider?.call();
    if (itemReader == null || _threadItemRecoveryHandler == null) {
      return false;
    }
    await _threadDetailController.readThread(threadId, includeTurns: false);
    if (_threadDetailController.selectedThreadId != threadId) {
      return true;
    }
    return _recoverThreadItems(threadId, recoveryHint: recoveryHint);
  }

  Future<bool> _recoverThreadItems(
    String threadId, {
    required ThreadRecoveryHint recoveryHint,
  }) async {
    final itemReader = _threadItemListReaderProvider?.call();
    final recoveryHandler = _threadItemRecoveryHandler;
    if (itemReader == null || recoveryHandler == null) {
      return false;
    }
    try {
      final fallbackItems = <ThreadItemSummary>[];
      final fallbackSeenItemIds = <String>{};
      final items = <ThreadItemSummary>[];
      final seenItemIds = <String>{};
      final itemBoundary = _ItemRecoveryBoundary(
        lastSeenItemId: recoveryHint.forceConservativeBackfill
            ? null
            : recoveryHint.timelineCursor?.lastItemId,
      );
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
        _appendUniqueItems(fallbackItems, fallbackSeenItemIds, page.items);
        _appendUniqueItems(
          items,
          seenItemIds,
          page.items,
          boundary: itemBoundary,
        );
        final nextCursor = _normalized(page.nextCursor);
        if (page.items.isEmpty || nextCursor == null || nextCursor == cursor) {
          break;
        }
        cursor = nextCursor;
      }
      final recoveredItems = itemBoundary.hasBoundary && itemBoundary.found
          ? items
          : fallbackItems;
      if (recoveredItems.isNotEmpty &&
          _threadDetailController.selectedThreadId == threadId) {
        recoveryHandler(threadId: threadId, items: recoveredItems);
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

  Future<ThreadTimelineCursorSnapshot?> _loadTimelineCursor(
    String threadId,
  ) async {
    final provider = _threadTimelineCursorProvider;
    if (provider == null) {
      return null;
    }
    try {
      final snapshot = await provider(threadId);
      if (_normalized(snapshot?.threadId) != _normalized(threadId)) {
        return null;
      }
      return snapshot?.isEmpty == true ? null : snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<ThreadRecoveryHint> _loadRecoveryHint(String threadId) async {
    final hintProvider = _threadRecoveryHintProvider;
    if (hintProvider != null) {
      try {
        return _sanitizeRecoveryHint(threadId, await hintProvider(threadId));
      } catch (_) {
        return ThreadRecoveryHint.empty;
      }
    }

    final cursor = await _loadTimelineCursor(threadId);
    return ThreadRecoveryHint(timelineCursor: cursor);
  }

  ThreadRecoveryHint _sanitizeRecoveryHint(
    String threadId,
    ThreadRecoveryHint hint,
  ) {
    final cursor = hint.timelineCursor;
    final normalizedThreadId = _normalized(threadId);
    final normalizedCursorThreadId = _normalized(cursor?.threadId);
    final validCursor =
        cursor != null &&
        normalizedCursorThreadId == normalizedThreadId &&
        cursor.isEmpty != true;
    if (!validCursor && !hint.forceConservativeBackfill) {
      return ThreadRecoveryHint.empty;
    }
    return ThreadRecoveryHint(
      timelineCursor: validCursor ? cursor : null,
      forceConservativeBackfill: hint.forceConservativeBackfill,
    );
  }
}

bool _appendUniqueTurns(
  List<TurnSummary> target,
  Set<String> seenIds,
  List<TurnSummary> turns, {
  String? stopAfterTurnId,
}) {
  final stopId = _normalized(stopAfterTurnId);
  for (final turn in turns) {
    final id = _normalized(turn.id);
    if (id == null || seenIds.add(id)) {
      target.add(turn);
    }
    if (id != null && id == stopId) {
      return true;
    }
  }
  return false;
}

void _appendUniqueItems(
  List<ThreadItemSummary> target,
  Set<String> seenIds,
  List<ThreadItemSummary> items, {
  _ItemRecoveryBoundary? boundary,
}) {
  for (final item in items) {
    final id = _normalized(item.id);
    if (boundary != null && !boundary.shouldKeep(id)) {
      continue;
    }
    if (id == null || seenIds.add(id)) {
      target.add(item);
    }
  }
}

class _ItemRecoveryBoundary {
  _ItemRecoveryBoundary({String? lastSeenItemId})
    : _lastSeenItemId = _normalized(lastSeenItemId),
      _found = _normalized(lastSeenItemId) == null;

  final String? _lastSeenItemId;
  bool _found;

  bool get hasBoundary => _lastSeenItemId != null;
  bool get found => _found;

  bool shouldKeep(String? itemId) {
    if (_found) {
      return true;
    }
    if (itemId != null && itemId == _lastSeenItemId) {
      _found = true;
      return true;
    }
    return false;
  }
}

String? _normalized(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
