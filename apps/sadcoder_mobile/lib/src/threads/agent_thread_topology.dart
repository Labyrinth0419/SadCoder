import 'thread_summary.dart';

class AgentThreadTopology {
  const AgentThreadTopology({required this.entries});

  factory AgentThreadTopology.fromThreads(List<ThreadSummary> threads) {
    final byId = <String, ThreadSummary>{};
    for (final thread in threads) {
      final id = thread.id.trim();
      if (id.isNotEmpty) {
        byId[id] = thread;
      }
    }

    final childrenByParent = <String, List<ThreadSummary>>{};
    final roots = <ThreadSummary>[];
    for (final thread in byId.values) {
      final parentId = _resolvedParentId(thread, byId);
      if (parentId == null) {
        roots.add(thread);
        continue;
      }
      childrenByParent
          .putIfAbsent(parentId, () => <ThreadSummary>[])
          .add(thread);
    }

    void sortThreads(List<ThreadSummary> values) {
      values.sort((a, b) {
        final updated = b.updatedAtSeconds.compareTo(a.updatedAtSeconds);
        if (updated != 0) {
          return updated;
        }
        final title = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        if (title != 0) {
          return title;
        }
        return a.id.compareTo(b.id);
      });
    }

    sortThreads(roots);
    for (final children in childrenByParent.values) {
      sortThreads(children);
    }

    final entries = <AgentThreadTopologyEntry>[];
    void visit(ThreadSummary thread, int depth) {
      final children = childrenByParent[thread.id] ?? const <ThreadSummary>[];
      entries.add(
        AgentThreadTopologyEntry(
          thread: thread,
          depth: depth,
          hasChildren: children.isNotEmpty,
        ),
      );
      for (final child in children) {
        visit(child, depth + 1);
      }
    }

    for (final root in roots) {
      visit(root, 0);
    }
    return AgentThreadTopology(entries: List.unmodifiable(entries));
  }

  final List<AgentThreadTopologyEntry> entries;

  List<AgentThreadTopologyEntry> get subagentEntries => [
    for (final entry in entries)
      if (entry.thread.isSubagent) entry,
  ];

  bool get hasAgentTopology =>
      entries.any((entry) => entry.thread.isSubagent || entry.hasChildren);
}

String? _resolvedParentId(
  ThreadSummary thread,
  Map<String, ThreadSummary> byId,
) {
  final parentId = thread.parentThreadId?.trim();
  if (parentId != null &&
      parentId.isNotEmpty &&
      parentId != thread.id &&
      byId.containsKey(parentId)) {
    return parentId;
  }

  final ancestorId = thread.ancestorThreadId?.trim();
  if (ancestorId != null &&
      ancestorId.isNotEmpty &&
      ancestorId != thread.id &&
      byId.containsKey(ancestorId)) {
    return ancestorId;
  }
  return null;
}

class AgentThreadTopologyEntry {
  const AgentThreadTopologyEntry({
    required this.thread,
    required this.depth,
    required this.hasChildren,
  });

  final ThreadSummary thread;
  final int depth;
  final bool hasChildren;

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
