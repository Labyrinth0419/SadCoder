import 'package:flutter/material.dart';

import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../i18n/app_localizations.dart';

enum ChatOverrideScope { turn, session }

class ChatOverrideScopeSelector extends StatelessWidget {
  const ChatOverrideScopeSelector({
    super.key,
    required this.scope,
    required this.onChanged,
  });

  final ChatOverrideScope scope;
  final ValueChanged<ChatOverrideScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<ChatOverrideScope>(
      segments: [
        ButtonSegment(
          value: ChatOverrideScope.turn,
          icon: const Icon(Icons.send_outlined),
          label: Text(l10n.overrideTurnScope),
        ),
        ButtonSegment(
          value: ChatOverrideScope.session,
          icon: const Icon(Icons.forum_outlined),
          label: Text(l10n.overrideSessionScope),
        ),
      ],
      selected: {scope},
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}

CodexConfigOverrides chatOverridesForScope(
  CodexConfigOverrideController controller,
  ChatOverrideScope scope,
) {
  return switch (scope) {
    ChatOverrideScope.turn => controller.layers.turn,
    ChatOverrideScope.session => controller.layers.session,
  };
}
