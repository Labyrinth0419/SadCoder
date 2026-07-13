import 'package:flutter/material.dart';

import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../i18n/app_localizations.dart';
import 'raw_rpc_panel.dart';
import 'session_override_controls.dart';
import 'turn_override_controls.dart';

class ChatAdvancedControlsSheet extends StatelessWidget {
  const ChatAdvancedControlsSheet({
    super.key,
    required this.configOverrideController,
    required this.rawRpcSender,
    required this.onApplySessionOverrides,
  });

  final CodexConfigOverrideController? configOverrideController;
  final RawRpcSender? rawRpcSender;
  final Future<void> Function(CodexConfigOverrides overrides)?
  onApplySessionOverrides;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = configOverrideController;
    return FractionallySizedBox(
      key: const ValueKey('chat-advanced-controls-sheet'),
      heightFactor: 0.88,
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.62,
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      Icons.tune,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.showChatAdvancedControls,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('chat-advanced-controls-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (controller != null) ...[
                    SessionOverrideControls(
                      controller: controller,
                      onApplySessionOverrides: onApplySessionOverrides,
                    ),
                    const SizedBox(height: 10),
                    TurnOverrideControls(controller: controller),
                    const SizedBox(height: 10),
                  ],
                  RawRpcPanel(onSend: rawRpcSender),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
