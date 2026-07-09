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
}
