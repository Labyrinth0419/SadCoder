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
          'cwd': '/repo',
          'status': 'completed',
          'exitCode': 0,
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
    expect(controller.turns.single.items.last.command, 'cargo test');
    expect(controller.turns.single.items.last.cwd, '/repo');
    expect(controller.turns.single.items.last.status, 'completed');
    expect(controller.turns.single.items.last.exitCode, 0);
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

  test('turn start calls start handler', () {
    ({String threadId, TurnSummary turn})? started;
    final controller = ChatTimelineController(
      onTurnStarted: ({required threadId, required turn}) {
        started = (threadId: threadId, turn: turn);
      },
    );
    addTearDown(controller.dispose);

    controller.ingest(_turnStarted());

    expect(started?.threadId, 'thr_1');
    expect(started?.turn.id, 'turn_1');
  });

  test('lastAssistantMessageMarkdown returns the latest assistant text', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.ingest(_agentDelta('item_1', 'first'));
    controller.ingest(_commandDelta('cmd_1', 'command output'));
    controller.ingest(_agentDelta('item_2', 'second'));

    expect(controller.lastAssistantMessageMarkdown(), 'second');
  });

  test('showThread backfills turns and items from thread read detail', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_1',
        'sessionId': 'sess_1',
        'preview': 'Fix bug',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': [
          {
            'id': 'turn_1',
            'status': 'completed',
            'itemsView': 'full',
            'items': [
              {
                'id': 'item_user',
                'type': 'userMessage',
                'content': [
                  {
                    'type': 'text',
                    'text': 'Fix login bug',
                    'text_elements': <Object?>[],
                  },
                ],
              },
              {'id': 'item_agent', 'type': 'agentMessage', 'text': 'Done'},
              {
                'id': 'item_command',
                'type': 'commandExecution',
                'aggregatedOutput': 'tests passed',
              },
            ],
          },
        ],
      }),
    );

    expect(controller.selectedThreadId, 'thr_1');
    expect(controller.turns.single.turnId, 'turn_1');
    expect(controller.turns.single.status, 'completed');
    expect(controller.turns.single.items, hasLength(3));
    expect(controller.turns.single.items[0].text, 'Fix login bug');
    expect(controller.turns.single.items[1].text, 'Done');
    expect(controller.turns.single.items[2].output, 'tests passed');
  });

  test('cursor reports selected thread and seen turn item ids', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_1',
        'sessionId': 'sess_1',
        'preview': 'Fix bug',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': [
          {
            'id': 'turn_1',
            'status': 'completed',
            'itemsView': 'full',
            'items': [
              {'id': 'item_1', 'type': 'agentMessage', 'text': 'First'},
            ],
          },
        ],
      }),
    );
    controller.ingest(_turnStarted(threadId: 'thr_1', turnId: 'turn_2'));
    controller.ingest(_agentDelta('item_2', 'second'));

    final cursor = controller.cursor;
    expect(cursor.threadId, 'thr_1');
    expect(cursor.turnIds, ['turn_1', 'turn_2']);
    expect(cursor.itemIds, ['item_1', 'item_2']);
    expect(cursor.lastTurnId, 'turn_2');
    expect(cursor.lastItemId, 'item_2');

    controller.clear();

    expect(controller.cursor.isEmpty, true);
  });

  test('selectThread preserves live events for the active thread', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.ingest(_turnStarted(threadId: 'thr_1', turnId: 'turn_1'));
    controller.ingest(_agentDelta('item_1', 'streamed'));

    expect(controller.selectedThreadId, 'thr_1');
    controller.selectThread('thr_1');

    expect(controller.turns.single.items.single.text, 'streamed');

    controller.selectThread('thr_2');

    expect(controller.selectedThreadId, 'thr_2');
    expect(controller.turns, isEmpty);
  });

  test('local user message is replaced by real user item', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.showTurn(
      threadId: 'thr_1',
      turn: TurnSummary.fromJson({
        'id': 'turn_1',
        'status': 'inProgress',
        'itemsView': 'notLoaded',
        'items': <Object?>[],
      }),
    );
    controller.showLocalUserMessage(
      threadId: 'thr_1',
      turnId: 'turn_1',
      text: 'Fix login bug',
    );

    expect(controller.turns.single.items.single.itemType, 'userMessage');
    expect(controller.turns.single.items.single.text, 'Fix login bug');
    expect(controller.turns.single.items.single.isLocalUserMessage, true);

    controller.ingest(
      _itemStarted(
        itemId: 'real_user',
        itemType: 'userMessage',
        raw: {
          'id': 'real_user',
          'type': 'userMessage',
          'content': [
            {
              'type': 'text',
              'text': 'Fix login bug',
              'text_elements': <Object?>[],
            },
          ],
        },
      ),
    );

    expect(controller.turns.single.items, hasLength(1));
    expect(controller.turns.single.items.single.itemId, 'real_user');
    expect(controller.turns.single.items.single.isLocalUserMessage, false);
  });

  test('selected thread filters displayed live events only', () {
    ({String threadId, TurnSummary turn})? completed;
    final controller = ChatTimelineController(
      onTurnCompleted: ({required threadId, required turn}) {
        completed = (threadId: threadId, turn: turn);
      },
    );
    addTearDown(controller.dispose);

    controller.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_1',
        'sessionId': 'sess_1',
        'preview': 'Fix bug',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': <Object?>[],
      }),
    );
    controller.ingest(_turnStarted(threadId: 'thr_2', turnId: 'turn_2'));
    controller.ingest(
      _turnCompleted(threadId: 'thr_2', turnId: 'turn_2', status: 'completed'),
    );
    controller.ingest(_agentDelta('item_1', 'visible'));

    expect(controller.turns, hasLength(1));
    expect(controller.turns.single.threadId, 'thr_1');
    expect(controller.turns.single.items.single.text, 'visible');
    expect(completed?.threadId, 'thr_2');
  });

  test('showThread preserves live events that arrived during thread read', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.selectThread('thr_1');
    controller.ingest(_agentDelta('item_agent', 'Done plus live delta'));
    controller.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_1',
        'sessionId': 'sess_1',
        'preview': 'Fix bug',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': [
          {
            'id': 'turn_1',
            'status': 'completed',
            'itemsView': 'full',
            'items': [
              {'id': 'item_agent', 'type': 'agentMessage', 'text': 'Done'},
            ],
          },
        ],
      }),
    );

    expect(controller.turns.single.status, 'completed');
    expect(controller.turns.single.items.single.text, 'Done plus live delta');
  });

  test('showTurn displays an externally started review turn', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_parent',
        'sessionId': 'sess_1',
        'preview': 'Parent',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': [
          {
            'id': 'turn_parent',
            'status': 'completed',
            'itemsView': 'full',
            'items': <Object?>[],
          },
        ],
      }),
    );
    controller.showTurn(
      threadId: 'thr_review',
      turn: TurnSummary.fromJson({
        'id': 'turn_review',
        'status': 'inProgress',
        'itemsView': 'notLoaded',
        'items': [
          {
            'id': 'review_started',
            'type': 'enteredReviewMode',
            'review': 'current changes',
          },
        ],
      }),
    );

    expect(controller.selectedThreadId, 'thr_review');
    expect(controller.turns, hasLength(1));
    expect(controller.turns.single.turnId, 'turn_review');
    expect(controller.turns.single.status, 'inProgress');
    expect(controller.turns.single.items.single.itemType, 'enteredReviewMode');
    expect(controller.turns.single.items.single.text, 'current changes');
  });

  test('restoreCachedItems groups cached items by turn id', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.restoreCachedItems(
      threadId: 'thr_1',
      items: [
        _threadItem('item_1', 'first', turnId: 'turn_1'),
        _threadItem('item_2', 'second', turnId: 'turn_1'),
        _threadItem('item_3', 'third', turnId: 'turn_2'),
      ],
    );

    expect(controller.selectedThreadId, 'thr_1');
    expect(controller.turns.map((turn) => turn.turnId), ['turn_1', 'turn_2']);
    expect(controller.turns.first.items.map((item) => item.text), [
      'first',
      'second',
    ]);
    expect(controller.turns.last.items.single.text, 'third');
  });

  test('restoreCachedItems deduplicates items without turn ids', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_1',
        'sessionId': 'sess_1',
        'preview': 'Fix bug',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': [
          {
            'id': 'turn_1',
            'status': 'completed',
            'itemsView': 'full',
            'items': [
              {'id': 'item_agent', 'type': 'agentMessage', 'text': 'Done'},
            ],
          },
        ],
      }),
    );

    controller.restoreCachedItems(
      threadId: 'thr_1',
      items: [
        _threadItem('item_agent', 'Done plus cached'),
        _threadItem('item_new', 'Recovered without turn id'),
      ],
    );

    expect(controller.turns, hasLength(2));
    expect(controller.turns.first.turnId, 'turn_1');
    expect(controller.turns.first.items.single.text, 'Done plus cached');
    expect(controller.turns.last.turnId, 'cached_items');
    expect(
      controller.turns.last.items.single.text,
      'Recovered without turn id',
    );
  });

  test('ingest maps reasoning file changes and MCP progress into timeline', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.ingest(
      CodexEvent.fromNotification({
        'method': 'item/reasoning/summaryTextDelta',
        'params': {
          'threadId': 'thr_1',
          'turnId': 'turn_1',
          'itemId': 'reason_1',
          'delta': 'first thought',
          'summaryIndex': 0,
        },
      }),
    );
    controller.ingest(
      CodexEvent.fromNotification({
        'method': 'item/reasoning/summaryPartAdded',
        'params': {
          'threadId': 'thr_1',
          'turnId': 'turn_1',
          'itemId': 'reason_1',
          'summaryIndex': 1,
        },
      }),
    );
    controller.ingest(
      CodexEvent.fromNotification({
        'method': 'item/reasoning/summaryTextDelta',
        'params': {
          'threadId': 'thr_1',
          'turnId': 'turn_1',
          'itemId': 'reason_1',
          'delta': 'second thought',
          'summaryIndex': 1,
        },
      }),
    );
    controller.ingest(
      CodexEvent.fromNotification({
        'method': 'item/fileChange/patchUpdated',
        'params': {
          'threadId': 'thr_1',
          'turnId': 'turn_1',
          'itemId': 'file_1',
          'changes': [
            {'path': 'lib/main.dart', 'kind': 'modify', 'diff': '@@'},
          ],
        },
      }),
    );
    controller.ingest(
      CodexEvent.fromNotification({
        'method': 'item/mcpToolCall/progress',
        'params': {
          'threadId': 'thr_1',
          'turnId': 'turn_1',
          'itemId': 'mcp_1',
          'message': 'searching',
        },
      }),
    );

    final items = controller.turns.single.items;
    expect(items.map((item) => item.itemType), [
      'reasoning',
      'fileChange',
      'mcpToolCall',
    ]);
    expect(items[0].text, 'first thought\n\nsecond thought');
    expect(items[1].fileChanges.single.path, 'lib/main.dart');
    expect(items[2].text, 'searching');
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

  test('auto-review denials are cached without timeline items', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    controller.ingest(_autoReviewCompleted(reviewId: 'review_approved'));
    controller.ingest(
      _autoReviewCompleted(reviewId: 'review_1', status: 'denied'),
    );
    controller.ingest(
      _autoReviewCompleted(
        threadId: 'thr_2',
        turnId: 'turn_2',
        reviewId: 'review_2',
        status: 'denied',
      ),
    );

    expect(controller.turns, isEmpty);
    expect(controller.recentAutoReviewDenials.map((event) => event.id), [
      'review_2',
      'review_1',
    ]);
    expect(controller.latestAutoReviewDenial()?.id, 'review_2');
    expect(
      controller.latestAutoReviewDenial(threadId: 'thr_1')?.id,
      'review_1',
    );
    expect(
      controller.latestAutoReviewDenial(threadId: 'thr_2')?.id,
      'review_2',
    );
  });

  test('auto-review denial cache replaces duplicates and keeps latest ten', () {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    for (var index = 0; index < 12; index++) {
      controller.ingest(
        _autoReviewCompleted(reviewId: 'review_$index', status: 'denied'),
      );
    }
    controller.ingest(
      _autoReviewCompleted(reviewId: 'review_8', status: 'denied'),
    );

    expect(controller.recentAutoReviewDenials, hasLength(10));
    expect(controller.recentAutoReviewDenials.first.id, 'review_8');
    expect(
      controller.recentAutoReviewDenials.map((event) => event.id),
      isNot(contains('review_0')),
    );
    expect(
      controller.recentAutoReviewDenials.map((event) => event.id),
      isNot(contains('review_1')),
    );
  });
}

