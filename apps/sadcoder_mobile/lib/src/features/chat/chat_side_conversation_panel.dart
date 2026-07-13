import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';

class ChatSideConversation {
  const ChatSideConversation({
    required this.parentThreadId,
    required this.sideThreadId,
    required this.slash,
  });

  final String parentThreadId;
  final String sideThreadId;
  final String slash;
}

class ChatSideConversationPanel extends StatelessWidget {
  const ChatSideConversationPanel({
    super.key,
    required this.conversation,
    required this.canReturn,
    required this.onReturn,
  });

  final ChatSideConversation conversation;
  final bool canReturn;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      key: const ValueKey('chat-side-conversation-panel'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.34),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: colorScheme.tertiary),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 8, 9),
            child: Row(
              children: [
                Icon(
                  Icons.call_split_outlined,
                  size: 18,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l10n.sideConversationTitle} · ${conversation.slash}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  key: const ValueKey('chat-side-return-main'),
                  onPressed: canReturn ? onReturn : null,
                  tooltip: l10n.returnToMainThread,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size.square(32),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.keyboard_return, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
