import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/app/app_session_recovery_coordinator.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/threads/thread_turn_list_reader.dart';
import 'package:sadcoder_mobile/src/turns/turn_controller.dart';

void main() {
  test('refreshes thread list once when session becomes connected', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.idle);
    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(fixture.threadListReader.limits, [20]);
    expect(fixture.threadDetailReader.threadIds, isEmpty);
  });

  test('rereads the selected thread after reconnect', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    fixture.coordinator.handleSessionStatus(CodexSessionStatus.reconnecting);
    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(fixture.threadListReader.limits, [20, 20]);
    expect(fixture.threadDetailReader.threadIds, [
      'thr_selected',
      'thr_selected',
    ]);
    expect(fixture.threadDetailReader.includeTurnsValues, [true, true]);
  });

  test(
    'backfills recent turns after reconnect with thread turns list',
    () async {
      final turnListReader = _RecordingThreadTurnListReader(
        page: ThreadTurnsPage(
          turns: [
            _turn('turn_newer', 'completed', 'newer'),
            _turn('turn_older', 'completed', 'older'),
          ],
          nextCursor: 'older_cursor',
          backwardsCursor: 'newer_cursor',
        ),
      );
      final fixture = _Fixture(threadTurnListReader: turnListReader);
      addTearDown(fixture.dispose);
      await fixture.threadDetailController.readThread('thr_selected');
      fixture.threadDetailReader.clear();

      fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
      await _flushMicrotasks();

      expect(fixture.threadDetailReader.threadIds, ['thr_selected']);
      expect(fixture.threadDetailReader.includeTurnsValues, [false]);
      expect(turnListReader.calls, [
        (
          threadId: 'thr_selected',
          limit: 50,
          sortDirection: 'desc',
          itemsView: 'full',
        ),
      ]);
      expect(
        fixture.threadDetailController.detail?.turns.map((turn) => turn.id),
        ['turn_older', 'turn_newer'],
      );
      expect(
        fixture.threadDetailController.detail?.turns.last.items.single.text,
        'newer',
      );
    },
  );

  test('falls back to full thread read when turns backfill fails', () async {
    final fixture = _Fixture(
      threadTurnListReader: _FailingThreadTurnListReader(),
    );
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(fixture.threadDetailReader.threadIds, [
      'thr_selected',
      'thr_selected',
    ]);
    expect(fixture.threadDetailReader.includeTurnsValues, [false, true]);
  });

  test('rereads the active turn thread before the selected thread', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.clear();
    fixture.turnController.trackStartedTurn(
      threadId: 'thr_active',
      turn: const TurnSummary(
        id: 'turn_1',
        status: 'running',
        itemCount: 0,
        itemsView: 'notLoaded',
      ),
    );

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(fixture.threadDetailReader.threadIds, ['thr_active']);
  });
}

class _Fixture {
  _Fixture({ThreadTurnListReader? threadTurnListReader})
    : threadListReader = _RecordingThreadListReader(),
      threadDetailReader = _RecordingThreadDetailReader() {
    threadListController = ThreadListController(
      readerProvider: () => threadListReader,
    );
    threadDetailController = ThreadDetailController(
      readerProvider: () => threadDetailReader,
    );
    turnController = TurnController(runnerProvider: () => null);
    coordinator = AppSessionRecoveryCoordinator(
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      threadTurnListReaderProvider: threadTurnListReader == null
          ? null
          : () => threadTurnListReader,
    );
  }

  final _RecordingThreadListReader threadListReader;
  final _RecordingThreadDetailReader threadDetailReader;
  late final ThreadListController threadListController;
  late final ThreadDetailController threadDetailController;
  late final TurnController turnController;
  late final AppSessionRecoveryCoordinator coordinator;

  void dispose() {
    threadListController.dispose();
    threadDetailController.dispose();
    turnController.dispose();
  }
}

class _RecordingThreadListReader implements ThreadListReader {
  final limits = <int>[];

  @override
  Future<ThreadListPage> listThreads({
    int limit = 20,
    bool archived = false,
  }) async {
    limits.add(limit);
    return ThreadListPage(threads: [_thread('thr_selected')]);
  }
}

class _RecordingThreadDetailReader implements ThreadDetailReader {
  final threadIds = <String>[];
  final includeTurnsValues = <bool>[];

  void clear() {
    threadIds.clear();
    includeTurnsValues.clear();
  }

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    threadIds.add(threadId);
    includeTurnsValues.add(includeTurns);
    return ThreadDetail(thread: _thread(threadId));
  }
}

class _RecordingThreadTurnListReader implements ThreadTurnListReader {
  _RecordingThreadTurnListReader({required this.page});

  final ThreadTurnsPage page;
  final calls =
      <
        ({
          String threadId,
          int? limit,
          String? sortDirection,
          String? itemsView,
        })
      >[];

  @override
  Future<ThreadTurnsPage> listTurns({
    required String threadId,
    String? cursor,
    int? limit,
    String? sortDirection,
    String? itemsView,
  }) async {
    calls.add((
      threadId: threadId,
      limit: limit,
      sortDirection: sortDirection,
      itemsView: itemsView,
    ));
    return page;
  }
}

class _FailingThreadTurnListReader implements ThreadTurnListReader {
  @override
  Future<ThreadTurnsPage> listTurns({
    required String threadId,
    String? cursor,
    int? limit,
    String? sortDirection,
    String? itemsView,
  }) async {
    throw StateError('turns list failed');
  }
}

ThreadSummary _thread(String id) {
  return ThreadSummary.fromJson({
    'id': id,
    'sessionId': 'sess_1',
    'preview': id,
    'ephemeral': false,
    'status': 'idle',
    'cwd': '/repo',
    'updatedAt': 1,
  });
}

TurnSummary _turn(String id, String status, String text) {
  return TurnSummary.fromJson({
    'id': id,
    'status': status,
    'itemsView': 'full',
    'items': [
      {'id': '${id}_item', 'type': 'agentMessage', 'text': text},
    ],
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
