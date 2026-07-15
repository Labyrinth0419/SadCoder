import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_timeline_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_timeline_window_coordinator.dart';
import 'package:sadcoder_mobile/src/threads/thread_item_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

void main() {
  test('reset rejects an old initial window after a host switch', () async {
    final timeline = ChatTimelineController();
    final reader = _DeferredThreadItemListReader();
    final coordinator = ChatTimelineWindowCoordinator(
      mounted: () => true,
      timelineControllerProvider: () => timeline,
      threadItemListReaderProvider: () => reader,
      turnControllerProvider: () => null,
    );
    addTearDown(timeline.dispose);

    coordinator.loadInitialWindow(_thread('thr_old'));
    coordinator.reset();
    coordinator.loadInitialWindow(_thread('thr_new'));
    expect(reader.calls.map((call) => call.threadId), ['thr_old', 'thr_new']);

    reader.complete(1, ThreadItemsPage(items: [_item('new_item', 'New host')]));
    await _flushMicrotasks();
    reader.complete(0, ThreadItemsPage(items: [_item('old_item', 'Old host')]));
    await _flushMicrotasks();

    expect(timeline.selectedThreadId, 'thr_new');
    expect(timeline.cursor.itemIds, ['new_item']);
  });

  test('initial recovery merges a live delta in server order', () async {
    final timeline = ChatTimelineController();
    final reader = _DeferredThreadItemListReader();
    final coordinator = ChatTimelineWindowCoordinator(
      mounted: () => true,
      timelineControllerProvider: () => timeline,
      threadItemListReaderProvider: () => reader,
      turnControllerProvider: () => null,
    );
    addTearDown(timeline.dispose);

    coordinator.loadInitialWindow(_thread('thr_1'));
    timeline.selectThread('thr_1');
    timeline.ingest(_agentDelta('item_live', 'streamed complete'));
    reader.complete(
      0,
      ThreadItemsPage(
        items: [
          _item('item_live', 'streamed', turnId: 'turn_1'),
          _item('item_before', 'Persisted before live', turnId: 'turn_1'),
        ],
      ),
    );
    await _flushMicrotasks();

    expect(timeline.turns, hasLength(1));
    expect(timeline.turns.single.items.map((item) => item.itemId), [
      'item_before',
      'item_live',
    ]);
    expect(timeline.turns.single.items.last.text, 'streamed complete');
    expect(timeline.cursor.itemIds.toSet(), hasLength(2));
  });

  test('empty item pages fall back to full thread detail turns', () async {
    final timeline = ChatTimelineController();
    final reader = _DeferredThreadItemListReader();
    final coordinator = ChatTimelineWindowCoordinator(
      mounted: () => true,
      timelineControllerProvider: () => timeline,
      threadItemListReaderProvider: () => reader,
      turnControllerProvider: () => null,
    );
    addTearDown(timeline.dispose);
    final thread = ThreadSummary.fromJson({
      ..._thread('thr_1').toDetailJson(),
      'turns': [
        {
          'id': 'turn_1',
          'status': 'completed',
          'itemsView': 'full',
          'items': [
            {'id': 'item_1', 'type': 'agentMessage', 'text': 'From detail'},
          ],
        },
      ],
    });

    coordinator.loadInitialWindow(thread);
    reader.complete(0, const ThreadItemsPage(items: []));
    await _flushMicrotasks();

    expect(timeline.selectedThreadId, 'thr_1');
    expect(timeline.turns.single.items.single.text, 'From detail');
  });
}

class _DeferredThreadItemListReader implements ThreadItemListReader {
  final calls =
      <
        ({String threadId, String? cursor, Completer<ThreadItemsPage> result})
      >[];

  void complete(int index, ThreadItemsPage page) {
    calls[index].result.complete(page);
  }

  @override
  Future<ThreadItemsPage> listItems({
    required String threadId,
    String? turnId,
    String? cursor,
    int? limit,
    String? sortDirection,
  }) {
    final result = Completer<ThreadItemsPage>();
    calls.add((threadId: threadId, cursor: cursor, result: result));
    return result.future;
  }
}

ThreadSummary _thread(String id) => ThreadSummary.fromJson({
  'id': id,
  'sessionId': 'session_$id',
  'preview': id,
  'ephemeral': false,
  'status': 'idle',
  'cwd': '/repo',
  'updatedAt': 1,
});

ThreadItemSummary _item(String id, String text, {String? turnId}) {
  return ThreadItemSummary.fromJson({
    'id': id,
    'type': 'agentMessage',
    'text': text,
    'turnId': ?turnId,
  });
}

CodexEvent _agentDelta(String itemId, String delta) {
  return CodexEvent.fromNotification({
    'method': 'item/agentMessage/delta',
    'params': {
      'threadId': 'thr_1',
      'turnId': 'turn_1',
      'itemId': itemId,
      'delta': delta,
    },
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
