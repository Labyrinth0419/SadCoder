import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/turns/turn_controller.dart';
import 'package:sadcoder_mobile/src/turns/turn_runner.dart';

void main() {
  test('submitText starts a thread before sending first turn', () async {
    final runner = _FakeTurnRunner();
    final controller = TurnController(runnerProvider: () => runner);
    addTearDown(controller.dispose);
    final statuses = <TurnControllerStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.submitText(' Fix bug ');

    expect(runner.startedThreads, 1);
    expect(runner.startedTurns, [(threadId: 'thr_new', text: 'Fix bug')]);
    expect(controller.status, TurnControllerStatus.submitted);
    expect(controller.activeThreadId, 'thr_new');
    expect(controller.activeTurnId, 'turn_1');
    expect(statuses, [
      TurnControllerStatus.startingThread,
      TurnControllerStatus.sendingTurn,
      TurnControllerStatus.submitted,
    ]);
  });

  test('submitText resumes selected thread before sending', () async {
    final runner = _FakeTurnRunner();
    var selectedThreadId = 'thr_existing';
    final controller = TurnController(
      runnerProvider: () => runner,
      activeThreadIdProvider: () => selectedThreadId,
    );
    addTearDown(controller.dispose);

    await controller.submitText('Continue');

    expect(runner.startedThreads, 0);
    expect(runner.resumedThreads, ['thr_existing']);
    expect(runner.startedTurns, [(threadId: 'thr_existing', text: 'Continue')]);
    expect(controller.activeThreadId, 'thr_existing');

    controller.clearActiveTurn();
    selectedThreadId = 'thr_existing';
    await controller.submitText('Follow up');

    expect(runner.resumedThreads, ['thr_existing']);
    expect(runner.startedTurns.last, (
      threadId: 'thr_existing',
      text: 'Follow up',
    ));
  });

  test(
    'interruptActiveTurn sends explicit interrupt only for active turn',
    () async {
      final runner = _FakeTurnRunner();
      final controller = TurnController(runnerProvider: () => runner);
      addTearDown(controller.dispose);

      await controller.submitText('Run long task');
      await controller.interruptActiveTurn();

      expect(runner.interruptedTurns, [
        (threadId: 'thr_new', turnId: 'turn_1'),
      ]);
      expect(controller.status, TurnControllerStatus.interrupted);
      expect(controller.activeTurnId, isNull);
    },
  );

  test('finishTurn clears active turn and restores submit ability', () async {
    final runner = _FakeTurnRunner();
    final controller = TurnController(runnerProvider: () => runner);
    addTearDown(controller.dispose);

    await controller.submitText('Run task');
    controller.finishTurn(
      threadId: 'thr_new',
      turn: TurnSummary.fromJson({
        'id': 'turn_1',
        'status': 'completed',
        'items': <Object?>[],
        'itemsView': 'full',
      }),
    );

    expect(controller.status, TurnControllerStatus.completed);
    expect(controller.activeTurnId, isNull);
    expect(controller.canSubmit, true);
  });

  test('clearLocalConversation clears local thread and turn state', () async {
    final runner = _FakeTurnRunner();
    final controller = TurnController(runnerProvider: () => runner);
    addTearDown(controller.dispose);

    await controller.submitText('Run task');
    controller.clearLocalConversation();

    expect(controller.status, TurnControllerStatus.idle);
    expect(controller.activeThreadId, isNull);
    expect(controller.activeTurnId, isNull);
    expect(controller.lastTurn, isNull);
    expect(runner.interruptedTurns, isEmpty);
  });

  test(
    'startNewThread starts a new idle thread without sending a turn',
    () async {
      final runner = _FakeTurnRunner();
      final controller = TurnController(runnerProvider: () => runner);
      addTearDown(controller.dispose);

      final started = await controller.startNewThread();

      expect(started, true);
      expect(runner.startedThreads, 1);
      expect(runner.startedTurns, isEmpty);
      expect(controller.status, TurnControllerStatus.idle);
      expect(controller.activeThreadId, 'thr_new');
      expect(controller.activeTurnId, isNull);
    },
  );

  test('resumeThread resumes an idle thread without sending a turn', () async {
    final runner = _FakeTurnRunner();
    final controller = TurnController(runnerProvider: () => runner);
    addTearDown(controller.dispose);

    final resumed = await controller.resumeThread(' thr_existing ');

    expect(resumed, true);
    expect(runner.resumedThreads, ['thr_existing']);
    expect(runner.startedThreads, 0);
    expect(runner.startedTurns, isEmpty);
    expect(controller.status, TurnControllerStatus.idle);
    expect(controller.activeThreadId, 'thr_existing');
    expect(controller.activeTurnId, isNull);
  });

  test('resumeThread is unavailable while a turn is active', () async {
    final runner = _FakeTurnRunner();
    final controller = TurnController(runnerProvider: () => runner);
    addTearDown(controller.dispose);

    await controller.submitText('Run long task');
    final resumed = await controller.resumeThread('thr_other');

    expect(resumed, false);
    expect(runner.resumedThreads, isEmpty);
    expect(controller.activeThreadId, 'thr_new');
    expect(controller.activeTurnId, 'turn_1');
  });

  test('startNewThread is unavailable while a turn is active', () async {
    final runner = _FakeTurnRunner();
    final controller = TurnController(runnerProvider: () => runner);
    addTearDown(controller.dispose);

    await controller.submitText('Run long task');
    final started = await controller.startNewThread();

    expect(started, false);
    expect(runner.startedThreads, 1);
    expect(runner.startedTurns, [(threadId: 'thr_new', text: 'Run long task')]);
    expect(controller.activeTurnId, 'turn_1');
  });

  test(
    'finishTurn records failed turns without blocking next submit',
    () async {
      final runner = _FakeTurnRunner();
      final controller = TurnController(runnerProvider: () => runner);
      addTearDown(controller.dispose);

      await controller.submitText('Run task');
      controller.finishTurn(
        threadId: 'thr_new',
        turn: TurnSummary.fromJson({
          'id': 'turn_1',
          'status': 'failed',
          'items': <Object?>[],
          'itemsView': 'full',
          'error': {'message': 'model failed'},
        }),
      );

      expect(controller.status, TurnControllerStatus.failed);
      expect(controller.error, 'model failed');
      expect(controller.activeTurnId, isNull);
      expect(controller.canSubmit, true);
    },
  );

  test('submitText resolves and passes explicit config overrides', () async {
    final runner = _FakeTurnRunner();
    final controller = TurnController(
      runnerProvider: () => runner,
      overrideLayersProvider: () => const CodexConfigOverrideLayers(
        appDefault: CodexConfigOverrides(model: 'gpt-5'),
        session: CodexConfigOverrides(model: 'gpt-5-codex'),
        turn: CodexConfigOverrides(effort: 'high'),
      ),
    );
    addTearDown(controller.dispose);

    await controller.submitText('Run task');

    expect(runner.startedTurnOverrides.single.toTurnStartParams(), {
      'model': 'gpt-5-codex',
      'effort': 'high',
    });
  });

  test('submitText without runner records failure', () async {
    final controller = TurnController(runnerProvider: () => null);
    addTearDown(controller.dispose);

    await controller.submitText('Fix bug');

    expect(controller.status, TurnControllerStatus.failed);
    expect(controller.error, isA<StateError>());
  });
}

