import 'dart:async';

import '../../threads/thread_detail_reader.dart';
import '../../threads/thread_item_list_reader.dart';
import '../../threads/thread_summary.dart';
import '../../turns/turn_controller.dart';
import 'chat_timeline_controller.dart';

typedef ChatTimelineControllerProvider = ChatTimelineController? Function();
typedef ChatThreadDetailReaderProvider = ThreadDetailReader? Function();
typedef ChatThreadItemListReaderProvider = ThreadItemListReader? Function();
typedef ChatTurnControllerProvider = TurnController? Function();

class ChatTimelineWindowCoordinator {
  ChatTimelineWindowCoordinator({
    required this.mounted,
    required this.timelineControllerProvider,
    required this.threadDetailReaderProvider,
    required this.threadItemListReaderProvider,
    required this.turnControllerProvider,
  });

  final bool Function() mounted;
  final ChatTimelineControllerProvider timelineControllerProvider;
  final ChatThreadDetailReaderProvider threadDetailReaderProvider;
  final ChatThreadItemListReaderProvider threadItemListReaderProvider;
  final ChatTurnControllerProvider turnControllerProvider;

  String? _lastWindowThreadId;
  int _generation = 0;

  void reset() {
    _lastWindowThreadId = null;
    _generation++;
  }

  void loadInitialWindow(ThreadSummary thread) {
    final threadId = _normalizedText(thread.id);
    final timelineController = timelineControllerProvider();
    if (threadId == null || timelineController == null) {
      return;
    }
    final reader = threadItemListReaderProvider();
    if (reader == null) {
      _lastWindowThreadId = threadId;
      final generation = ++_generation;
      unawaited(
        _showFullThreadFallback(generation: generation, thread: thread),
      );
      return;
    }
    if (_lastWindowThreadId == threadId &&
        timelineController.selectedThreadId == threadId &&
        timelineController.itemCount > 0) {
      return;
    }
    _lastWindowThreadId = threadId;
    final generation = ++_generation;
    unawaited(
      _readInitialWindow(
        generation: generation,
        reader: reader,
        thread: thread,
      ),
    );
  }

  Future<void> _readInitialWindow({
    required int generation,
    required ThreadItemListReader reader,
    required ThreadSummary thread,
  }) async {
    try {
      final page = await reader.listItems(
        threadId: thread.id,
        limit: chatTimelineInitialItemLimit,
        sortDirection: 'desc',
      );
      if (!mounted() || generation != _generation) {
        return;
      }
      if (page.items.isEmpty) {
        await _showFullThreadFallback(generation: generation, thread: thread);
        return;
      }
      timelineControllerProvider()?.showThreadItemWindow(
        thread: thread,
        items: page.items.reversed.toList(growable: false),
        olderItemsCursor: page.nextCursor,
      );
    } on Object {
      if (!mounted() || generation != _generation) {
        return;
      }
      await _showFullThreadFallback(generation: generation, thread: thread);
    }
  }

  Future<void> _showFullThreadFallback({
    required int generation,
    required ThreadSummary thread,
  }) async {
    if (!mounted() || generation != _generation) {
      return;
    }
    if (thread.turns.isNotEmpty) {
      timelineControllerProvider()?.showThread(thread);
      return;
    }

    final detailReader = threadDetailReaderProvider();
    if (detailReader == null) {
      timelineControllerProvider()?.showThread(thread);
      return;
    }
    try {
      final detail = await detailReader.readThread(
        threadId: thread.id,
        includeTurns: true,
      );
      if (!mounted() || generation != _generation) {
        return;
      }
      final fullThread = detail.thread.id == thread.id ? detail.thread : thread;
      timelineControllerProvider()?.showThread(fullThread);
    } on Object {
      if (!mounted() || generation != _generation) {
        return;
      }
      timelineControllerProvider()?.showThread(thread);
    }
  }

  void requestOlderItems() {
    final timelineController = timelineControllerProvider();
    final reader = threadItemListReaderProvider();
    final threadId = _normalizedText(timelineController?.selectedThreadId);
    final cursor = _normalizedText(timelineController?.olderItemsCursor);
    if (timelineController == null ||
        reader == null ||
        threadId == null ||
        cursor == null ||
        timelineController.isLoadingOlderHistory) {
      return;
    }
    timelineController.beginOlderHistoryLoad();
    final generation = ++_generation;
    unawaited(
      _readOlderItems(
        generation: generation,
        reader: reader,
        threadId: threadId,
        cursor: cursor,
      ),
    );
  }

  Future<void> _readOlderItems({
    required int generation,
    required ThreadItemListReader reader,
    required String threadId,
    required String cursor,
  }) async {
    try {
      final page = await reader.listItems(
        threadId: threadId,
        cursor: cursor,
        limit: chatTimelineInitialItemLimit,
        sortDirection: 'desc',
      );
      if (!mounted() || generation != _generation) {
        return;
      }
      final nextCursor = _normalizedText(page.nextCursor);
      timelineControllerProvider()?.prependThreadItems(
        threadId: threadId,
        items: page.items.reversed.toList(growable: false),
        olderItemsCursor: nextCursor == cursor ? null : nextCursor,
      );
    } on Object catch (error) {
      if (!mounted() || generation != _generation) {
        return;
      }
      timelineControllerProvider()?.failOlderHistoryLoad(error);
    }
  }

  void syncActiveTurn({String? submittedText, bool queuedInstruction = false}) {
    final timelineController = timelineControllerProvider();
    final turnController = turnControllerProvider();
    final activeThreadId = _normalizedText(turnController?.activeThreadId);
    if (timelineController == null ||
        turnController == null ||
        activeThreadId == null) {
      return;
    }
    final lastTurn = turnController.lastTurn;
    if (lastTurn != null && lastTurn.id.trim().isNotEmpty) {
      timelineController.showTurn(threadId: activeThreadId, turn: lastTurn);
      final text = _normalizedText(submittedText);
      if (text != null) {
        if (queuedInstruction) {
          timelineController.showQueuedInstruction(
            threadId: activeThreadId,
            turnId: lastTurn.id,
            text: text,
          );
        } else {
          timelineController.showLocalUserMessage(
            threadId: activeThreadId,
            turnId: lastTurn.id,
            text: text,
          );
        }
      }
      return;
    }
    timelineController.selectThread(activeThreadId);
  }
}

String? _normalizedText(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
