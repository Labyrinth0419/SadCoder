import 'package:flutter/material.dart';

import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../i18n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.configOverrideController});

  final CodexConfigOverrideController? configOverrideController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.settings, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.serverDefaults),
            subtitle: Text(l10n.serverDefaultsBody),
          ),
        ),
        if (configOverrideController != null)
          _AppDefaultOverridesCard(controller: configOverrideController!),
        Card(
          child: ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: Text(l10n.theme),
            subtitle: Text(l10n.themeBody),
          ),
        ),
      ],
    );
  }
}

class _AppDefaultOverridesCard extends StatefulWidget {
  const _AppDefaultOverridesCard({required this.controller});

  final CodexConfigOverrideController controller;

  @override
  State<_AppDefaultOverridesCard> createState() =>
      _AppDefaultOverridesCardState();
}

class _AppDefaultOverridesCardState extends State<_AppDefaultOverridesCard> {
  late final TextEditingController _modelController;
  late final TextEditingController _effortController;
  late final TextEditingController _cwdController;

  @override
  void initState() {
    super.initState();
    final appDefault = widget.controller.layers.appDefault;
    _modelController = TextEditingController(text: appDefault.model ?? '');
    _effortController = TextEditingController(text: appDefault.effort ?? '');
    _cwdController = TextEditingController(text: appDefault.cwd ?? '');
  }

  @override
  void dispose() {
    _modelController.dispose();
    _effortController.dispose();
    _cwdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.rule_folder_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.appDefaultOverrides,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  label: l10n.modelOverride,
                  source: widget.controller.sourceFor('model'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('settings-model-override'),
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: l10n.modelOverride,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  label: l10n.effortOverride,
                  source: widget.controller.sourceFor('effort'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('settings-effort-override'),
                  controller: _effortController,
                  decoration: InputDecoration(
                    labelText: l10n.effortOverride,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _SourceLine(
                  label: l10n.cwdOverride,
                  source: widget.controller.sourceFor('cwd'),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('settings-cwd-override'),
                  controller: _cwdController,
                  decoration: InputDecoration(
                    labelText: l10n.cwdOverride,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.restore),
                      label: Text(l10n.clearOverrides),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _apply,
                      icon: const Icon(Icons.check),
                      label: Text(l10n.applyOverrides),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _apply() {
    widget.controller.setAppDefault(
      CodexConfigOverrides(
        model: _modelController.text,
        effort: _effortController.text,
        cwd: _cwdController.text,
      ),
    );
  }

  void _clear() {
    _modelController.clear();
    _effortController.clear();
    _cwdController.clear();
    widget.controller.setAppDefault(CodexConfigOverrides.empty);
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.label, required this.source});

  final String label;
  final CodexConfigOverrideSource source;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Text(
      '$label - ${l10n.overrideSource}: ${_sourceLabel(l10n, source)}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  String _sourceLabel(AppLocalizations l10n, CodexConfigOverrideSource source) {
    return switch (source) {
      CodexConfigOverrideSource.serverDefault => l10n.sourceServerDefault,
      CodexConfigOverrideSource.appDefault => l10n.sourceAppDefault,
      CodexConfigOverrideSource.session => l10n.sourceSessionOverride,
      CodexConfigOverrideSource.turn => l10n.sourceTurnOverride,
    };
  }
}