class _FakeTurnRunner implements TurnRunner {
  int startedThreads = 0;
  final resumedThreads = <String>[];
  final startedTurns = <({String threadId, String text})>[];
  final startedTurnOverrides = <CodexConfigOverrides>[];
  final interruptedTurns = <({String threadId, String turnId})>[];

  @override
  Future<ThreadSummary> startThread() async {
    startedThreads++;
    return _thread('thr_new');
  }

  @override
  Future<ThreadSummary> resumeThread({required String threadId}) async {
    resumedThreads.add(threadId);
    return _thread(threadId);
  }

  @override
  Future<TurnSummary> startTurn({
    required String threadId,
    required String text,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
  }) async {
    startedTurns.add((threadId: threadId, text: text));
    startedTurnOverrides.add(overrides);
    return TurnSummary.fromJson({
      'id': 'turn_${startedTurns.length}',
      'status': 'inProgress',
      'items': <Object?>[],
      'itemsView': 'notLoaded',
    });
  }

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    interruptedTurns.add((threadId: threadId, turnId: turnId));
  }
}

ThreadSummary _thread(String threadId) {
  return ThreadSummary.fromJson({
    'id': threadId,
    'sessionId': 'sess_1',
    'preview': 'Thread',
    'ephemeral': false,
    'status': 'idle',
    'cwd': '/repo',
    'updatedAt': 1,
  });
}
