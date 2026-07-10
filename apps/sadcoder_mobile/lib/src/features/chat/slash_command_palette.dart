import 'package:flutter/material.dart';

import '../../commands/slash_command_registry.dart';
import '../../i18n/app_localizations.dart';

Future<void> showSlashCommandPalette({
  required BuildContext context,
  required SlashCommandRegistry registry,
  required bool hasActiveTurn,
  required bool isSideConversation,
  required ValueChanged<SlashCommandSpec> onSelected,
  bool showUnavailableCommands = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SlashCommandPalette(
      registry: registry,
      hasActiveTurn: hasActiveTurn,
      isSideConversation: isSideConversation,
      onSelected: onSelected,
      showUnavailableCommands: showUnavailableCommands,
    ),
  );
}

class _SlashCommandPalette extends StatefulWidget {
  const _SlashCommandPalette({
    required this.registry,
    required this.hasActiveTurn,
    required this.isSideConversation,
    required this.onSelected,
    required this.showUnavailableCommands,
  });

  final SlashCommandRegistry registry;
  final bool hasActiveTurn;
  final bool isSideConversation;
  final ValueChanged<SlashCommandSpec> onSelected;
  final bool showUnavailableCommands;

  @override
  State<_SlashCommandPalette> createState() => _SlashCommandPaletteState();
}

class _SlashCommandPaletteState extends State<_SlashCommandPalette> {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';
  _SlashCommandGroup _selectedGroup = _SlashCommandGroup.common;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableHeight = screenHeight - bottomInset;
    final sheetHeight = (availableHeight * 0.86)
        .clamp(220.0, screenHeight * 0.86)
        .toDouble();
    final commands = _filteredCommands(l10n);
    final groups = _groupsFor(commands);
    final selectedGroup = groups.isEmpty
        ? null
        : (groups.contains(_selectedGroup) ? _selectedGroup : groups.first);
    final selectedCommands = selectedGroup == null
        ? const <SlashCommandSpec>[]
        : _commandsForGroup(commands, selectedGroup);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.max,
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
                Expanded(
                  child: selectedGroup == null
                      ? const SizedBox.shrink()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SlashCommandGroupRail(
                              groups: groups,
                              selectedGroup: selectedGroup,
                              onSelected: (group) =>
                                  setState(() => _selectedGroup = group),
                            ),
                            const VerticalDivider(width: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: selectedCommands.length,
                                itemBuilder: (context, index) =>
                                    _SlashCommandTile(
                                      command: selectedCommands[index],
                                      hasActiveTurn: widget.hasActiveTurn,
                                      isSideConversation:
                                          widget.isSideConversation,
                                      onSelected: widget.onSelected,
                                    ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<SlashCommandSpec> _filteredCommands(AppLocalizations l10n) {
    final normalized = _filter.trim().toLowerCase().replaceFirst('/', '');
    final visibleCommands = widget.showUnavailableCommands
        ? widget.registry.commands
        : widget.registry.commands.where(_isVisibleByDefault);
    if (normalized.isEmpty) {
      return visibleCommands.toList(growable: false);
    }
    return [
      for (final command in visibleCommands)
        if (_matches(command, normalized, l10n)) command,
    ];
  }

  bool _matches(SlashCommandSpec command, String query, AppLocalizations l10n) {
    final localizedDescription = l10n.slashCommandDescription(
      command.command,
      command.description,
    );
    final argumentHint = l10n.slashCommandArgumentHint(command.command);
    return command.command.contains(query) ||
        command.aliases.any((alias) => alias.contains(query)) ||
        command.description.toLowerCase().contains(query) ||
        localizedDescription.toLowerCase().contains(query) ||
        argumentHint.toLowerCase().contains(query);
  }

  List<_SlashCommandGroup> _groupsFor(List<SlashCommandSpec> commands) {
    return [
      for (final group in _SlashCommandGroup.values)
        if (commands.any((command) => _groupFor(command) == group)) group,
    ];
  }

  List<SlashCommandSpec> _commandsForGroup(
    List<SlashCommandSpec> commands,
    _SlashCommandGroup group,
  ) {
    return [
      for (final command in commands)
        if (_groupFor(command) == group) command,
    ];
  }
}

bool _isVisibleByDefault(SlashCommandSpec command) {
  return switch (command.platformVisibility) {
    SlashPlatformVisibility.desktopOnly ||
    SlashPlatformVisibility.debugOnly => false,
    SlashPlatformVisibility.all ||
    SlashPlatformVisibility.windowsOnly ||
    SlashPlatformVisibility.tuiOnly => true,
  };
}

enum _SlashCommandGroup {
  common,
  session,
  configuration,
  filesAndCommands,
  mcpAndExtensions,
  debug,
}

class _SlashCommandGroupRail extends StatelessWidget {
  const _SlashCommandGroupRail({
    required this.groups,
    required this.selectedGroup,
    required this.onSelected,
  });

  final List<_SlashCommandGroup> groups;
  final _SlashCommandGroup selectedGroup;
  final ValueChanged<_SlashCommandGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: ListView.separated(
        itemCount: groups.length,
        separatorBuilder: (context, index) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final group = groups[index];
          return _SlashCommandGroupButton(
            group: group,
            selected: group == selectedGroup,
            onTap: () => onSelected(group),
          );
        },
      ),
    );
  }
}

