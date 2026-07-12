import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/usage/thread_token_usage_controller.dart';

void main() {
  test('parses canonical camelCase token usage payload', () {
    final controller = ThreadTokenUsageController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.ingestTokenUsageUpdated({
      'threadId': 'thr_1',
      'turnId': 'turn_1',
      'tokenUsage': {
        'last': {
          'cachedInputTokens': 2,
          'inputTokens': 10,
          'outputTokens': 5,
          'reasoningOutputTokens': 1,
          'totalTokens': 16,
        },
        'total': {
          'cachedInputTokens': 4,
          'inputTokens': 100,
          'outputTokens': 50,
          'reasoningOutputTokens': 10,
          'totalTokens': 160,
        },
        'modelContextWindow': 200000,
      },
    });

    final snapshot = controller.latestForThread('thr_1');
    expect(notifications, 1);
    expect(controller.latest, same(snapshot));
    expect(snapshot?.threadId, 'thr_1');
    expect(snapshot?.turnId, 'turn_1');
    expect(snapshot?.usage.last.totalTokens, 16);
    expect(snapshot?.usage.total.inputTokens, 100);
    expect(snapshot?.usage.modelContextWindow, 200000);
  });

  test('parses snake_case token usage payload', () {
    final controller = ThreadTokenUsageController();
    addTearDown(controller.dispose);

    controller.ingestTokenUsageUpdated({
      'thread_id': 'thr_2',
      'turn_id': 'turn_2',
      'token_usage': {
        'last': {
          'cached_input_tokens': '3',
          'input_tokens': '11',
          'output_tokens': '7',
          'reasoning_output_tokens': '2',
          'total_tokens': '20',
        },
        'total': {
          'cached_input_tokens': 6,
          'input_tokens': 110,
          'output_tokens': 70,
          'reasoning_output_tokens': 20,
          'total_tokens': 200,
        },
        'model_context_window': '128000',
      },
    });

    final snapshot = controller.latestForThread('thr_2');
    expect(snapshot?.usage.last.cachedInputTokens, 3);
    expect(snapshot?.usage.last.totalTokens, 20);
    expect(snapshot?.usage.total.reasoningOutputTokens, 20);
    expect(snapshot?.usage.modelContextWindow, 128000);
  });

  test('malformed token usage payloads do not notify', () {
    final controller = ThreadTokenUsageController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.ingestTokenUsageUpdated({'threadId': 'thr_1'});
    controller.ingestTokenUsageUpdated({
      'threadId': 'thr_1',
      'turnId': 'turn_1',
      'tokenUsage': {
        'last': {'totalTokens': 1},
        'total': {'totalTokens': 1},
      },
    });

    expect(notifications, 0);
    expect(controller.latest, isNull);
    expect(controller.snapshotsByThread, isEmpty);
  });

  test('stores latest snapshot per thread and globally', () {
    final controller = ThreadTokenUsageController();
    addTearDown(controller.dispose);

    controller.ingestTokenUsageUpdated(_payload('thr_1', 'turn_1', total: 10));
    controller.ingestTokenUsageUpdated(_payload('thr_2', 'turn_2', total: 20));
    controller.ingestTokenUsageUpdated(_payload('thr_1', 'turn_3', total: 30));

    expect(controller.snapshotsByThread.keys, containsAll(['thr_1', 'thr_2']));
    expect(controller.latestForThread('thr_1')?.turnId, 'turn_3');
    expect(controller.latestForThread('thr_1')?.usage.total.totalTokens, 30);
    expect(controller.latestForThread('thr_2')?.turnId, 'turn_2');
    expect(controller.latest?.threadId, 'thr_1');
    expect(controller.latest?.turnId, 'turn_3');
  });
}

Map<String, Object?> _payload(String threadId, String turnId, {int total = 1}) {
  return {
    'threadId': threadId,
    'turnId': turnId,
    'tokenUsage': {
      'last': {
        'cachedInputTokens': 0,
        'inputTokens': total,
        'outputTokens': 0,
        'reasoningOutputTokens': 0,
        'totalTokens': total,
      },
      'total': {
        'cachedInputTokens': 0,
        'inputTokens': total,
        'outputTokens': 0,
        'reasoningOutputTokens': 0,
        'totalTokens': total,
      },
    },
  };
}
