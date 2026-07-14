import 'dart:async';

import 'package:flutter/material.dart';

import '../../hooks/hook_list_reader.dart';
import '../../hooks/hook_mutation_runner.dart';
import '../../i18n/app_localizations.dart';

Future<void> showChatHooksSheet({
  required BuildContext context,
  required HookListReader? reader,
  required HookMutationRunner? mutationRunner,
  required List<String> cwds,
}) async {
  if (reader == null || !context.mounted) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ChatHooksSheet(
      reader: reader,
      mutationRunner: mutationRunner,
      cwds: cwds,
    ),
  );
}

class _ChatHooksSheet extends StatefulWidget {
  const _ChatHooksSheet({
    required this.reader,
    required this.mutationRunner,
    required this.cwds,
  });

  final HookListReader reader;
  final HookMutationRunner? mutationRunner;
  final List<String> cwds;

  @override
  State<_ChatHooksSheet> createState() => _ChatHooksSheetState();
}

class _ChatHooksSheetState extends State<_ChatHooksSheet> {
  HookListPage? _page;
  Object? _error;
  bool _loading = true;
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
                    l10n.hooksManagementTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const ValueKey('chat-hooks-refresh'),
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.refreshHooks,
                ),
                IconButton(
                  key: const ValueKey('chat-hooks-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.close,
                ),
              ],
            ),
            Text(l10n.hooksManagementBody),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${l10n.hooksLoadFailed}: $_error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (!_loading && _error == null && page != null)
              Expanded(
                child: _HookEntries(page: page, owner: this),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.reader.listHooks(cwds: widget.cwds);
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

  Future<void> setEnabled(HookListEntry entry, HookSummary hook) async {
    final runner = widget.mutationRunner;
    if (runner == null || hook.isManaged || _busyKey != null) {
      return;
    }
    final l10n = context.l10n;
    final next = !hook.enabled;
    final confirmed = await _confirm(
      title: l10n.hookMutationConfirmTitle,
      body: l10n.hookMutationConfirmBody(
        hook.eventName,
        next ? l10n.hookEnableAction : l10n.hookDisableAction,
      ),
      action: next ? l10n.hookEnable : l10n.hookDisable,
    );
    if (!mounted || !confirmed) {
      return;
    }
    await _mutate(
      hook.key,
      () => runner.setHookEnabled(hookKey: hook.key, enabled: next),
    );
  }

  Future<void> trust(HookListEntry entry, HookSummary hook) async {
    final runner = widget.mutationRunner;
    if (runner == null ||
        hook.isManaged ||
        hook.currentHash.isEmpty ||
        _busyKey != null) {
      return;
    }
    final l10n = context.l10n;
    final confirmed = await _confirm(
      title: l10n.hookMutationConfirmTitle,
      body: l10n.hookTrustConfirmBody(hook.eventName),
      action: l10n.hookTrust,
    );
    if (!mounted || !confirmed) {
      return;
    }
    await _mutate(
      hook.key,
      () => runner.trustHook(hookKey: hook.key, currentHash: hook.currentHash),
    );
  }

  Future<void> _mutate(
    String key,
    Future<HookMutationResult> Function() action,
  ) async {
    setState(() => _busyKey = key);
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.hookMutationFailed}: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyKey = null);
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }
}

class _HookEntries extends StatelessWidget {
  const _HookEntries({required this.page, required this.owner});

  final HookListPage page;
  final _ChatHooksSheetState owner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (page.entries.every((entry) => entry.hooks.isEmpty)) {
      return Center(child: Text(l10n.hooksEmpty));
    }
    return ListView(
      children: [
        for (final entry in page.entries) ...[
          Text(entry.cwd, style: Theme.of(context).textTheme.titleSmall),
          for (final hook in entry.hooks)
            _HookTile(entry: entry, hook: hook, owner: owner),
          if (entry.warnings.isNotEmpty)
            Text('${l10n.hookWarnings}: ${entry.warnings.join('; ')}'),
          if (entry.errors.isNotEmpty)
            for (final error in entry.errors)
              Text('${l10n.hookErrors}: ${error.path}: ${error.message}'),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HookTile extends StatelessWidget {
  const _HookTile({
    required this.entry,
    required this.hook,
    required this.owner,
  });

  final HookListEntry entry;
  final HookSummary hook;
  final _ChatHooksSheetState owner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canMutate = owner.widget.mutationRunner != null && !hook.isManaged;
    final isBusy = owner._busyKey == hook.key;
    final details = [
      hook.command,
      hook.matcher,
      hook.sourcePath.isEmpty ? null : hook.sourcePath,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${hook.eventName} · ${hook.handlerType}'),
      subtitle: Text(
        details.isEmpty ? hook.key : '${hook.key}\n$details',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            key: ValueKey('chat-hook-trust-${hook.key}'),
            onPressed:
                canMutate &&
                    !isBusy &&
                    hook.currentHash.isNotEmpty &&
                    hook.trustStatus != 'trusted'
                ? () => owner.trust(entry, hook)
                : null,
            icon: Icon(
              hook.trustStatus == 'trusted'
                  ? Icons.verified_outlined
                  : Icons.gpp_maybe_outlined,
            ),
            tooltip: hook.trustStatus == 'trusted'
                ? l10n.hookTrusted
                : l10n.hookTrust,
          ),
          Switch(
            key: ValueKey('chat-hook-enabled-${hook.key}'),
            value: hook.enabled,
            onChanged: canMutate && !isBusy
                ? (_) => owner.setEnabled(entry, hook)
                : null,
          ),
        ],
      ),
    );
  }
}