ThreadItemSummary _threadItem(String id, String text, {String? turnId}) {
  final json = <String, Object?>{
    'id': id,
    'type': 'agentMessage',
    'text': text,
  };
  if (turnId != null) {
    json['turnId'] = turnId;
  }
  return ThreadItemSummary.fromJson(json);
}

CodexEvent _turnStarted({String threadId = 'thr_1', String turnId = 'turn_1'}) {
  return CodexEvent.fromNotification({
    'method': 'turn/started',
    'params': {
      'threadId': threadId,
      'turn': {
        'id': turnId,
        'status': 'inProgress',
        'items': <Object?>[],
        'itemsView': 'notLoaded',
      },
    },
  });
}

CodexEvent _turnCompleted({
  String threadId = 'thr_1',
  String turnId = 'turn_1',
  required String status,
}) {
  return CodexEvent.fromNotification({
    'method': 'turn/completed',
    'params': {
      'threadId': threadId,
      'turn': {
        'id': turnId,
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

CodexEvent _autoReviewCompleted({
  String threadId = 'thr_1',
  String turnId = 'turn_1',
  required String reviewId,
  String status = 'approved',
}) {
  return CodexEvent.fromNotification({
    'method': 'item/autoApprovalReview/completed',
    'params': {
      'threadId': threadId,
      'turnId': turnId,
      'startedAtMs': 1000,
      'completedAtMs': 1042,
      'reviewId': reviewId,
      'targetItemId': 'item_$reviewId',
      'decisionSource': 'agent',
      'review': {
        'status': status,
        'riskLevel': 'high',
        'userAuthorization': 'low',
        'rationale': 'too risky',
      },
      'action': {
        'type': 'command',
        'source': 'shell',
        'command': 'rm -rf /tmp/test',
        'cwd': '/repo',
      },
    },
  });
}
