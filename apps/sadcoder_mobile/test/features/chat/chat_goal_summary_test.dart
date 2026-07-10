import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_goal_summary.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  test('buildThreadGoalSummary formats numeric values through localizations', () {
    const en = AppLocalizations(Locale('en'));
    const zh = AppLocalizations(Locale('zh'));
    const goal = ThreadGoal(
      threadId: 'thr_1',
      objective: 'Ship mobile UI',
      status: 'in_progress',
      tokensUsed: 1234,
      tokenBudget: 5678,
      createdAtSeconds: 1,
      updatedAtSeconds: 2,
      timeUsedSeconds: 90,
      raw: {},
    );

    final english = buildThreadGoalSummary(l10n: en, goal: goal);
    final chinese = buildThreadGoalSummary(l10n: zh, goal: goal);

    expect(english, contains('Tokens used: 1,234 tokens'));
    expect(english, contains('Token budget: 5,678 tokens'));
    expect(english, contains('Time used: 90 sec'));
    expect(chinese, contains('已用 token: 1,234 个 token'));
    expect(chinese, contains('Token 预算: 5,678 个 token'));
    expect(chinese, contains('已用时间: 90 秒'));
  });

  test('buildThreadGoalSummary keeps the empty state concise', () {
    const l10n = AppLocalizations(Locale('en'));

    expect(
      buildThreadGoalSummary(l10n: l10n),
      'Goal\nNo goal set.',
    );
  });
}
