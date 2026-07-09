import 'package:flutter/material.dart';

import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../i18n/app_localizations.dart';
import 'config_override_controls.dart';

class SessionOverrideControls extends StatelessWidget {
  const SessionOverrideControls({super.key, required this.controller});

  final CodexConfigOverrideController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _SessionOverrideBar(controller: controller),
    );
  }
}

class _SessionOverrideBar extends StatelessWidget {
  const _SessionOverrideBar({required this.controller});

  final CodexConfigOverrideController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final layers = controller.layers;
    final sessionDefault = layers.appDefault.merge(layers.session);
    final hasSessionOverrides = layers.session.toTurnStartParams().isNotEmpty;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.forum_outlined, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.sessionOverrides,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ConfigOverrideSourceChip(
                        label: l10n.modelOverride,
                        value: sessionDefault.model,
                        source: _sessionSourceFor(layers, 'model'),
                      ),
                      ConfigOverrideSourceChip(
                        label: l10n.effortOverride,
                        value: sessionDefault.effort,
                        source: _sessionSourceFor(layers, 'effort'),
                      ),
                      ConfigOverrideSourceChip(
                        label: l10n.cwdOverride,
                        value: sessionDefault.cwd,
                        source: _sessionSourceFor(layers, 'cwd'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('chat-session-overrides-clear'),
              onPressed: hasSessionOverrides ? controller.clearSession : null,
              icon: const Icon(Icons.restore),
              tooltip: l10n.clearSessionOverrides,
            ),
            IconButton(
              key: const ValueKey('chat-session-overrides-edit'),
              onPressed: () => _showSessionOverrideSheet(context, controller),
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editSessionOverrides,
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionOverrideSheet(
    BuildContext context,
    CodexConfigOverrideController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SessionOverrideSheet(controller: controller),
    );
  }

  CodexConfigOverrideSource _sessionSourceFor(
    CodexConfigOverrideLayers layers,
    String fieldName,
  ) {
    if (layers.session.toTurnStartParams().containsKey(fieldName)) {
      return CodexConfigOverrideSource.session;
    }
    if (layers.appDefault.toTurnStartParams().containsKey(fieldName)) {
      return CodexConfigOverrideSource.appDefault;
    }
    return CodexConfigOverrideSource.serverDefault;
  }
}

class _SessionOverrideSheet extends StatefulWidget {
  const _SessionOverrideSheet({required this.controller});

  final CodexConfigOverrideController controller;

  @override
  State<_SessionOverrideSheet> createState() => _SessionOverrideSheetState();
}

class _SessionOverrideSheetState extends State<_SessionOverrideSheet> {
  late final TextEditingController _modelController;
  late final TextEditingController _effortController;
  late final TextEditingController _cwdController;

  @override
  void initState() {
    super.initState();
    final session = widget.controller.layers.session;
    _modelController = TextEditingController(text: session.model ?? '');
    _effortController = TextEditingController(text: session.effort ?? '');
    _cwdController = TextEditingController(text: session.cwd ?? '');
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.sessionOverrides,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-session-model-override',
              controller: _modelController,
              label: l10n.modelOverride,
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-session-effort-override',
              controller: _effortController,
              label: l10n.effortOverride,
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-session-cwd-override',
              controller: _cwdController,
              label: l10n.cwdOverride,
            ),
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey('chat-session-overrides-sheet-clear'),
                  onPressed: _clear,
                  icon: const Icon(Icons.restore),
                  label: Text(l10n.clearSessionOverrides),
                ),
                FilledButton.icon(
                  key: const ValueKey('chat-session-overrides-apply'),
                  onPressed: _apply,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applySessionOverrides),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _apply() {
    widget.controller.setSession(
      CodexConfigOverrides(
        model: _modelController.text,
        effort: _effortController.text,
        cwd: _cwdController.text,
      ),
    );
    Navigator.of(context).pop();
  }

  void _clear() {
    widget.controller.clearSession();
    Navigator.of(context).pop();
  }
}
