import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/threads/agent_thread_topology.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

void main() {
  test('AgentThreadTopology orders parent and subagent entries', () {
    final topology = AgentThreadTopology.fromThreads([
      _thread(
        'thr_worker',
        parentThreadId: 'thr_main',
        ancestorThreadId: 'thr_main',
        agentNickname: 'Builder',
        agentRole: 'coder',
        updatedAt: 3,
      ),
      _thread('thr_main', updatedAt: 2),
      _thread(
        'thr_reviewer',
        parentThreadId: 'thr_main',
        ancestorThreadId: 'thr_main',
        agentRole: 'reviewer',
        updatedAt: 4,
      ),
      _thread(
        'thr_planner',
        ancestorThreadId: 'thr_main',
        agentNickname: 'Planner',
        updatedAt: 6,
      ),
      _thread(
        'thr_orphan',
        parentThreadId: 'missing',
        agentNickname: 'Detached',
        updatedAt: 5,
      ),
    ]);

    expect(topology.entries.map((entry) => entry.thread.id), [
      'thr_orphan',
      'thr_main',
      'thr_planner',
      'thr_reviewer',
      'thr_worker',
    ]);
    expect(topology.entries.map((entry) => entry.depth), [0, 0, 1, 1, 1]);
    expect(topology.subagentEntries.map((entry) => entry.thread.id), [
      'thr_orphan',
      'thr_planner',
      'thr_reviewer',
      'thr_worker',
    ]);
    expect(topology.hasAgentTopology, true);
    expect(topology.entries.last.displayRole, 'Builder / coder');
  });
}

ThreadSummary _thread(
  String id, {
  String? parentThreadId,
  String? ancestorThreadId,
  String? agentNickname,
  String? agentRole,
  int updatedAt = 1,
}) {
  final json = <String, Object?>{
    'id': id,
    'sessionId': 'sess_1',
    'preview': id,
    'ephemeral': false,
    'status': 'idle',
    'cwd': '/repo',
    'updatedAt': updatedAt,
  };
  if (parentThreadId != null) {
    json['parentThreadId'] = parentThreadId;
  }
  if (ancestorThreadId != null) {
    json['ancestorThreadId'] = ancestorThreadId;
  }
  if (agentNickname != null) {
    json['agentNickname'] = agentNickname;
  }
  if (agentRole != null) {
    json['agentRole'] = agentRole;
  }
  return ThreadSummary.fromJson(json);
}
