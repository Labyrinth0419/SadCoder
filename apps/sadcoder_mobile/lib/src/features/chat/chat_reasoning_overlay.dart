import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../files/workspace_markdown_preview.dart';
import 'chat_timeline_controller.dart';

class ChatReasoningOverlay extends StatelessWidget {
  const ChatReasoningOverlay({
    super.key,
    required this.controller,
    required this.activeTurnId,
    required this.compact,
  });

  final ChatTimelineController? controller;
  final String? activeTurnId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null || activeTurnId == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final markdown = controller.reasoningMarkdownForTurn(activeTurnId);
        if (markdown == null) {
          return const SizedBox.shrink();
        }
        return _ReasoningSurface(markdown: markdown, compact: compact);
      },
    );
  }
}

class _ReasoningSurface extends StatelessWidget {
  const _ReasoningSurface({required this.markdown, required this.compact});

  final String markdown;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('chat-reasoning-overlay'),
      constraints: BoxConstraints(maxHeight: compact ? 84 : 190),
      margin: EdgeInsets.fromLTRB(compact ? 8 : 10, 4, compact ? 8 : 10, 0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        key: const ValueKey('chat-reasoning-scroll'),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology_outlined,
                  size: 17,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 7),
                Text(
                  context.l10n.timelineReasoning,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            WorkspaceMarkdownPreview(
              key: const ValueKey('chat-reasoning-markdown'),
              content: markdown,
            ),
          ],
        ),
      ),
    );
  }
}
