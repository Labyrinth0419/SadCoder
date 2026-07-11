import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

void main() {
  test('readThread loads detail from current reader', () async {
    final reader = _FakeThreadDetailReader(detail: _detail('thr_1'));
    final controller = ThreadDetailController(readerProvider: () => reader);
    addTearDown(controller.dispose);
    final statuses = <ThreadDetailStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.readThread('thr_1', includeTurns: false);

    expect(reader.threadIds, ['thr_1']);
    expect(reader.includeTurnsValues, [false]);
    expect(controller.status, ThreadDetailStatus.loaded);
    expect(controller.selectedThreadId, 'thr_1');
    expect(controller.detail?.thread.id, 'thr_1');
    expect(statuses, [ThreadDetailStatus.loading, ThreadDetailStatus.loaded]);
  });

  test('readThread without a reader records failure', () async {
    final controller = ThreadDetailController(readerProvider: () => null);
    addTearDown(controller.dispose);

    await controller.readThread('thr_1');

    expect(controller.status, ThreadDetailStatus.failed);
    expect(controller.selectedThreadId, 'thr_1');
    expect(controller.detail, isNull);
    expect(controller.error, isA<StateError>());
  });

  test('readThread records reader failures', () async {
    final controller = ThreadDetailController(
      readerProvider: () => _FailingThreadDetailReader(),
    );
    addTearDown(controller.dispose);

    await controller.readThread('thr_1');

    expect(controller.status, ThreadDetailStatus.failed);
    expect(controller.detail, isNull);
    expect(controller.error, isA<StateError>());
  });

  test('clear resets loaded detail and selection', () async {
    final controller = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(detail: _detail('thr_1')),
    );
    addTearDown(controller.dispose);

    await controller.readThread('thr_1');
    controller.clear();

    expect(controller.status, ThreadDetailStatus.idle);
    expect(controller.selectedThreadId, isNull);
    expect(controller.detail, isNull);
    expect(controller.error, isNull);
  });

  test('restoreCachedSelection restores selection without cached detail', () {
    final controller = ThreadDetailController(readerProvider: () => null);
    addTearDown(controller.dispose);

    controller.restoreCachedSelection(' thr_cached ');

    expect(controller.status, ThreadDetailStatus.idle);
    expect(controller.selectedThreadId, 'thr_cached');
    expect(controller.detail, isNull);
    expect(controller.error, isNull);
  });

  test('restoreCachedDetail restores loaded cached thread detail', () {
    final controller = ThreadDetailController(readerProvider: () => null);
    addTearDown(controller.dispose);
    final detail = _detail('thr_cached');

    controller.restoreCachedDetail(detail.thread);

    expect(controller.status, ThreadDetailStatus.loaded);
    expect(controller.selectedThreadId, 'thr_cached');
    expect(controller.detail?.thread.id, 'thr_cached');
    expect(controller.detail?.thread.turns.single.id, 'turn_1');
    expect(controller.error, isNull);
  });
}

ThreadDetail _detail(String threadId) {
  return ThreadDetail(
    thread: ThreadSummary.fromJson({
      'id': threadId,
      'sessionId': 'sess_1',
      'preview': 'Fake thread',
      'ephemeral': false,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'turns': [
        {'id': 'turn_1', 'status': 'completed', 'items': <Object?>[]},
      ],
    }),
  );
}

class _FakeThreadDetailReader implements ThreadDetailReader {
  _FakeThreadDetailReader({required this.detail});

  final ThreadDetail detail;
  final threadIds = <String>[];
  final includeTurnsValues = <bool>[];

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    threadIds.add(threadId);
    includeTurnsValues.add(includeTurns);
    return detail;
  }
}

class _FailingThreadDetailReader implements ThreadDetailReader {
  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) {
    throw StateError('thread detail failed');
  }
}
