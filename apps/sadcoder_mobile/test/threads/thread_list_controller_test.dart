import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

void main() {
  test('refresh loads threads from current reader', () async {
    final reader = _FakeThreadListReader(
      page: ThreadListPage(
        threads: [
          ThreadSummary.fromJson({
            'id': 'thr_1',
            'sessionId': 'sess_1',
            'preview': 'Fix bug',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
          }),
        ],
      ),
    );
    final controller = ThreadListController(readerProvider: () => reader);
    addTearDown(controller.dispose);
    final statuses = <ThreadListStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.refresh(limit: 5, archived: true);

    expect(reader.limits, [5]);
    expect(reader.archivedFilters, [true]);
    expect(controller.status, ThreadListStatus.loaded);
    expect(controller.threads.single.id, 'thr_1');
    expect(statuses, [ThreadListStatus.loading, ThreadListStatus.loaded]);
  });

  test(
    'refresh without a reader returns to idle without clearing cache',
    () async {
      _FakeThreadListReader? reader = _FakeThreadListReader(
        page: ThreadListPage(
          threads: [
            ThreadSummary.fromJson({
              'id': 'thr_1',
              'sessionId': 'sess_1',
              'preview': 'Fix bug',
              'ephemeral': false,
              'status': 'idle',
              'cwd': '/repo',
              'updatedAt': 1,
            }),
          ],
        ),
      );
      final controller = ThreadListController(readerProvider: () => reader);
      addTearDown(controller.dispose);

      await controller.refresh();
      reader = null;
      await controller.refresh();

      expect(controller.status, ThreadListStatus.idle);
      expect(controller.threads.single.id, 'thr_1');
    },
  );

  test('refresh records failures', () async {
    final controller = ThreadListController(
      readerProvider: () => _FailingThreadListReader(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.status, ThreadListStatus.failed);
    expect(controller.error, isA<StateError>());
  });
}

class _FakeThreadListReader implements ThreadListReader {
  _FakeThreadListReader({required this.page});

  final ThreadListPage page;
  final limits = <int>[];
  final archivedFilters = <bool>[];

  @override
  Future<ThreadListPage> listThreads({
    int limit = 20,
    bool archived = false,
  }) async {
    limits.add(limit);
    archivedFilters.add(archived);
    return page;
  }
}

class _FailingThreadListReader implements ThreadListReader {
  @override
  Future<ThreadListPage> listThreads({int limit = 20, bool archived = false}) {
    throw StateError('thread list failed');
  }
}