class _SlashCommandGroupButton extends StatelessWidget {
  const _SlashCommandGroupButton({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final _SlashCommandGroup group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      key: ValueKey('slash-command-group-${group.name}'),
      color: selected
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Icon(
                _groupIcon(group),
                size: 18,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.l10n.slashCommandGroupLabel(group.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _groupIcon(_SlashCommandGroup group) {
    return switch (group) {
      _SlashCommandGroup.common => Icons.star_outline,
      _SlashCommandGroup.session => Icons.forum_outlined,
      _SlashCommandGroup.configuration => Icons.tune,
      _SlashCommandGroup.filesAndCommands => Icons.terminal,
      _SlashCommandGroup.mcpAndExtensions => Icons.extension_outlined,
      _SlashCommandGroup.debug => Icons.bug_report_outlined,
    };
  }
}

class _SlashCommandTile extends StatelessWidget {
  const _SlashCommandTile({
    required this.command,
    required this.hasActiveTurn,
    required this.isSideConversation,
    required this.onSelected,
  });

  final SlashCommandSpec command;
  final bool hasActiveTurn;
  final bool isSideConversation;
  final ValueChanged<SlashCommandSpec> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final unavailableDuringTask = hasActiveTurn && !command.availableDuringTask;
    final unavailableInSide =
        isSideConversation && !command.availableInSideConversation;
    final disabled = unavailableDuringTask || unavailableInSide;
    final subtitle = _subtitle(
      l10n,
      unavailableDuringTask: unavailableDuringTask,
      unavailableInSide: unavailableInSide,
    );
    return Material(
      key: ValueKey('slash-command-${command.command}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                onSelected(command);
                Navigator.of(context).pop();
              },
        child: Opacity(
          opacity: disabled ? 0.48 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(_iconFor(command)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(command.slash, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SmallBadge(
                            key: ValueKey(
                              'slash-command-${command.command}-mapping-label',
                            ),
                            label: l10n.slashCommandMappingLabel(
                              command.mappingType.name,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _SmallBadge(
                            key: ValueKey(
                              'slash-command-${command.command}-phase-label',
                            ),
                            label: l10n.slashCommandPhaseLabel(
                              command.phase.name,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(
    AppLocalizations l10n, {
    required bool unavailableDuringTask,
    required bool unavailableInSide,
  }) {
    final details = <String>[
      l10n.slashCommandDescription(command.command, command.description),
    ];
    final argumentHint = l10n.slashCommandArgumentHint(command.command);
    if (argumentHint.isNotEmpty) {
      details.add(l10n.slashCommandArgs(argumentHint));
    }
    if (command.aliases.isNotEmpty) {
      details.add(
        l10n.slashCommandAliases(
          command.aliases.map((alias) => '/$alias').join(', '),
        ),
      );
    }
    if (unavailableDuringTask) {
      details.add(l10n.slashCommandUnavailableDuringTask);
    }
    if (unavailableInSide) {
      details.add(l10n.slashCommandUnavailableInSideConversation);
    }
    if (command.riskLevel != SlashCommandRiskLevel.low) {
      details.add(
        '${l10n.slashCommandRisk}: '
        '${l10n.slashCommandRiskLevelLabel(command.riskLevel.name)}',
      );
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

_SlashCommandGroup _groupFor(SlashCommandSpec command) {
  return switch (command.command) {
    'model' ||
    'permissions' ||
    'status' ||
    'usage' ||
    'copy' ||
    'raw' => _SlashCommandGroup.common,
    'new' ||
    'resume' ||
    'rename' ||
    'archive' ||
    'delete' ||
    'fork' ||
    'duplicate' ||
    'rewind' ||
    'app' ||
    'compact' ||
    'plan' ||
    'goal' ||
    'agent' ||
    'side' ||
    'btw' ||
    'logout' ||
    'quit' ||
    'exit' ||
    'clear' ||
    'subagents' => _SlashCommandGroup.session,
    'keymap' ||
    'vim' ||
    'setup-default-sandbox' ||
    'sandbox-add-read-dir' ||
    'experimental' ||
    'memories' ||
    'title' ||
    'statusline' ||
    'theme' ||
    'personality' => _SlashCommandGroup.configuration,
    'ide' ||
    'approve' ||
    'review' ||
    'init' ||
    'diff' ||
    'mention' ||
    'ps' ||
    'stop' => _SlashCommandGroup.filesAndCommands,
    'skills' ||
    'import' ||
    'hooks' ||
    'mcp' ||
    'apps' ||
    'plugins' => _SlashCommandGroup.mcpAndExtensions,
    'debug-config' ||
    'feedback' ||
    'rollout' ||
    'test-approval' ||
    'debug-m-drop' ||
    'debug-m-update' => _SlashCommandGroup.debug,
    _ => _SlashCommandGroup.common,
  };
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({super.key, required this.label});

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
