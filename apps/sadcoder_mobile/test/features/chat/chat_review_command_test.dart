import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_review_command.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_timeline_controller.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review_runner.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/turns/turn_controller.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test('review command starts review and tracks returned turn', () async {
    final runner = _RecordingThreadReviewRunner(result: _reviewResult());
    final turnController = TurnController(runnerProvider: () => null);
    final timelineController = ChatTimelineController();
    final detailReader = _RecordingThreadDetailReader();
    final detailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    addTearDown(turnController.dispose);
    addTearDown(timelineController.dispose);
    addTearDown(detailController.dispose);
    var refreshCount = 0;

    final summary = await startThreadReviewFromCommand(
      l10n: l10n,
      runner: runner,
      turnController: turnController,
      timelineController: timelineController,
      threadDetailController: detailController,
      refreshVisibleThreads: () => refreshCount++,
      threadId: 'thr_main',
      arguments: 'detached commit abc123 Fix regression',
    );
    await Future<void>.delayed(Duration.zero);

    expect(summary, contains(l10n.threadReviewStarted));
    expect(summary, contains('thr_review'));
    expect(runner.calls, hasLength(1));
    expect(runner.calls.single.threadId, 'thr_main');
    expect(runner.calls.single.delivery, ThreadReviewDelivery.detached);
    expect(runner.calls.single.target.kind, ThreadReviewTargetKind.commit);
    expect(runner.calls.single.target.sha, 'abc123');
    expect(runner.calls.single.target.title, 'Fix regression');
    expect(turnController.activeThreadId, 'thr_review');
    expect(turnController.activeTurnId, 'turn_review');
    expect(timelineController.selectedThreadId, 'thr_review');
    expect(timelineController.turns.single.turnId, 'turn_review');
    expect(refreshCount, 1);
    expect(detailReader.calls, [(threadId: 'thr_review', includeTurns: false)]);
  });

  test('review command rejects unavailable and unsupported inputs', () async {
    final runner = _RecordingThreadReviewRunner(result: _reviewResult());
    final turnController = TurnController(runnerProvider: () => null);
    final timelineController = ChatTimelineController();
    addTearDown(turnController.dispose);
    addTearDown(timelineController.dispose);

    expect(
      await startThreadReviewFromCommand(
        l10n: l10n,
        runner: null,
        turnController: turnController,
        timelineController: timelineController,
        threadDetailController: null,
        refreshVisibleThreads: () {},
        threadId: 'thr_main',
        arguments: '',
      ),
      isNull,
    );
    expect(
      await startThreadReviewFromCommand(
        l10n: l10n,
        runner: runner,
        turnController: null,
        timelineController: timelineController,
        threadDetailController: null,
        refreshVisibleThreads: () {},
        threadId: 'thr_main',
        arguments: '',
      ),
      isNull,
    );
    expect(
      await startThreadReviewFromCommand(
        l10n: l10n,
        runner: runner,
        turnController: turnController,
        timelineController: timelineController,
        threadDetailController: null,
        refreshVisibleThreads: () {},
        threadId: null,
        arguments: '',
      ),
      isNull,
    );
    expect(
      await startThreadReviewFromCommand(
        l10n: l10n,
        runner: runner,
        turnController: turnController,
        timelineController: timelineController,
        threadDetailController: null,
        refreshVisibleThreads: () {},
        threadId: 'thr_main',
        arguments: '--unknown',
      ),
      isNull,
    );
    turnController.trackStartedTurn(
      threadId: 'thr_active',
      turn: _turn('turn_active'),
    );
    expect(
      await startThreadReviewFromCommand(
        l10n: l10n,
        runner: runner,
        turnController: turnController,
        timelineController: timelineController,
        threadDetailController: null,
        refreshVisibleThreads: () {},
        threadId: 'thr_main',
        arguments: '',
      ),
      isNull,
    );
    expect(runner.calls, isEmpty);
    expect(timelineController.turns, isEmpty);
  });
}

class _RecordingThreadReviewRunner implements ThreadReviewRunner {
  _RecordingThreadReviewRunner({required this.result});

  final ThreadReviewStartResult result;
  final calls =
      <
        ({
          String threadId,
          ThreadReviewTarget target,
          ThreadReviewDelivery? delivery,
        })
      >[];

  @override
  Future<ThreadReviewStartResult> startReview({
    required String threadId,
    required ThreadReviewTarget target,
    ThreadReviewDelivery? delivery,
  }) async {
    calls.add((threadId: threadId, target: target, delivery: delivery));
    return result;
  }
}

class _RecordingThreadDetailReader implements ThreadDetailReader {
  final calls = <({String threadId, bool includeTurns})>[];

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    calls.add((threadId: threadId, includeTurns: includeTurns));
    return ThreadDetail(thread: _thread(threadId));
  }
}

ThreadReviewStartResult _reviewResult() {
  return ThreadReviewStartResult(
    reviewThreadId: 'thr_review',
    turn: _turn('turn_review'),
  );
}

TurnSummary _turn(String id) {
  return TurnSummary(
    id: id,
    status: 'inProgress',
    itemCount: 0,
    itemsView: 'notLoaded',
  );
}

ThreadSummary _thread(String id) {
  return ThreadSummary(
    id: id,
    sessionId: 'sess_1',
    preview: 'Review',
    ephemeral: false,
    status: 'active',
    cwd: '/repo',
    updatedAtSeconds: 0,
  );
}
