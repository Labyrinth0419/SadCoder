import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_timeline_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

void main() {
  test('ingest builds timeline turns, items, and deltas', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.ingest(_turnStarted());
    controller.ingest(
      _itemStarted(
        itemId: 'item_1',
        itemType: 'agentMessage',
        raw: {'id': 'item_1', 'type': 'agentMessage', 'text': ''},
      ),
    );
    controller.ingest(_agentDelta('item_1', 'hello'));
    controller.ingest(_agentDelta('item_1', ' world'));
    controller.ingest(
      _itemStarted(
        itemId: 'item_2',
        itemType: 'commandExecution',
        raw: {
          'id': 'item_2',
          'type': 'commandExecution',
          'command': 'cargo test',
          'aggregatedOutput': '',
        },
      ),
    );
    controller.ingest(_commandDelta('item_2', 'ok'));

    expect(controller.turns, hasLength(1));
    expect(controller.turns.single.turnId, 'turn_1');
    expect(controller.turns.single.status, 'inProgress');
    expect(controller.turns.single.items, hasLength(2));
    expect(controller.turns.single.items.first.text, 'hello world');
    expect(controller.turns.single.items.last.output, 'ok');
  });

  test('turn completion updates status and calls completion handler', () {
    ({String threadId, TurnSummary turn})? completed;
    final controller = ChatTimelineController(
      onTurnCompleted: ({required threadId, required turn}) {
        completed = (threadId: threadId, turn: turn);
      },
    );
    addTearDown(controller.dispose);

    controller.ingest(_turnStarted());
    controller.ingest(_turnCompleted(status: 'completed'));

    expect(controller.turns.single.status, 'completed');
    expect(completed?.threadId, 'thr_1');
    expect(completed?.turn.id, 'turn_1');
  });

  test('attach consumes event streams asynchronously', () async {
    final events = StreamController<CodexEvent>.broadcast();
    ({String threadId, TurnSummary turn})? completed;
    final controller = ChatTimelineController(
      onTurnCompleted: ({required threadId, required turn}) {
        completed = (threadId: threadId, turn: turn);
      },
    );
    addTearDown(controller.dispose);
    addTearDown(events.close);

    controller.attach(events.stream);
    events.add(_turnStarted());
    events.add(_agentDelta('item_1', 'streamed'));
    events.add(_turnCompleted(status: 'completed'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.turns.single.status, 'completed');
    expect(controller.turns.single.items.single.text, 'streamed');
    expect(completed?.threadId, 'thr_1');
  });
}

CodexEvent _turnStarted() {
  return CodexEvent.fromNotification({
    'method': 'turn/started',
    'params': {
      'threadId': 'thr_1',
      'turn': {
        'id': 'turn_1',
        'status': 'inProgress',
        'items': <Object?>[],
        'itemsView': 'notLoaded',
      },
    },
  });
}

CodexEvent _turnCompleted({required String status}) {
  return CodexEvent.fromNotification({
    'method': 'turn/completed',
    'params': {
      'threadId': 'thr_1',
      'turn': {
        'id': 'turn_1',
        'status': status,
        'items': <Object?>[],
        'itemsView': 'full',
      },
    },
  });
}

CodexEvent _itemStarted({
  required String itemId,
  required String itemType,
  required Map<String, Object?> raw,
}) {
  return CodexEvent.fromNotification({
    'method': 'item/started',
    'params': {'threadId': 'thr_1', 'turnId': 'turn_1', 'item': raw},
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

CodexEvent _commandDelta(String itemId, String delta) {
  return CodexEvent.fromNotification({
    'method': 'item/commandExecution/outputDelta',
    'params': {
      'threadId': 'thr_1',
      'turnId': 'turn_1',
      'itemId': itemId,
      'delta': delta,
    },
  });
}
