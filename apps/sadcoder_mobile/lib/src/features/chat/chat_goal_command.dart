import '../../goals/thread_goal_runner.dart';
import '../../i18n/app_localizations.dart';
import 'chat_goal_summary.dart';

sealed class ChatGoalCommand {
  const ChatGoalCommand();
}

class ChatGoalGetCommand extends ChatGoalCommand {
  const ChatGoalGetCommand();
}

class ChatGoalClearCommand extends ChatGoalCommand {
  const ChatGoalClearCommand();
}

class ChatGoalSetCommand extends ChatGoalCommand {
  const ChatGoalSetCommand({this.objective, this.status, this.tokenBudget});

  final String? objective;
  final String? status;
  final int? tokenBudget;
}

ChatGoalCommand? parseChatGoalCommand(String arguments) {
  final trimmed = arguments.trim();
  if (trimmed.isEmpty || trimmed == 'show' || trimmed == 'get') {
    return const ChatGoalGetCommand();
  }
  if (trimmed == 'clear') {
    return const ChatGoalClearCommand();
  }

  final firstSpace = trimmed.indexOf(RegExp(r'\s'));
  final head = firstSpace == -1 ? trimmed : trimmed.substring(0, firstSpace);
  final tail = firstSpace == -1 ? '' : trimmed.substring(firstSpace + 1).trim();
  if (head == 'status') {
    if (!_goalStatuses.contains(tail)) {
      return null;
    }
    return ChatGoalSetCommand(status: tail);
  }
  if (head == 'budget') {
    final nextSpace = tail.indexOf(RegExp(r'\s'));
    final budgetText = nextSpace == -1 ? tail : tail.substring(0, nextSpace);
    final budget = int.tryParse(budgetText);
    if (budget == null || budget <= 0) {
      return null;
    }
    final objective = nextSpace == -1
        ? null
        : tail.substring(nextSpace + 1).trim();
    return ChatGoalSetCommand(
      tokenBudget: budget,
      objective: objective?.isEmpty == true ? null : objective,
    );
  }
  if (head == 'set') {
    return tail.isEmpty ? null : ChatGoalSetCommand(objective: tail);
  }
  return ChatGoalSetCommand(objective: trimmed);
}

const _goalStatuses = {
  'active',
  'paused',
  'blocked',
  'usageLimited',
  'budgetLimited',
  'complete',
};

Future<String?> buildThreadGoalSummaryFromCommand({
  required AppLocalizations l10n,
  required ThreadGoalRunner? runner,
  required String? threadId,
  required String arguments,
}) async {
  if (runner == null || threadId == null) {
    return null;
  }

  final command = parseChatGoalCommand(arguments);
  if (command == null) {
    return null;
  }

  return switch (command) {
    ChatGoalGetCommand() => buildThreadGoalSummary(
      l10n: l10n,
      goal: (await runner.getGoal(threadId: threadId)).goal,
    ),
    ChatGoalClearCommand() => buildThreadGoalClearedSummary(
      l10n: l10n,
      cleared: (await runner.clearGoal(threadId: threadId)).cleared,
    ),
    ChatGoalSetCommand(:final objective, :final status, :final tokenBudget) =>
      _setThreadGoal(
        l10n: l10n,
        runner: runner,
        threadId: threadId,
        objective: objective,
        status: status,
        tokenBudget: tokenBudget,
      ),
  };
}

Future<String> _setThreadGoal({
  required AppLocalizations l10n,
  required ThreadGoalRunner runner,
  required String threadId,
  required String? objective,
  required String? status,
  required int? tokenBudget,
}) async {
  var resolvedStatus = status;
  if (objective != null && resolvedStatus == null) {
    final current = (await runner.getGoal(threadId: threadId)).goal;
    if (current?.status == 'complete' || current?.status == 'budgetLimited') {
      resolvedStatus = 'active';
    }
  }
  await runner.setGoal(
    threadId: threadId,
    objective: objective,
    status: resolvedStatus,
    tokenBudget: tokenBudget,
  );
  return l10n.threadGoalUpdated;
}
