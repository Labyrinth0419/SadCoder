import 'package:flutter/material.dart';

import '../../config/codex_config_override_controller.dart';
import '../../i18n/app_localizations.dart';
import 'chat_override_scope.dart';
import 'config_override_controls.dart';

class ChatPersonalityOverrideResult {
  const ChatPersonalityOverrideResult({
    required this.scope,
    required this.personality,
  });

  final ChatOverrideScope scope;
  final String personality;
}

class ChatPersonalityOverrideSheet extends StatefulWidget {
  const ChatPersonalityOverrideSheet({super.key, required this.controller});

  final CodexConfigOverrideController controller;

  @override
  State<ChatPersonalityOverrideSheet> createState() =>
      _ChatPersonalityOverrideSheetState();
}

class _ChatPersonalityOverrideSheetState
    extends State<ChatPersonalityOverrideSheet> {
  late ChatOverrideScope _scope;
  late final TextEditingController _personalityController;

  @override
  void initState() {
    super.initState();
    _scope = ChatOverrideScope.turn;
    final overrides = chatOverridesForScope(widget.controller, _scope);
    _personalityController = TextEditingController(
      text: overrides.personality ?? '',
    );
  }

  @override
  void dispose() {
    _personalityController.dispose();
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
              l10n.personalityCommandTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ChatOverrideScopeSelector(
              scope: _scope,
              onChanged: (scope) {
                setState(() {
                  _scope = scope;
                  _loadScopeValues();
                });
              },
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-personality-command-personality',
              controller: _personalityController,
              label: l10n.personalityOverride,
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
                  key: const ValueKey('chat-personality-command-apply'),
                  onPressed: _apply,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyPersonalityOverride),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _apply() {
    Navigator.of(context).pop(
      ChatPersonalityOverrideResult(
        scope: _scope,
        personality: _personalityController.text,
      ),
    );
  }

  void _loadScopeValues() {
    final overrides = chatOverridesForScope(widget.controller, _scope);
    _personalityController.text = overrides.personality ?? '';
  }
}
