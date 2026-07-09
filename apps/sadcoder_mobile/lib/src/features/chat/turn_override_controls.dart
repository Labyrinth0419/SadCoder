import 'package:flutter/material.dart';

import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../i18n/app_localizations.dart';
import 'config_override_controls.dart';
import 'config_override_labels.dart';

class TurnOverrideControls extends StatelessWidget {
  const TurnOverrideControls({super.key, required this.controller});

  final CodexConfigOverrideController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _TurnOverrideBar(controller: controller),
    );
  }
}

class _TurnOverrideBar extends StatelessWidget {
  const _TurnOverrideBar({required this.controller});

  final CodexConfigOverrideController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasTurnOverrides = controller.layers.turn
        .toTurnStartParams()
        .isNotEmpty;
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
              child: Icon(Icons.tune, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.nextTurnOverrides,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ConfigOverrideSourceChip(
                          label: l10n.modelOverride,
                          value: controller.layers.resolve().model,
                          source: controller.sourceFor('model'),
                        ),
                        const SizedBox(width: 8),
                        ConfigOverrideSourceChip(
                          label: l10n.effortOverride,
                          value: controller.layers.resolve().effort,
                          source: controller.sourceFor('effort'),
                        ),
                        const SizedBox(width: 8),
                        ConfigOverrideSourceChip(
                          label: l10n.approvalPolicy,
                          value: configOverrideValueLabel(
                            controller.layers.resolve().approvalPolicy,
                          ),
                          source: controller.sourceFor('approvalPolicy'),
                        ),
                        const SizedBox(width: 8),
                        ConfigOverrideSourceChip(
                          label: l10n.sandboxMode,
                          value: configOverrideValueLabel(
                            controller.layers.resolve().sandboxPolicy,
                          ),
                          source: controller.sourceFor('sandboxPolicy'),
                        ),
                        const SizedBox(width: 8),
                        ConfigOverrideSourceChip(
                          label: l10n.cwdOverride,
                          value: controller.layers.resolve().cwd,
                          source: controller.sourceFor('cwd'),
                        ),
                        const SizedBox(width: 8),
                        ConfigOverrideSourceChip(
                          label: l10n.personalityOverride,
                          value: controller.layers.resolve().personality,
                          source: controller.sourceFor('personality'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('chat-turn-overrides-clear'),
              onPressed: hasTurnOverrides ? controller.clearTurn : null,
              icon: const Icon(Icons.restore),
              tooltip: l10n.clearTurnOverrides,
            ),
            IconButton(
              key: const ValueKey('chat-turn-overrides-edit'),
              onPressed: () => _showTurnOverrideSheet(context, controller),
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editTurnOverrides,
            ),
          ],
        ),
      ),
    );
  }

  void _showTurnOverrideSheet(
    BuildContext context,
    CodexConfigOverrideController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TurnOverrideSheet(controller: controller),
    );
  }
}

class _TurnOverrideSheet extends StatefulWidget {
  const _TurnOverrideSheet({required this.controller});

  final CodexConfigOverrideController controller;

  @override
  State<_TurnOverrideSheet> createState() => _TurnOverrideSheetState();
}

class _TurnOverrideSheetState extends State<_TurnOverrideSheet> {
  late final TextEditingController _modelController;
  late final TextEditingController _effortController;
  late final TextEditingController _cwdController;

  @override
  void initState() {
    super.initState();
    final turn = widget.controller.layers.turn;
    _modelController = TextEditingController(text: turn.model ?? '');
    _effortController = TextEditingController(text: turn.effort ?? '');
    _cwdController = TextEditingController(text: turn.cwd ?? '');
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
              l10n.nextTurnOverrides,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-turn-model-override',
              controller: _modelController,
              label: l10n.modelOverride,
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-turn-effort-override',
              controller: _effortController,
              label: l10n.effortOverride,
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-turn-cwd-override',
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
                  key: const ValueKey('chat-turn-overrides-sheet-clear'),
                  onPressed: _clear,
                  icon: const Icon(Icons.restore),
                  label: Text(l10n.clearTurnOverrides),
                ),
                FilledButton.icon(
                  key: const ValueKey('chat-turn-overrides-apply'),
                  onPressed: _apply,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyTurnOverrides),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _apply() {
    widget.controller.setTurn(
      CodexConfigOverrides(
        model: _modelController.text,
        effort: _effortController.text,
        cwd: _cwdController.text,
      ),
    );
    Navigator.of(context).pop();
  }

  void _clear() {
    widget.controller.clearTurn();
    Navigator.of(context).pop();
  }
}
