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

  test('AgentThreadTopology backfills activity from thread items', () {
    final topology = AgentThreadTopology.fromThreads([
      _thread(
        'thr_main',
        items: [
          {
            'id': 'item_spawn',
            'type': 'collabAgentToolCall',
            'tool': 'spawnAgent',
            'status': 'completed',
            'senderThreadId': 'thr_main',
            'receiverThreadIds': ['thr_worker'],
            'agentsStates': {
              'thr_worker': {'status': 'running', 'message': null},
            },
          },
          {
            'id': 'item_path',
            'type': 'subAgentActivity',
            'kind': 'started',
            'agentThreadId': 'thr_worker',
            'agentPath': 'agents/build',
          },
          {
            'id': 'item_close',
            'type': 'collabAgentToolCall',
            'tool': 'closeAgent',
            'status': 'completed',
            'senderThreadId': 'thr_main',
            'receiverThreadIds': ['thr_review'],
          },
          {
            'id': 'item_wait',
            'type': 'collabAgentToolCall',
            'tool': 'wait',
            'status': 'completed',
            'senderThreadId': 'thr_main',
            'receiverThreadIds': ['thr_broken'],
            'agentsStates': {
              'thr_broken': {'status': 'errored', 'message': 'timeout'},
            },
          },
          {
            'id': 'item_failed_send',
            'type': 'collabAgentToolCall',
            'tool': 'sendInput',
            'status': 'failed',
            'senderThreadId': 'thr_main',
            'receiverThreadIds': ['thr_failed'],
            'agentsStates': {
              'thr_failed': {'status': 'running', 'message': null},
            },
          },
        ],
      ),
    ]);

    final worker = _entry(topology, 'thr_worker');
    final review = _entry(topology, 'thr_review');
    final broken = _entry(topology, 'thr_broken');
    final failed = _entry(topology, 'thr_failed');

    expect(worker.parentThreadId, 'thr_main');
    expect(worker.ancestorThreadId, 'thr_main');
    expect(worker.agentPath, 'agents/build');
    expect(worker.runtimeStatus, AgentThreadRuntimeStatus.running);
    expect(worker.displayStatus, 'running');
    expect(review.displayStatus, 'closed');
    expect(broken.displayStatus, 'errored');
    expect(failed.displayStatus, 'errored');
    expect(
      topology.subagentEntries.map((entry) => entry.thread.id),
      containsAll(['thr_worker', 'thr_review', 'thr_broken', 'thr_failed']),
    );
  });
}

AgentThreadTopologyEntry _entry(AgentThreadTopology topology, String id) {
  return topology.entries.singleWhere((entry) => entry.thread.id == id);
}

ThreadSummary _thread(
  String id, {
  String? parentThreadId,
  String? ancestorThreadId,
  String? agentNickname,
  String? agentRole,
  int updatedAt = 1,
  List<Map<String, Object?>> items = const [],
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
  if (items.isNotEmpty) {
    json['turns'] = [
      {
        'id': 'turn_1',
        'status': 'completed',
        'itemsView': 'full',
        'items': items,
      },
    ];
  }
  return ThreadSummary.fromJson(json);
}
