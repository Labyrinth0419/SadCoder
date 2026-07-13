import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_goal_command.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal_runner.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  group('parseChatGoalCommand', () {
    test('parses empty show and get as read commands', () {
      expect(parseChatGoalCommand(''), isA<ChatGoalGetCommand>());
      expect(parseChatGoalCommand('   '), isA<ChatGoalGetCommand>());
      expect(parseChatGoalCommand('show'), isA<ChatGoalGetCommand>());
      expect(parseChatGoalCommand('get'), isA<ChatGoalGetCommand>());
    });

    test('parses clear command', () {
      expect(parseChatGoalCommand('clear'), isA<ChatGoalClearCommand>());
    });

    test('parses default and explicit set objectives', () {
      final defaultSet = parseChatGoalCommand('Ship goal support');
      expect(defaultSet, isA<ChatGoalSetCommand>());
      expect((defaultSet as ChatGoalSetCommand).objective, 'Ship goal support');
      expect(defaultSet.status, isNull);
      expect(defaultSet.tokenBudget, isNull);

      final explicitSet = parseChatGoalCommand('set Reduce latency');
      expect(explicitSet, isA<ChatGoalSetCommand>());
      expect((explicitSet as ChatGoalSetCommand).objective, 'Reduce latency');
    });

    test('rejects explicit set without an objective', () {
      expect(parseChatGoalCommand('set'), isNull);
      expect(parseChatGoalCommand('set   '), isNull);
    });

    test('parses supported status values and rejects unsupported values', () {
      for (final status in const [
        'active',
        'paused',
        'blocked',
        'usageLimited',
        'budgetLimited',
        'complete',
      ]) {
        final command = parseChatGoalCommand('status $status');
        expect(command, isA<ChatGoalSetCommand>());
        expect((command as ChatGoalSetCommand).status, status);
        expect(command.objective, isNull);
        expect(command.tokenBudget, isNull);
      }

      expect(parseChatGoalCommand('status sideways'), isNull);
      expect(parseChatGoalCommand('status'), isNull);
    });

    test('parses positive token budgets with optional objectives', () {
      final budgetOnly = parseChatGoalCommand('budget 7500');
      expect(budgetOnly, isA<ChatGoalSetCommand>());
      expect((budgetOnly as ChatGoalSetCommand).tokenBudget, 7500);
      expect(budgetOnly.objective, isNull);

      final withObjective = parseChatGoalCommand(
        'budget 12000 Finish benchmark',
      );
      expect(withObjective, isA<ChatGoalSetCommand>());
      expect((withObjective as ChatGoalSetCommand).tokenBudget, 12000);
      expect(withObjective.objective, 'Finish benchmark');
      expect(withObjective.status, isNull);
    });

    test('rejects invalid token budgets', () {
      expect(parseChatGoalCommand('budget'), isNull);
      expect(parseChatGoalCommand('budget 0'), isNull);
      expect(parseChatGoalCommand('budget -5'), isNull);
      expect(parseChatGoalCommand('budget many'), isNull);
    });
  });

  group('buildThreadGoalSummaryFromCommand', () {
    test('reads the selected thread goal', () async {
      final runner = _RecordingThreadGoalRunner(
        goal: _goal(objective: 'Ship mobile goal support'),
      );

      final summary = await buildThreadGoalSummaryFromCommand(
        l10n: l10n,
        runner: runner,
        threadId: 'thr_1',
        arguments: 'get',
      );

      expect(summary, contains('Ship mobile goal support'));
      expect(runner.calls, ['get:thr_1']);
    });

    test('sets goal budget and objective', () async {
      final runner = _RecordingThreadGoalRunner();

      final summary = await buildThreadGoalSummaryFromCommand(
        l10n: l10n,
        runner: runner,
        threadId: 'thr_1',
        arguments: 'budget 12000 Finish benchmark',
      );

      expect(summary, contains('Finish benchmark'));
      expect(runner.setCalls, [
        (
          threadId: 'thr_1',
          objective: 'Finish benchmark',
          status: null,
          tokenBudget: 12000,
        ),
      ]);
    });

    test('clears the selected thread goal', () async {
      final runner = _RecordingThreadGoalRunner(cleared: true);

      final summary = await buildThreadGoalSummaryFromCommand(
        l10n: l10n,
        runner: runner,
        threadId: 'thr_1',
        arguments: 'clear',
      );

      expect(summary, l10n.threadGoalCleared);
      expect(runner.calls, ['clear:thr_1']);
    });

    test('rejects unavailable and unsupported inputs', () async {
      final runner = _RecordingThreadGoalRunner();

      expect(
        await buildThreadGoalSummaryFromCommand(
          l10n: l10n,
          runner: null,
          threadId: 'thr_1',
          arguments: '',
        ),
        isNull,
      );
      expect(
        await buildThreadGoalSummaryFromCommand(
          l10n: l10n,
          runner: runner,
          threadId: null,
          arguments: '',
        ),
        isNull,
      );
      expect(
        await buildThreadGoalSummaryFromCommand(
          l10n: l10n,
          runner: runner,
          threadId: 'thr_1',
          arguments: 'status sideways',
        ),
        isNull,
      );
      expect(runner.calls, isEmpty);
    });
  });
}

class _RecordingThreadGoalRunner implements ThreadGoalRunner {
  _RecordingThreadGoalRunner({this.goal, this.cleared = false});

  final ThreadGoal? goal;
  final bool cleared;
  final calls = <String>[];
  final setCalls =
      <
        ({String threadId, String? objective, String? status, int? tokenBudget})
      >[];

  @override
  Future<ThreadGoalGetResult> getGoal({required String threadId}) async {
    calls.add('get:$threadId');
    return ThreadGoalGetResult(goal: goal);
  }

  @override
  Future<ThreadGoalSetResult> setGoal({
    required String threadId,
    String? objective,
    String? status,
    int? tokenBudget,
  }) async {
    calls.add('set:$threadId');
    setCalls.add((
      threadId: threadId,
      objective: objective,
      status: status,
      tokenBudget: tokenBudget,
    ));
    return ThreadGoalSetResult(
      goal: _goal(
        threadId: threadId,
        objective: objective ?? 'Thread goal',
        status: status ?? 'active',
        tokenBudget: tokenBudget,
      ),
    );
  }

  @override
  Future<ThreadGoalClearResult> clearGoal({required String threadId}) async {
    calls.add('clear:$threadId');
    return ThreadGoalClearResult(cleared: cleared);
  }
}

ThreadGoal _goal({
  String threadId = 'thr_1',
  String objective = 'Thread goal',
  String status = 'active',
  int? tokenBudget,
}) {
  return ThreadGoal(
    threadId: threadId,
    objective: objective,
    status: status,
    tokenBudget: tokenBudget,
    tokensUsed: 20,
    timeUsedSeconds: 30,
    createdAtSeconds: 0,
    updatedAtSeconds: 0,
    raw: const {},
  );
}
