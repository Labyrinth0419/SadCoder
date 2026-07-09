import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';

void main() {
  test('maps thread and turn lifecycle notifications', () {
    final threadStarted = CodexEvent.fromNotification({
      'method': 'thread/started',
      'params': {
        'thread': {
          'id': 'thr_1',
          'sessionId': 'sess_1',
          'preview': 'Fix bug',
          'ephemeral': false,
          'status': 'running',
          'cwd': '/repo',
          'updatedAt': 1,
        },
      },
    });
    final turnCompleted = CodexEvent.fromNotification({
      'method': 'turn/completed',
      'params': {
        'threadId': 'thr_1',
        'turn': {
          'id': 'turn_1',
          'status': 'completed',
          'items': <Object?>[],
          'itemsView': 'full',
        },
      },
    });

    expect(threadStarted.kind, CodexEventKind.threadStarted);
    expect(threadStarted.threadId, 'thr_1');
    expect(threadStarted.thread?.title, 'Fix bug');
    expect(turnCompleted.kind, CodexEventKind.turnCompleted);
    expect(turnCompleted.threadId, 'thr_1');
    expect(turnCompleted.turnId, 'turn_1');
    expect(turnCompleted.turn?.status, 'completed');
  });

  test('maps item lifecycle and delta notifications', () {
    final itemStarted = CodexEvent.fromNotification({
      'method': 'item/started',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'item': {'id': 'item_1', 'type': 'agentMessage', 'text': ''},
      },
    });
    final delta = CodexEvent.fromNotification({
      'method': 'item/agentMessage/delta',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'itemId': 'item_1',
        'delta': 'hello',
      },
    });

    expect(itemStarted.kind, CodexEventKind.itemStarted);
    expect(itemStarted.itemId, 'item_1');
    expect(itemStarted.itemType, 'agentMessage');
    expect(delta.kind, CodexEventKind.agentMessageDelta);
    expect(delta.threadId, 'thr_1');
    expect(delta.turnId, 'turn_1');
    expect(delta.itemId, 'item_1');
    expect(delta.delta, 'hello');
  });

  test('preserves unknown notifications without throwing', () {
    final event = CodexEvent.fromNotification({
      'method': 'future/event',
      'params': {'value': true},
    });

    expect(event.kind, CodexEventKind.unknown);
    expect(event.method, 'future/event');
    expect(event.raw['params'], {'value': true});
  });
}
