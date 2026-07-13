import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../threads/agent_thread_topology.dart';

class ChatAgentTopologySheet extends StatelessWidget {
  const ChatAgentTopologySheet({
    super.key,
    required this.entries,
    required this.subagentsOnly,
    required this.activeThreadId,
  });

  final List<AgentThreadTopologyEntry> entries;
  final bool subagentsOnly;
  final String? activeThreadId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                subagentsOnly
                    ? l10n.subagentTopologyTitle
                    : l10n.agentTopologyTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (context, index) => _AgentTopologyTile(
                  entry: entries[index],
                  active: entries[index].thread.id == activeThreadId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentTopologyTile extends StatelessWidget {
  const _AgentTopologyTile({required this.entry, required this.active});

  final AgentThreadTopologyEntry entry;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thread = entry.thread;
    final role = entry.displayRole;
    final statusColor = _agentRuntimeStatusColor(context, entry);
    final details = <String>[
      '${l10n.approvalThread}: ${thread.id}',
      '${l10n.timelineStatus}: ${entry.displayStatus}',
      if (role.isNotEmpty) '${l10n.agentRole}: $role',
      if (entry.agentPath != null) '${l10n.agentPath}: ${entry.agentPath}',
      if (entry.parentThreadId != null)
        '${l10n.agentParentThread}: ${entry.parentThreadId}',
      if (entry.ancestorThreadId != null)
        '${l10n.agentAncestorThread}: ${entry.ancestorThreadId}',
      if (thread.cwd.isNotEmpty) thread.cwd,
    ];
    return ListTile(
      key: ValueKey('agent-thread-${thread.id}'),
      contentPadding: EdgeInsetsDirectional.only(
        start: 16.0 + entry.depth * 24,
        end: 16,
      ),
      leading: Icon(
        entry.isSubagent ? Icons.account_tree_outlined : Icons.forum_outlined,
        color: statusColor,
      ),
      title: Text(
        active ? '${thread.title} (${l10n.activeThread})' : thread.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(details.join('\n')),
      isThreeLine: true,
      trailing: entry.hasChildren
          ? const Icon(Icons.keyboard_arrow_down)
          : const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pop(thread),
    );
  }
}

Color _agentRuntimeStatusColor(
  BuildContext context,
  AgentThreadTopologyEntry entry,
) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (entry.runtimeStatus) {
    AgentThreadRuntimeStatus.running => colorScheme.primary,
    AgentThreadRuntimeStatus.closed => colorScheme.onSurfaceVariant,
    AgentThreadRuntimeStatus.errored => colorScheme.error,
    null => switch (entry.displayStatus.trim().toLowerCase()) {
      'running' || 'inprogress' || 'pendinginit' => colorScheme.primary,
      'closed' ||
      'completed' ||
      'interrupted' ||
      'shutdown' => colorScheme.onSurfaceVariant,
      'errored' || 'failed' || 'notfound' => colorScheme.error,
      _ => colorScheme.secondary,
    },
  };
}
