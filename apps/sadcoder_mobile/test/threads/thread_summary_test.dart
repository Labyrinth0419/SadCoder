import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

void main() {
  test('ThreadListPage parses app-server thread/list response', () {
    final page = ThreadListPage.fromJson({
      'data': [
        {
          'id': 'thr_1',
          'sessionId': 'sess_1',
          'preview': 'Fix CI failure',
          'ephemeral': false,
          'status': 'running',
          'cwd': '/repo',
          'updatedAt': 123,
          'name': 'CI fix',
          'forkedFromId': 'thr_0',
          'parentThreadId': null,
          'ancestorThreadId': 'thr_root',
        },
      ],
      'nextCursor': 'next',
      'backwardsCursor': 'back',
    });

    expect(page.nextCursor, 'next');
    expect(page.backwardsCursor, 'back');
    expect(page.threads.single.id, 'thr_1');
    expect(page.threads.single.title, 'CI fix');
    expect(page.threads.single.isFork, true);
    expect(page.threads.single.isSubagent, true);
    expect(page.threads.single.ancestorThreadId, 'thr_root');
    expect(page.threads.single.cwd, '/repo');
  });

  test('ThreadSummary falls back to preview and id for title', () {
    final previewThread = ThreadSummary.fromJson({
      'id': 'thr_1',
      'sessionId': 'sess_1',
      'preview': 'Write docs',
      'ephemeral': false,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
    });
    final idThread = ThreadSummary.fromJson({
      'id': 'thr_2',
      'sessionId': 'sess_1',
      'preview': '',
      'ephemeral': false,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
    });

    expect(previewThread.title, 'Write docs');
    expect(idThread.title, 'thr_2');
  });

  test('ThreadSummary detail JSON includes current backfilled turns', () {
    final thread =
        ThreadSummary.fromJson({
          'id': 'thr_1',
          'sessionId': 'sess_1',
          'preview': 'Fix bug',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': <Object?>[],
        }).copyWith(
          turns: [
            TurnSummary.fromJson({
              'id': 'turn_backfilled',
              'status': 'completed',
              'items': <Object?>[],
            }),
          ],
        );

    final json = thread.toDetailJson();
    final turns = json['turns'] as List<Object?>;

    expect((turns.single as Map<String, Object?>)['id'], 'turn_backfilled');
  });

  test('ThreadDetail parses turns from thread/read response', () {
    final detail = ThreadDetail.fromJson({
      'thread': {
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
            'items': [
              {
                'id': 'item_1',
                'type': 'userMessage',
                'content': [
                  {
                    'type': 'text',
                    'text': 'Fix this bug',
                    'text_elements': <Object?>[],
                  },
                ],
              },
              {
                'id': 'item_2',
                'type': 'commandExecution',
                'command': 'cargo test',
                'cwd': '/repo',
                'status': 'completed',
                'exitCode': 0,
                'durationMs': 1200,
                'aggregatedOutput': 'ok',
              },
              {
                'id': 'item_3',
                'type': 'fileChange',
                'status': 'completed',
                'changes': [
                  {'path': 'lib/main.dart', 'kind': 'modify', 'diff': '@@'},
                ],
              },
              {
                'id': 'item_4',
                'type': 'mcpToolCall',
                'server': 'github',
                'tool': 'search_issues',
                'status': 'completed',
              },
              {
                'id': 'item_5',
                'type': 'exitedReviewMode',
                'review': 'Looks solid overall.',
              },
            ],
            'itemsView': 'full',
            'startedAt': 10,
            'completedAt': 20,
            'durationMs': 1000,
          },
          {
            'id': 'turn_2',
            'status': 'failed',
            'items': <Object?>[],
            'itemsView': 'notLoaded',
            'error': {'message': 'failed turn'},
          },
        ],
      },
    });

    expect(detail.thread.id, 'thr_1');
    expect(detail.turns, hasLength(2));
    expect(detail.turns.first.id, 'turn_1');
    expect(detail.turns.first.itemCount, 5);
    expect(detail.turns.first.itemsView, 'full');
    expect(detail.turns.first.durationMs, 1000);
    expect(detail.turns.first.items.first.type, 'userMessage');
    expect(detail.turns.first.items.first.text, 'Fix this bug');
    expect(detail.turns.first.items[1].type, 'commandExecution');
    expect(detail.turns.first.items[1].command, 'cargo test');
    expect(detail.turns.first.items[1].cwd, '/repo');
    expect(detail.turns.first.items[1].status, 'completed');
    expect(detail.turns.first.items[1].exitCode, 0);
    expect(detail.turns.first.items[1].durationMs, 1200);
    expect(detail.turns.first.items[1].output, 'ok');
    expect(
      detail.turns.first.items[2].fileChanges.single.path,
      'lib/main.dart',
    );
    expect(detail.turns.first.items[3].server, 'github');
    expect(detail.turns.first.items[3].tool, 'search_issues');
    expect(detail.turns.first.items[4].type, 'exitedReviewMode');
    expect(detail.turns.first.items[4].text, 'Looks solid overall.');
    expect(detail.turns.last.errorMessage, 'failed turn');
  });

  test('ThreadTurnsPage parses paginated thread turns response', () {
    final page = ThreadTurnsPage.fromJson({
      'data': [
        {
          'id': 'turn_1',
          'status': 'completed',
          'itemsView': 'summary',
          'items': [
            {
              'id': 'item_1',
              'type': 'userMessage',
              'content': [
                {'type': 'text', 'text': 'Backfill this turn'},
              ],
            },
          ],
          'startedAt': 10,
          'completedAt': 12,
          'durationMs': 2000,
        },
      ],
      'nextCursor': 'older',
      'backwardsCursor': 'newer',
    });

    expect(page.turns.single.id, 'turn_1');
    expect(page.turns.single.itemsView, 'summary');
    expect(page.turns.single.items.single.text, 'Backfill this turn');
    expect(page.nextCursor, 'older');
    expect(page.backwardsCursor, 'newer');
  });

  test('ThreadItemsPage parses paginated thread items response', () {
    final page = ThreadItemsPage.fromJson({
      'data': [
        {
          'id': 'item_command',
          'type': 'commandExecution',
          'command': 'cargo test',
          'cwd': '/repo',
          'status': 'completed',
          'exitCode': 0,
          'aggregatedOutput': 'ok',
        },
      ],
      'nextCursor': 'next_item',
      'backwardsCursor': 'previous_item',
    });

    expect(page.items.single.id, 'item_command');
    expect(page.items.single.command, 'cargo test');
    expect(page.items.single.output, 'ok');
    expect(page.nextCursor, 'next_item');
    expect(page.backwardsCursor, 'previous_item');
  });

  test('ThreadItemSummary parses collab agent and subagent activity items', () {
    final collab = ThreadItemSummary.fromJson({
      'id': 'item_spawn',
      'type': 'collabAgentToolCall',
      'tool': 'spawnAgent',
      'status': 'completed',
      'senderThreadId': 'thr_main',
      'receiverThreadIds': ['thr_worker'],
      'prompt': 'Build the patch',
      'model': 'gpt-5',
      'reasoningEffort': 'high',
      'agentsStates': {
        'thr_worker': {'status': 'running', 'message': null},
      },
    });
    final activity = ThreadItemSummary.fromJson({
      'id': 'item_activity',
      'type': 'subAgentActivity',
      'kind': 'started',
      'agentThreadId': 'thr_worker',
      'agentPath': 'agents/build',
    });

    expect(collab.tool, 'spawnAgent');
    expect(collab.status, 'completed');
    expect(collab.senderThreadId, 'thr_main');
    expect(collab.receiverThreadIds, ['thr_worker']);
    expect(collab.prompt, 'Build the patch');
    expect(collab.model, 'gpt-5');
    expect(collab.reasoningEffort, 'high');
    expect(collab.agentStates['thr_worker']?.status, 'running');
    expect(collab.text, 'Build the patch');
    expect(activity.activityKind, 'started');
    expect(activity.agentThreadId, 'thr_worker');
    expect(activity.agentPath, 'agents/build');
    expect(activity.text, 'started agents/build');
  });

  test('ThreadItemSummary JSON includes parsed item fields', () {
    final item = ThreadItemSummary.fromJson({
      'id': 'item_cmd',
      'type': 'commandExecution',
      'command': 'cargo test',
      'cwd': '/repo',
      'status': 'completed',
      'exitCode': 0,
      'durationMs': 120,
      'aggregatedOutput': 'ok',
    });

    expect(item.toJson(), {
      'id': 'item_cmd',
      'type': 'commandExecution',
      'text': '',
      'aggregatedOutput': 'ok',
      'command': 'cargo test',
      'cwd': '/repo',
      'status': 'completed',
      'exitCode': 0,
      'durationMs': 120,
    });
  });
}
