import 'thread_summary.dart';

enum AgentThreadRuntimeStatus {
  running('running'),
  closed('closed'),
  errored('errored');

  const AgentThreadRuntimeStatus(this.label);

  final String label;
}

class AgentThreadTopology {
  const AgentThreadTopology({required this.entries});

  factory AgentThreadTopology.fromThreads(List<ThreadSummary> threads) {
    final byId = <String, _AgentThreadTopologyNode>{};
    for (final thread in threads) {
      final id = thread.id.trim();
      if (id.isNotEmpty) {
        byId[id] = _AgentThreadTopologyNode(thread: thread);
      }
    }

    for (final thread in threads) {
      _ingestThreadActivity(thread, byId);
    }

    final childrenByParent = <String, List<_AgentThreadTopologyNode>>{};
    final roots = <_AgentThreadTopologyNode>[];
    for (final thread in byId.values) {
      final parentId = _resolvedParentId(thread, byId);
      if (parentId == null) {
        roots.add(thread);
        continue;
      }
      childrenByParent
          .putIfAbsent(parentId, () => <_AgentThreadTopologyNode>[])
          .add(thread);
    }

    void sortThreads(List<_AgentThreadTopologyNode> values) {
      values.sort((a, b) {
        final updated = b.thread.updatedAtSeconds.compareTo(
          a.thread.updatedAtSeconds,
        );
        if (updated != 0) {
          return updated;
        }
        final title = a.thread.title.toLowerCase().compareTo(
          b.thread.title.toLowerCase(),
        );
        if (title != 0) {
          return title;
        }
        return a.thread.id.compareTo(b.thread.id);
      });
    }

    sortThreads(roots);
    for (final children in childrenByParent.values) {
      sortThreads(children);
    }

    final entries = <AgentThreadTopologyEntry>[];
    final visited = <String>{};
    void visit(_AgentThreadTopologyNode node, int depth) {
      if (!visited.add(node.thread.id)) {
        return;
      }
      final children =
          childrenByParent[node.thread.id] ??
          const <_AgentThreadTopologyNode>[];
      entries.add(
        AgentThreadTopologyEntry(
          thread: node.thread,
          depth: depth,
          hasChildren: children.isNotEmpty,
          parentThreadId: node.parentThreadId,
          ancestorThreadId: node.ancestorThreadId,
          agentPath: node.agentPath,
          runtimeStatus: node.runtimeStatus,
        ),
      );
      for (final child in children) {
        visit(child, depth + 1);
      }
    }

    for (final root in roots) {
      visit(root, 0);
    }
    for (final node in byId.values) {
      visit(node, 0);
    }
    return AgentThreadTopology(entries: List.unmodifiable(entries));
  }

  final List<AgentThreadTopologyEntry> entries;

  List<AgentThreadTopologyEntry> get subagentEntries => [
    for (final entry in entries)
      if (entry.isSubagent) entry,
  ];

  bool get hasAgentTopology =>
      entries.any((entry) => entry.isSubagent || entry.hasChildren);
}

String? _resolvedParentId(
  _AgentThreadTopologyNode thread,
  Map<String, _AgentThreadTopologyNode> byId,
) {
  final parentId = thread.parentThreadId?.trim();
  if (parentId != null &&
      parentId.isNotEmpty &&
      parentId != thread.thread.id &&
      byId.containsKey(parentId)) {
    return parentId;
  }

  final ancestorId = thread.ancestorThreadId?.trim();
  if (ancestorId != null &&
      ancestorId.isNotEmpty &&
      ancestorId != thread.thread.id &&
      byId.containsKey(ancestorId)) {
    return ancestorId;
  }
  return null;
}

void _ingestThreadActivity(
  ThreadSummary source,
  Map<String, _AgentThreadTopologyNode> byId,
) {
  final sourceId = source.id.trim();
  if (sourceId.isEmpty) {
    return;
  }
  _ensureNode(sourceId, byId, source: source);
  for (final turn in source.turns) {
    for (final item in turn.items) {
      switch (item.type) {
        case 'collabAgentToolCall':
          _ingestCollabAgentToolCall(source, item, byId);
        case 'subAgentActivity':
          _ingestSubAgentActivity(source, item, byId);
      }
    }
  }
}

void _ingestCollabAgentToolCall(
  ThreadSummary source,
  ThreadItemSummary item,
  Map<String, _AgentThreadTopologyNode> byId,
) {
  final sourceId = source.id.trim();
  final senderId = _normalizedId(item.senderThreadId) ?? sourceId;
  _ensureNode(senderId, byId, source: source);

  for (final receiverId in item.receiverThreadIds) {
    final normalizedReceiverId = _normalizedId(receiverId);
    if (normalizedReceiverId == null) {
      continue;
    }
    final node = _ensureNode(
      normalizedReceiverId,
      byId,
      source: source,
      parentThreadId: senderId == normalizedReceiverId ? null : senderId,
      ancestorThreadId: _ancestorFor(source),
    );
    final callStatus = _runtimeStatusFromCollabCall(item);
    final stateStatus = _runtimeStatusFromAgentState(
      item.agentStates[normalizedReceiverId],
    );
    node.applyRuntimeStatus(_mergedRuntimeStatus(callStatus, stateStatus));
  }
}

void _ingestSubAgentActivity(
  ThreadSummary source,
  ThreadItemSummary item,
  Map<String, _AgentThreadTopologyNode> byId,
) {
  final agentThreadId = _normalizedId(item.agentThreadId);
  if (agentThreadId == null) {
    return;
  }
  final sourceId = source.id.trim();
  final node = _ensureNode(
    agentThreadId,
    byId,
    source: source,
    parentThreadId: sourceId == agentThreadId ? null : sourceId,
    ancestorThreadId: _ancestorFor(source),
    agentPath: item.agentPath,
  );
  node.applyRuntimeStatus(_runtimeStatusFromActivityKind(item.activityKind));
}

