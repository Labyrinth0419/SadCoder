import 'thread_goal.dart';

abstract interface class ThreadGoalRunner {
  Future<ThreadGoalGetResult> getGoal({required String threadId});

  Future<ThreadGoalSetResult> setGoal({
    required String threadId,
    String? objective,
    String? status,
    int? tokenBudget,
  });

  Future<ThreadGoalClearResult> clearGoal({required String threadId});
}
