import '../protocol/codex_app_server_client.dart';
import 'thread_goal.dart';
import 'thread_goal_runner.dart';

class CodexThreadGoalRunner implements ThreadGoalRunner {
  const CodexThreadGoalRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ThreadGoalGetResult> getGoal({required String threadId}) async {
    final response = await _client.getThreadGoal(threadId: threadId);
    return ThreadGoalGetResult.fromJson(response);
  }

  @override
  Future<ThreadGoalSetResult> setGoal({
    required String threadId,
    String? objective,
    String? status,
    int? tokenBudget,
  }) async {
    final response = await _client.setThreadGoal(
      threadId: threadId,
      objective: objective,
      status: status,
      tokenBudget: tokenBudget,
    );
    return ThreadGoalSetResult.fromJson(response);
  }

  @override
  Future<ThreadGoalClearResult> clearGoal({required String threadId}) async {
    final response = await _client.clearThreadGoal(threadId: threadId);
    return ThreadGoalClearResult.fromJson(response);
  }
}
