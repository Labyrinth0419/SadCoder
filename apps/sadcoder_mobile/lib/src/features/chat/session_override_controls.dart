import 'package:flutter/material.dart';

import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../i18n/app_localizations.dart';
import 'config_override_controls.dart';
import 'config_override_labels.dart';

class SessionOverrideControls extends StatelessWidget {
  const SessionOverrideControls({
    super.key,
    required this.controller,
    this.onApplySessionOverrides,
  });

  final CodexConfigOverrideController controller;
  final Future<void> Function(CodexConfigOverrides overrides)?
  onApplySessionOverrides;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _SessionOverrideBar(
        controller: controller,
        onApplySessionOverrides: onApplySessionOverrides,
      ),
    );
  }
}

class _SessionOverrideBar extends StatelessWidget {
  const _SessionOverrideBar({
    required this.controller,
    this.onApplySessionOverrides,
  });

  final CodexConfigOverrideController controller;
  final Future<void> Function(CodexConfigOverrides overrides)?
  onApplySessionOverrides;

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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ConfigOverrideSourceChip(
                          label: l10n.modelOverride,
                          value: sessionDefault.model,
                          source: _sessionSourceFor(layers, 'model'),
                        ),
                        const SizedBox(width: 8),
                        ConfigOverrideSourceChip(
                          label: l10n.effortOverride,
                          value: sessionDefault.effort,
                          source: _sessionSourceFor(layers, 'effort'),
                        ),
                        const SizedBox(width: 8),
                        ConfigOverrideSourceChip(
                          label: l10n.approvalPolicy,
                          value: configOverrideValueLabel(
                            sessionDefault.approvalPolicy,
                          ),
                          source: _sessionSourceFor(layers, 'approvalPolicy'),
                        ),
                        const SizedBox(width: 8),
                        ConfigOverrideSourceChip(
                          label: l10n.permissionProfile,
                          value: sessionDefault.permissionProfile,
                          source: _sessionSourceFor(
                            layers,
                            'permissionProfile',
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConfigOverrideSourceChip(
                          label: l10n.sandboxMode,
                          value: configOverrideValueLabel(
                            sessionDefault.sandboxPolicy,
                          ),
                          source: _sessionSourceFor(layers, 'sandboxPolicy'),
                        ),
                        const SizedBox(width: 8),
                        ConfigOverrideSourceChip(
                          label: l10n.cwdOverride,
                          value: sessionDefault.cwd,
                          source: _sessionSourceFor(layers, 'cwd'),
                        ),
                        const SizedBox(width: 8),
                        ConfigOverrideSourceChip(
                          label: l10n.personalityOverride,
                          value: sessionDefault.personality,
                          source: _sessionSourceFor(layers, 'personality'),
                        ),
                      ],
                    ),
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
      builder: (context) => _SessionOverrideSheet(
        controller: controller,
        onApplySessionOverrides: onApplySessionOverrides,
      ),
    );
  }

  CodexConfigOverrideSource _sessionSourceFor(
    CodexConfigOverrideLayers layers,
    String fieldName,
  ) {
    final sessionDefault = layers.appDefault.merge(layers.session);
    if (fieldName == 'permissionProfile' &&
        !_hasText(sessionDefault.permissionProfile)) {
      return CodexConfigOverrideSource.serverDefault;
    }
    if (fieldName == 'sandboxPolicy' &&
        (sessionDefault.sandboxPolicy == null ||
            sessionDefault.sandboxPolicy!.isEmpty)) {
      return CodexConfigOverrideSource.serverDefault;
    }
    final wireFieldName = fieldName == 'permissionProfile'
        ? 'permissions'
        : fieldName;
    if (layers.session.toTurnStartParams().containsKey(wireFieldName)) {
      return CodexConfigOverrideSource.session;
    }
    if (layers.appDefault.toTurnStartParams().containsKey(wireFieldName)) {
      return CodexConfigOverrideSource.appDefault;
    }
    return CodexConfigOverrideSource.serverDefault;
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

class _SessionOverrideSheet extends StatefulWidget {
  const _SessionOverrideSheet({
    required this.controller,
    this.onApplySessionOverrides,
  });

  final CodexConfigOverrideController controller;
  final Future<void> Function(CodexConfigOverrides overrides)?
  onApplySessionOverrides;

  @override
  State<_SessionOverrideSheet> createState() => _SessionOverrideSheetState();
}

class _SessionOverrideSheetState extends State<_SessionOverrideSheet> {
  late final TextEditingController _modelController;
  late final TextEditingController _effortController;
  late final TextEditingController _cwdController;
  bool _isApplying = false;

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
                  onPressed: _isApplying ? null : _apply,
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

  Future<void> _apply() async {
    final overrides = CodexConfigOverrides(
      model: _modelController.text,
      effort: _effortController.text,
      cwd: _cwdController.text,
    );
    setState(() => _isApplying = true);
    try {
      final applyToSession = widget.onApplySessionOverrides;
      if (applyToSession != null) {
        await applyToSession(overrides);
      }
      widget.controller.setSession(overrides);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.threadSettingsUpdateFailed}: $error'),
        ),
      );
    }
  }

  void _clear() {
    widget.controller.clearSession();
    Navigator.of(context).pop();
  }
}
