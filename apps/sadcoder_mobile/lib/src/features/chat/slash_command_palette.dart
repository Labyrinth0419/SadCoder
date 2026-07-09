import 'package:flutter/material.dart';

import '../../commands/slash_command_registry.dart';
import '../../i18n/app_localizations.dart';

Future<void> showSlashCommandPalette({
  required BuildContext context,
  required SlashCommandRegistry registry,
  required bool hasActiveTurn,
  required ValueChanged<SlashCommandSpec> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SlashCommandPalette(
      registry: registry,
      hasActiveTurn: hasActiveTurn,
      onSelected: onSelected,
    ),
  );
}

class _SlashCommandPalette extends StatefulWidget {
  const _SlashCommandPalette({
    required this.registry,
    required this.hasActiveTurn,
    required this.onSelected,
  });

  final SlashCommandRegistry registry;
  final bool hasActiveTurn;
  final ValueChanged<SlashCommandSpec> onSelected;

  @override
  State<_SlashCommandPalette> createState() => _SlashCommandPaletteState();
}

class _SlashCommandPaletteState extends State<_SlashCommandPalette> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final commands = _filteredCommands();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.manage_search),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.slashCommands,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('slash-command-search-field'),
              controller: _filterController,
              autofocus: true,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.typeCommandName,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: commands.length,
                itemBuilder: (context, index) => _SlashCommandTile(
                  command: commands[index],
                  hasActiveTurn: widget.hasActiveTurn,
                  onSelected: widget.onSelected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SlashCommandSpec> _filteredCommands() {
    final normalized = _filter.trim().toLowerCase().replaceFirst('/', '');
    if (normalized.isEmpty) {
      return widget.registry.commands;
    }
    return [
      for (final command in widget.registry.commands)
        if (_matches(command, normalized)) command,
    ];
  }

  bool _matches(SlashCommandSpec command, String query) {
    return command.command.contains(query) ||
        command.aliases.any((alias) => alias.contains(query)) ||
        command.description.toLowerCase().contains(query);
  }
}

class _SlashCommandTile extends StatelessWidget {
  const _SlashCommandTile({
    required this.command,
    required this.hasActiveTurn,
    required this.onSelected,
  });

  final SlashCommandSpec command;
  final bool hasActiveTurn;
  final ValueChanged<SlashCommandSpec> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final disabled = hasActiveTurn && !command.availableDuringTask;
    return ListTile(
      key: ValueKey('slash-command-${command.command}'),
      enabled: !disabled,
      leading: Icon(_iconFor(command)),
      title: Text(command.slash),
      subtitle: Text(_subtitle(l10n, disabled)),
      trailing: Wrap(
        spacing: 6,
        children: [
          _SmallBadge(label: command.mappingType.name),
          _SmallBadge(label: command.phase.name),
        ],
      ),
      onTap: disabled
          ? null
          : () {
              onSelected(command);
              Navigator.of(context).pop();
            },
    );
  }

  String _subtitle(AppLocalizations l10n, bool disabled) {
    final details = <String>[command.description];
    if (command.aliases.isNotEmpty) {
      details.add(
        'aliases: ${command.aliases.map((alias) => '/$alias').join(', ')}',
      );
    }
    if (disabled) {
      details.add(l10n.slashCommandUnavailableDuringTask);
    }
    if (command.riskLevel != SlashCommandRiskLevel.low) {
      details.add('${l10n.slashCommandRisk}: ${command.riskLevel.name}');
    }
    return details.join('\n');
  }

  IconData _iconFor(SlashCommandSpec command) {
    return switch (command.mappingType) {
      SlashCommandMappingType.appServer => Icons.hub_outlined,
      SlashCommandMappingType.uiOnly => Icons.phone_android,
      SlashCommandMappingType.agentFallback => Icons.terminal,
      SlashCommandMappingType.topology => Icons.account_tree_outlined,
      SlashCommandMappingType.notApplicable => Icons.block,
      SlashCommandMappingType.debug => Icons.bug_report_outlined,
    };
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}
