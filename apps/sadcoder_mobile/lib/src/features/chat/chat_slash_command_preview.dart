import 'package:flutter/material.dart';

import '../../commands/slash_command_registry.dart';
import '../../i18n/app_localizations.dart';

class ChatSlashCommandPreview extends StatelessWidget {
  const ChatSlashCommandPreview({
    super.key,
    required this.result,
    required this.sendAsText,
    required this.onSendAsText,
  });

  final SlashCommandParseResult result;
  final bool sendAsText;
  final VoidCallback onSendAsText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sendAsTextButton = TextButton(
      key: const ValueKey('slash-command-send-as-text'),
      onPressed: onSendAsText,
      child: Text(l10n.slashCommandSendAsText),
    );
    return switch (result.kind) {
      SlashCommandParseKind.notSlash => const SizedBox.shrink(),
      SlashCommandParseKind.empty => _PreviewCard(
        icon: Icons.manage_search,
        title: l10n.slashCommands,
        subtitle: l10n.typeCommandName,
      ),
      SlashCommandParseKind.unknown => _PreviewCard(
        icon: Icons.error_outline,
        title: l10n.slashCommandUnknown('/${result.rawCommand}'),
        subtitle: sendAsText
            ? l10n.slashCommandWillSendAsPrompt
            : l10n.slashCommandNotSentAsPrompt,
        trailing: sendAsText ? null : sendAsTextButton,
      ),
      SlashCommandParseKind.known => _PreviewCard(
        icon: Icons.terminal,
        title: result.command!.slash,
        subtitle: sendAsText
            ? l10n.slashCommandWillSendAsPrompt
            : l10n.slashCommandDescription(
                result.command!.command,
                result.command!.description,
              ),
        trailing: sendAsText ? null : sendAsTextButton,
      ),
    };
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 18, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
