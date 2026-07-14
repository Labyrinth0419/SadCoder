import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../memories/memory_runner.dart';

class ChatMemoriesSheet extends StatefulWidget {
  const ChatMemoriesSheet({
    super.key,
    required this.runner,
    required this.threadId,
    required this.initialMode,
  });

  final MemoryRunner runner;
  final String? threadId;
  final ThreadMemoryMode? initialMode;

  @override
  State<ChatMemoriesSheet> createState() => _ChatMemoriesSheetState();
}

class _ChatMemoriesSheetState extends State<ChatMemoriesSheet> {
  late ThreadMemoryMode? _mode;
  var _busy = false;
  var _changeCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final threadAvailable = widget.threadId?.trim().isNotEmpty == true;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.memoriesTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('memories-close'),
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(_changeCount),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          const Divider(height: 1),
          SwitchListTile(
            key: const ValueKey('memories-thread-mode'),
            value: _mode == ThreadMemoryMode.enabled,
            onChanged: !_busy && threadAvailable ? _changeMode : null,
            secondary: const Icon(Icons.psychology_outlined),
            title: Text(l10n.memoriesThreadToggle),
            subtitle: Text(
              threadAvailable
                  ? l10n.memoriesThreadToggleBody
                  : l10n.memoriesThreadUnavailable,
            ),
            controlAffinity: ListTileControlAffinity.trailing,
          ),
          const Divider(height: 1),
          ListTile(
            key: const ValueKey('memories-reset'),
            enabled: !_busy,
            onTap: _busy ? null : _resetMemory,
            leading: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
            title: Text(l10n.memoriesReset),
            subtitle: Text(l10n.memoriesResetBody),
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Future<void> _changeMode(bool enabled) async {
    final threadId = widget.threadId?.trim();
    if (threadId == null || threadId.isEmpty) {
      return;
    }
    final l10n = context.l10n;
    final mode = enabled ? ThreadMemoryMode.enabled : ThreadMemoryMode.disabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.memoriesModeConfirmTitle),
        content: Text(
          context.l10n.memoriesModeConfirmBody(
            enabled ? context.l10n.appEnabled : context.l10n.appDisabled,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('memories-mode-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.memoriesModeApply),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.runner.setThreadMemoryMode(threadId: threadId, mode: mode);
      if (!mounted) {
        return;
      }
      setState(() {
        _mode = mode;
        _changeCount++;
      });
      _showMessage(l10n.memoriesModeUpdated);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = l10n.messageWithDetail(l10n.memoriesModeUpdateFailed, error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resetMemory() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.memoriesResetConfirmTitle),
        content: Text(context.l10n.memoriesResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('memories-reset-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.memoriesResetConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.runner.resetMemory();
      if (!mounted) {
        return;
      }
      setState(() => _changeCount++);
      _showMessage(l10n.memoriesResetCompleted);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = l10n.messageWithDetail(l10n.memoriesResetFailed, error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
