import 'package:flutter/material.dart';

import '../../appearance/app_appearance_controller.dart';
import '../../i18n/app_localizations.dart';

class TitleDisplaySheet extends StatefulWidget {
  const TitleDisplaySheet({super.key, required this.initialSettings});

  final AppTitleDisplaySettings initialSettings;

  @override
  State<TitleDisplaySheet> createState() => _TitleDisplaySheetState();
}

class _TitleDisplaySheetState extends State<TitleDisplaySheet> {
  late bool _showThreadTitle;
  late bool _showWorkingDirectory;

  @override
  void initState() {
    super.initState();
    _showThreadTitle = widget.initialSettings.showThreadTitle;
    _showWorkingDirectory = widget.initialSettings.showWorkingDirectory;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.titleCommandTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey('chat-title-command-thread'),
              contentPadding: EdgeInsets.zero,
              value: _showThreadTitle,
              title: Text(l10n.titleDisplayThread),
              onChanged: (value) {
                setState(() => _showThreadTitle = value ?? false);
              },
            ),
            CheckboxListTile(
              key: const ValueKey('chat-title-command-cwd'),
              contentPadding: EdgeInsets.zero,
              value: _showWorkingDirectory,
              title: Text(l10n.titleDisplayWorkingDirectory),
              onChanged: (value) {
                setState(() => _showWorkingDirectory = value ?? false);
              },
            ),
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.approvalCancel),
                ),
                FilledButton.icon(
                  key: const ValueKey('chat-title-command-apply'),
                  onPressed: () => Navigator.of(context).pop(
                    AppTitleDisplaySettings(
                      showThreadTitle: _showThreadTitle,
                      showWorkingDirectory: _showWorkingDirectory,
                    ),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyTitleDisplay),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatusLineDisplaySheet extends StatefulWidget {
  const StatusLineDisplaySheet({super.key, required this.initialSettings});

  final AppStatusLineDisplaySettings initialSettings;

  @override
  State<StatusLineDisplaySheet> createState() => _StatusLineDisplaySheetState();
}

class _StatusLineDisplaySheetState extends State<StatusLineDisplaySheet> {
  late bool _showConnection;
  late bool _showThread;
  late bool _showWorkingDirectory;
  late bool _showModel;
  late bool _showEffort;

  @override
  void initState() {
    super.initState();
    _showConnection = widget.initialSettings.showConnection;
    _showThread = widget.initialSettings.showThread;
    _showWorkingDirectory = widget.initialSettings.showWorkingDirectory;
    _showModel = widget.initialSettings.showModel;
    _showEffort = widget.initialSettings.showEffort;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.statusLineCommandTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _StatusLineOption(
              keyValue: 'chat-statusline-command-connection',
              value: _showConnection,
              label: l10n.connectionStatus,
              onChanged: (value) {
                setState(() => _showConnection = value ?? false);
              },
            ),
            _StatusLineOption(
              keyValue: 'chat-statusline-command-thread',
              value: _showThread,
              label: l10n.approvalThread,
              onChanged: (value) {
                setState(() => _showThread = value ?? false);
              },
            ),
            _StatusLineOption(
              keyValue: 'chat-statusline-command-cwd',
              value: _showWorkingDirectory,
              label: l10n.approvalWorkingDirectory,
              onChanged: (value) {
                setState(() => _showWorkingDirectory = value ?? false);
              },
            ),
            _StatusLineOption(
              keyValue: 'chat-statusline-command-model',
              value: _showModel,
              label: l10n.modelOverride,
              onChanged: (value) {
                setState(() => _showModel = value ?? false);
              },
            ),
            _StatusLineOption(
              keyValue: 'chat-statusline-command-effort',
              value: _showEffort,
              label: l10n.effortOverride,
              onChanged: (value) {
                setState(() => _showEffort = value ?? false);
              },
            ),
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.approvalCancel),
                ),
                FilledButton.icon(
                  key: const ValueKey('chat-statusline-command-apply'),
                  onPressed: () => Navigator.of(context).pop(
                    AppStatusLineDisplaySettings(
                      showConnection: _showConnection,
                      showThread: _showThread,
                      showWorkingDirectory: _showWorkingDirectory,
                      showModel: _showModel,
                      showEffort: _showEffort,
                    ),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyStatusLineDisplay),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLineOption extends StatelessWidget {
  const _StatusLineOption({
    required this.keyValue,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final String keyValue;
  final bool value;
  final String label;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      key: ValueKey(keyValue),
      contentPadding: EdgeInsets.zero,
      value: value,
      title: Text(label),
      onChanged: onChanged,
    );
  }
}

class TerminalPetDisplaySheet extends StatefulWidget {
  const TerminalPetDisplaySheet({super.key, required this.initialPreference});

  final AppTerminalPetPreference initialPreference;

  @override
  State<TerminalPetDisplaySheet> createState() =>
      _TerminalPetDisplaySheetState();
}

class _TerminalPetDisplaySheetState extends State<TerminalPetDisplaySheet> {
  late AppTerminalPetPreference _preference;

  @override
  void initState() {
    super.initState();
    _preference = widget.initialPreference;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.terminalPetCommandTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<AppTerminalPetPreference>(
              key: const ValueKey('chat-pets-command-mode'),
              segments: [
                ButtonSegment(
                  value: AppTerminalPetPreference.tuiOnly,
                  icon: const Icon(Icons.terminal),
                  label: Text(l10n.terminalPetTuiOnly),
                ),
                ButtonSegment(
                  value: AppTerminalPetPreference.hidden,
                  icon: const Icon(Icons.visibility_off_outlined),
                  label: Text(l10n.terminalPetHidden),
                ),
              ],
              selected: {_preference},
              onSelectionChanged: (selection) {
                setState(() => _preference = selection.single);
              },
            ),
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.approvalCancel),
                ),
                FilledButton.icon(
                  key: const ValueKey('chat-pets-command-apply'),
                  onPressed: () => Navigator.of(context).pop(_preference),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyTerminalPetDisplay),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
