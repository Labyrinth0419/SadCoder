import '../../goals/thread_goal.dart';
import '../../i18n/app_localizations.dart';

String buildThreadGoalSummary({
  required AppLocalizations l10n,
  ThreadGoal? goal,
}) {
  final lines = <String>[l10n.threadGoalStatus];
  if (goal == null) {
    lines.add(l10n.threadGoalEmpty);
    return lines.join('\n');
  }

  lines.add('${l10n.threadGoalObjective}: ${goal.objective}');
  lines.add('${l10n.timelineStatus}: ${goal.status}');
  lines.add('${l10n.threadGoalTokensUsed}: ${l10n.tokenCount(goal.tokensUsed)}');
  if (goal.tokenBudget != null) {
    lines.add(
      '${l10n.threadGoalTokenBudget}: ${l10n.tokenCount(goal.tokenBudget!)}',
    );
  }
  lines.add(
    '${l10n.threadGoalTimeUsed}: ${l10n.secondCount(goal.timeUsedSeconds)}',
  );
  return lines.join('\n');
}

String buildThreadGoalClearedSummary({
  required AppLocalizations l10n,
  required bool cleared,
}) {
  return cleared ? l10n.threadGoalCleared : l10n.threadGoalEmpty;
}
