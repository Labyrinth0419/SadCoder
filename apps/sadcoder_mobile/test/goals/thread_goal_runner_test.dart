import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/goals/codex_thread_goal_runner.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('ThreadGoal parses persisted goal payloads', () {
    final goal = ThreadGoal.fromJson({
      'threadId': 'thr_1',
      'objective': 'Ship goal support',
      'status': 'active',
      'tokenBudget': 5000,
      'tokensUsed': 1234,
      'timeUsedSeconds': 60,
      'createdAt': 10,
      'updatedAt': 20,
    });

    expect(goal?.threadId, 'thr_1');
    expect(goal?.objective, 'Ship goal support');
    expect(goal?.status, 'active');
    expect(goal?.tokenBudget, 5000);
    expect(goal?.tokensUsed, 1234);
    expect(goal?.timeUsedSeconds, 60);
  });

  test('CodexThreadGoalRunner calls get set and clear methods', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return switch (request.method) {
        'thread/goal/get' => {
          'goal': {
            'threadId': 'thr_1',
            'objective': 'Existing goal',
            'status': 'active',
            'tokensUsed': 1,
            'timeUsedSeconds': 2,
            'createdAt': 3,
            'updatedAt': 4,
          },
        },
        'thread/goal/set' => {
          'goal': {
            'threadId': 'thr_1',
            'objective': 'New goal',
            'status': 'active',
            'tokenBudget': 5000,
            'tokensUsed': 0,
            'timeUsedSeconds': 0,
            'createdAt': 5,
            'updatedAt': 5,
          },
        },
        'thread/goal/clear' => {'cleared': true},
        _ => <String, Object?>{},
      };
    });
    final runner = CodexThreadGoalRunner(CodexAppServerClient(transport));

    final existing = await runner.getGoal(threadId: 'thr_1');
    final updated = await runner.setGoal(
      threadId: 'thr_1',
      objective: 'New goal',
      tokenBudget: 5000,
    );
    final cleared = await runner.clearGoal(threadId: 'thr_1');

    expect(existing.goal?.objective, 'Existing goal');
    expect(updated.goal.objective, 'New goal');
    expect(updated.goal.tokenBudget, 5000);
    expect(cleared.cleared, true);
    expect(requests.map((request) => request.method), [
      'thread/goal/get',
      'thread/goal/set',
      'thread/goal/clear',
    ]);
    expect(requests[1].params, {
      'threadId': 'thr_1',
      'objective': 'New goal',
      'tokenBudget': 5000,
    });
  });
}