_AgentThreadTopologyNode _ensureNode(
  String threadId,
  Map<String, _AgentThreadTopologyNode> byId, {
  required ThreadSummary source,
  String? parentThreadId,
  String? ancestorThreadId,
  String? agentPath,
}) {
  final normalizedThreadId = threadId.trim();
  final existing = byId[normalizedThreadId];
  if (existing != null) {
    existing.applyParent(parentThreadId);
    existing.applyAncestor(ancestorThreadId);
    existing.applyAgentPath(agentPath);
    return existing;
  }

  final node = _AgentThreadTopologyNode(
    thread: ThreadSummary(
      id: normalizedThreadId,
      sessionId: source.sessionId,
      preview:
          _firstNonBlank(agentPath, normalizedThreadId) ?? normalizedThreadId,
      ephemeral: false,
      status: 'unknown',
      cwd: source.cwd,
      updatedAtSeconds: source.updatedAtSeconds,
      parentThreadId: parentThreadId,
      ancestorThreadId: ancestorThreadId,
    ),
  );
  node.applyAgentPath(agentPath);
  byId[normalizedThreadId] = node;
  return node;
}

AgentThreadRuntimeStatus? _runtimeStatusFromAgentState(
  CollabAgentStateSummary? state,
) {
  return switch (state?.status) {
    'pendingInit' || 'running' => AgentThreadRuntimeStatus.running,
    'completed' ||
    'interrupted' ||
    'shutdown' => AgentThreadRuntimeStatus.closed,
    'errored' || 'notFound' => AgentThreadRuntimeStatus.errored,
    _ => null,
  };
}

AgentThreadRuntimeStatus? _runtimeStatusFromCollabCall(ThreadItemSummary item) {
  if (item.status == 'failed') {
    return AgentThreadRuntimeStatus.errored;
  }
  if (item.status == 'inProgress') {
    return AgentThreadRuntimeStatus.running;
  }
  return switch (item.tool) {
    'spawnAgent' ||
    'sendInput' ||
    'resumeAgent' => AgentThreadRuntimeStatus.running,
    'closeAgent' => AgentThreadRuntimeStatus.closed,
    _ => null,
  };
}

AgentThreadRuntimeStatus? _runtimeStatusFromActivityKind(String? kind) {
  return switch (kind) {
    'started' || 'interacted' => AgentThreadRuntimeStatus.running,
    'interrupted' => AgentThreadRuntimeStatus.closed,
    _ => null,
  };
}

AgentThreadRuntimeStatus? _mergedRuntimeStatus(
  AgentThreadRuntimeStatus? callStatus,
  AgentThreadRuntimeStatus? stateStatus,
) {
  if (callStatus == AgentThreadRuntimeStatus.errored ||
      callStatus == AgentThreadRuntimeStatus.closed) {
    return callStatus;
  }
  return stateStatus ?? callStatus;
}

String? _ancestorFor(ThreadSummary source) {
  return _firstNonBlank(
    source.ancestorThreadId,
    source.parentThreadId,
    source.id,
  );
}

String? _normalizedId(String? id) {
  final trimmed = id?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String? _firstNonBlank(String? first, String? second, [String? third]) {
  for (final value in [first, second, third]) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

class _AgentThreadTopologyNode {
  _AgentThreadTopologyNode({required this.thread})
    : parentThreadId = _normalizedId(thread.parentThreadId),
      ancestorThreadId = _normalizedId(thread.ancestorThreadId);

  final ThreadSummary thread;
  String? parentThreadId;
  String? ancestorThreadId;
  String? agentPath;
  AgentThreadRuntimeStatus? runtimeStatus;

  void applyParent(String? value) {
    final parent = _normalizedId(value);
    if (parent == null || parent == thread.id || parentThreadId != null) {
      return;
    }
    parentThreadId = parent;
  }

  void applyAncestor(String? value) {
    final ancestor = _normalizedId(value);
    if (ancestor == null || ancestor == thread.id || ancestorThreadId != null) {
      return;
    }
    ancestorThreadId = ancestor;
  }

  void applyAgentPath(String? value) {
    agentPath ??= _firstNonBlank(value, null);
  }

  void applyRuntimeStatus(AgentThreadRuntimeStatus? value) {
    runtimeStatus = value ?? runtimeStatus;
  }
}

class AgentThreadTopologyEntry {
  const AgentThreadTopologyEntry({
    required this.thread,
    required this.depth,
    required this.hasChildren,
    this.parentThreadId,
    this.ancestorThreadId,
    this.agentPath,
    this.runtimeStatus,
  });

  final ThreadSummary thread;
  final int depth;
  final bool hasChildren;
  final String? parentThreadId;
  final String? ancestorThreadId;
  final String? agentPath;
  final AgentThreadRuntimeStatus? runtimeStatus;

  bool get isSubagent =>
      parentThreadId?.trim().isNotEmpty == true ||
      ancestorThreadId?.trim().isNotEmpty == true ||
      agentPath?.trim().isNotEmpty == true ||
      thread.isSubagent;

  String get displayStatus => runtimeStatus?.label ?? thread.status;

  String get displayRole {
    final nickname = thread.agentNickname?.trim();
    final role = thread.agentRole?.trim();
    if (nickname != null &&
        nickname.isNotEmpty &&
        role != null &&
        role.isNotEmpty) {
      return '$nickname / $role';
    }
    if (nickname != null && nickname.isNotEmpty) {
      return nickname;
    }
    if (role != null && role.isNotEmpty) {
      return role;
    }
    return '';
  }
}
