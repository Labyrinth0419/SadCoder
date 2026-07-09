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

  test('maps reasoning file change and MCP progress notifications', () {
    final reasoning = CodexEvent.fromNotification({
      'method': 'item/reasoning/summaryTextDelta',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'itemId': 'reason_1',
        'delta': 'thinking',
        'summaryIndex': 0,
      },
    });
    final patch = CodexEvent.fromNotification({
      'method': 'item/fileChange/patchUpdated',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'itemId': 'file_1',
        'changes': [
          {'path': 'lib/main.dart', 'kind': 'modify', 'diff': '@@'},
        ],
      },
    });
    final progress = CodexEvent.fromNotification({
      'method': 'item/mcpToolCall/progress',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'itemId': 'mcp_1',
        'message': 'searching',
      },
    });

    expect(reasoning.kind, CodexEventKind.reasoningDelta);
    expect(reasoning.itemId, 'reason_1');
    expect(reasoning.delta, 'thinking');
    expect(patch.kind, CodexEventKind.fileChangePatchUpdated);
    expect(patch.fileChanges?.single.path, 'lib/main.dart');
    expect(progress.kind, CodexEventKind.mcpToolCallProgress);
    expect(progress.delta, 'searching');
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
