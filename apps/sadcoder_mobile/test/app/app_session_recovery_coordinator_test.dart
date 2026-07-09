import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/app/app_session_recovery_coordinator.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
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
    fixture.threadDetailReader.threadIds.clear();

    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    fixture.coordinator.handleSessionStatus(CodexSessionStatus.reconnecting);
    fixture.coordinator.handleSessionStatus(CodexSessionStatus.connected);
    await _flushMicrotasks();

    expect(fixture.threadListReader.limits, [20, 20]);
    expect(fixture.threadDetailReader.threadIds, [
      'thr_selected',
      'thr_selected',
    ]);
  });

  test('rereads the active turn thread before the selected thread', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.threadDetailController.readThread('thr_selected');
    fixture.threadDetailReader.threadIds.clear();
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
  _Fixture()
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
  Future<ThreadListPage> listThreads({int limit = 20}) async {
    limits.add(limit);
    return ThreadListPage(threads: [_thread('thr_selected')]);
  }
}

class _RecordingThreadDetailReader implements ThreadDetailReader {
  final threadIds = <String>[];

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    threadIds.add(threadId);
    return ThreadDetail(thread: _thread(threadId));
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

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}
