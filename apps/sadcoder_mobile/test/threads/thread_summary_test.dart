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
}
