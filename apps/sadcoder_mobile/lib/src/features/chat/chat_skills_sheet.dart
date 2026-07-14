import 'dart:async';

import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../skills/skill_list_reader.dart';
import '../../skills/skill_mutation_runner.dart';

Future<void> showChatSkillsSheet({
  required BuildContext context,
  required SkillListReader? reader,
  required SkillMutationRunner? mutationRunner,
  required List<String> cwds,
}) async {
  if (reader == null || !context.mounted) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ChatSkillsSheet(
      reader: reader,
      mutationRunner: mutationRunner,
      cwds: cwds,
    ),
  );
}

class _ChatSkillsSheet extends StatefulWidget {
  const _ChatSkillsSheet({
    required this.reader,
    required this.mutationRunner,
    required this.cwds,
  });

  final SkillListReader reader;
  final SkillMutationRunner? mutationRunner;
  final List<String> cwds;

  @override
  State<_ChatSkillsSheet> createState() => _ChatSkillsSheetState();
}

class _ChatSkillsSheetState extends State<_ChatSkillsSheet> {
  final TextEditingController _searchController = TextEditingController();
  SkillListPage? _page;
  Object? _error;
  bool _loading = true;
  String? _busyKey;
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = _page;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.skillsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const ValueKey('chat-skills-refresh'),
                  onPressed: _loading ? null : () => _load(forceReload: true),
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.refreshSkills,
                ),
                IconButton(
                  key: const ValueKey('chat-skills-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.close,
                ),
              ],
            ),
            Text(l10n.skillsManagementBody),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('chat-skills-search'),
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: l10n.searchSkills,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('chat-skills-clear-search'),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.clearSkillSearch,
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.messageWithDetail(l10n.skillsLoadFailed, _error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (!_loading && _error == null && page != null)
              Expanded(
                child: _SkillEntries(page: page, owner: this),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _load({bool forceReload = false}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.reader.listSkills(
        cwds: widget.cwds,
        forceReload: forceReload,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _page = page;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  bool matches(SkillSummary skill) {
    final query = _query.toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return [
      skill.displayName,
      skill.name,
      skill.summary,
      skill.path,
      skill.scope,
    ].any((value) => value.toLowerCase().contains(query));
  }

  Future<void> setEnabled(SkillSummary skill) async {
    final runner = widget.mutationRunner;
    final selector = _selector(skill);
    if (runner == null || selector == null || _busyKey != null) {
      return;
    }
    final l10n = context.l10n;
    final next = !skill.enabled;
    final confirmed = await _confirm(name: skill.displayName, next: next);
    if (!mounted || !confirmed) {
      return;
    }
    setState(() => _busyKey = selector);
    try {
      await runner.setSkillEnabled(
        path: skill.path.trim().isEmpty ? null : skill.path,
        name: skill.path.trim().isEmpty ? skill.name : null,
        enabled: next,
      );
      await _load(forceReload: true);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.messageWithDetail(l10n.skillMutationFailed, error),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyKey = null);
      }
    }
  }

  Future<bool> _confirm({required String name, required bool next}) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.skillMutationConfirmTitle),
        content: Text(
          l10n.skillMutationConfirmBody(
            name,
            next ? l10n.skillEnableAction : l10n.skillDisableAction,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            key: const ValueKey('chat-skill-mutation-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(next ? l10n.skillEnable : l10n.skillDisable),
          ),
        ],
      ),
    );
    return result == true;
  }

  String? _selector(SkillSummary skill) {
    final path = skill.path.trim();
    if (path.isNotEmpty) {
      return path;
    }
    final name = skill.name.trim();
    return name.isEmpty ? null : name;
  }
}

class _SkillEntries extends StatelessWidget {
  const _SkillEntries({required this.page, required this.owner});

  final SkillListPage page;
  final _ChatSkillsSheetState owner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visibleEntries = [
      for (final entry in page.entries)
        (
          entry: entry,
          skills: entry.skills.where(owner.matches).toList(growable: false),
        ),
    ].where((entry) => entry.skills.isNotEmpty).toList(growable: false);
    final hasSkills = page.entries.any((entry) => entry.skills.isNotEmpty);
    return ListView(
      children: [
        if (visibleEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(hasSkills ? l10n.skillsNoMatches : l10n.skillsEmpty),
            ),
          )
        else
          for (final section in visibleEntries) ...[
            Text(
              section.entry.cwd,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            for (final skill in section.skills)
              _SkillTile(skill: skill, owner: owner),
            const SizedBox(height: 12),
          ],
        for (final entry in page.entries)
          if (entry.errors.isNotEmpty) ...[
            Text(
              '${entry.cwd} - ${l10n.skillErrors}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final error in entry.errors)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(error.path),
                subtitle: Text(error.message),
              ),
          ],
      ],
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.skill, required this.owner});

  final SkillSummary skill;
  final _ChatSkillsSheetState owner;

  @override
  Widget build(BuildContext context) {
    final selector = owner._selector(skill);
    final busy = selector != null && owner._busyKey == selector;
    final canMutate =
        owner.widget.mutationRunner != null &&
        selector != null &&
        owner._busyKey == null;
    final details = [
      if (skill.summary.isNotEmpty) skill.summary,
      if (skill.path.isNotEmpty) skill.path,
      if (skill.scope.isNotEmpty) skill.scope,
    ].join('\n');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.auto_awesome_outlined),
      title: Text(skill.displayName),
      subtitle: details.isEmpty
          ? null
          : Text(details, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              key: ValueKey('chat-skill-enabled-$selector'),
              value: skill.enabled,
              onChanged: canMutate
                  ? (_) => unawaited(owner.setEnabled(skill))
                  : null,
            ),
    );
  }
}
