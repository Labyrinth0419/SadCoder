import 'package:flutter/material.dart';

import '../../external_agents/external_agent_config_runner.dart';
import '../../i18n/app_localizations.dart';

class ChatExternalAgentImportSheet extends StatefulWidget {
  const ChatExternalAgentImportSheet({
    super.key,
    required this.items,
    this.histories = const [],
  });

  final List<ExternalAgentConfigMigrationItem> items;
  final List<ExternalAgentConfigImportHistory> histories;

  @override
  State<ChatExternalAgentImportSheet> createState() =>
      _ChatExternalAgentImportSheetState();
}

class _ChatExternalAgentImportSheetState
    extends State<ChatExternalAgentImportSheet> {
  late final Set<int> _selectedIndexes = {
    for (var index = 0; index < widget.items.length; index++) index,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedCount = _selectedIndexes.length;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.externalAgentImportTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (widget.items.isNotEmpty)
                    TextButton(
                      key: const ValueKey('external-agent-import-select-all'),
                      onPressed: _toggleAll,
                      child: Text(
                        selectedCount == widget.items.length
                            ? l10n.deselectAll
                            : l10n.selectAll,
                      ),
                    ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  if (widget.histories.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Text(
                        l10n.externalAgentImportRecentHistory,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final history in widget.histories.take(3))
                      _ImportHistoryTile(history: history),
                    const Divider(),
                  ],
                  if (widget.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.externalAgentImportEmpty,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (var index = 0; index < widget.items.length; index++)
                      CheckboxListTile(
                        key: ValueKey('external-agent-import-item-$index'),
                        value: _selectedIndexes.contains(index),
                        onChanged: (_) => _toggleIndex(index),
                        secondary: Icon(_iconFor(widget.items[index].type)),
                        title: Text(widget.items[index].description),
                        subtitle: Text(
                          _itemSubtitle(l10n, widget.items[index]),
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                      ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('external-agent-import-continue'),
                    onPressed: selectedCount == 0 ? null : _continue,
                    icon: const Icon(Icons.input),
                    label: Text(
                      l10n.externalAgentImportSelected(selectedCount),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAll() {
    setState(() {
      if (_selectedIndexes.length == widget.items.length) {
        _selectedIndexes.clear();
      } else {
        _selectedIndexes.addAll(Iterable<int>.generate(widget.items.length));
      }
    });
  }

  void _toggleIndex(int index) {
    setState(() {
      if (!_selectedIndexes.remove(index)) {
        _selectedIndexes.add(index);
      }
    });
  }

  void _continue() {
    final selected = [
      for (var index = 0; index < widget.items.length; index++)
        if (_selectedIndexes.contains(index)) widget.items[index],
    ];
    Navigator.of(context).pop(selected);
  }
}

class _ImportHistoryTile extends StatelessWidget {
  const _ImportHistoryTile({required this.history});

  final ExternalAgentConfigImportHistory history;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasFailures = history.failureCount > 0;
    return ExpansionTile(
      leading: Icon(
        hasFailures ? Icons.warning_amber_outlined : Icons.check_circle_outline,
        color: hasFailures ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(
        l10n.externalAgentImportResultCounts(
          history.successCount,
          history.failureCount,
        ),
      ),
      subtitle: Text(
        l10n.formatDateTime(
          DateTime.fromMillisecondsSinceEpoch(history.completedAtMs),
        ),
      ),
      children: [
        for (final success in history.successes)
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(
              success.target ?? l10n.externalAgentImportType(success.rawType),
            ),
            subtitle: Text(
              success.cwd == null
                  ? l10n.externalAgentImportHomeScope
                  : l10n.externalAgentImportRepoScope(success.cwd!),
            ),
            dense: true,
          ),
        for (final failure in history.failures)
          ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(failure.message),
            subtitle: Text(
              failure.cwd == null
                  ? failure.failureStage
                  : '${failure.failureStage} | '
                        '${l10n.externalAgentImportRepoScope(failure.cwd!)}',
            ),
            dense: true,
          ),
      ],
    );
  }
}

String _itemSubtitle(
  AppLocalizations l10n,
  ExternalAgentConfigMigrationItem item,
) {
  final parts = <String>[
    l10n.externalAgentImportType(item.rawType),
    item.cwd == null
        ? l10n.externalAgentImportHomeScope
        : l10n.externalAgentImportRepoScope(item.cwd!),
  ];
  if (item.detailCount > 0) {
    parts.add(l10n.externalAgentImportDetailCount(item.detailCount));
  }
  return parts.join(' | ');
}

IconData _iconFor(ExternalAgentConfigMigrationItemType type) {
  return switch (type) {
    ExternalAgentConfigMigrationItemType.agentsMd => Icons.description_outlined,
    ExternalAgentConfigMigrationItemType.config => Icons.tune,
    ExternalAgentConfigMigrationItemType.skills => Icons.auto_fix_high_outlined,
    ExternalAgentConfigMigrationItemType.plugins => Icons.extension_outlined,
    ExternalAgentConfigMigrationItemType.mcpServerConfig => Icons.hub_outlined,
    ExternalAgentConfigMigrationItemType.subagents =>
      Icons.account_tree_outlined,
    ExternalAgentConfigMigrationItemType.hooks => Icons.webhook_outlined,
    ExternalAgentConfigMigrationItemType.commands => Icons.terminal_outlined,
    ExternalAgentConfigMigrationItemType.sessions => Icons.forum_outlined,
    ExternalAgentConfigMigrationItemType.unknown => Icons.help_outline,
  };
}
