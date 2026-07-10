import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../theme/sadcoder_theme.dart';
import 'workspace_syntax_highlighter.dart';

class WorkspaceMarkdownPreview extends StatelessWidget {
  const WorkspaceMarkdownPreview({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = SadCoderThemeColors.of(context);
    final bodyStyle = theme.textTheme.bodyMedium;
    final codeStyle = bodyStyle?.copyWith(
      fontFamily: 'monospace',
      color: colors.codeForeground,
    );

    return MarkdownBody(
      key: const ValueKey('workspace-markdown-preview'),
      data: content,
      selectable: true,
      fitContent: true,
      syntaxHighlighter: WorkspaceSyntaxHighlighter(
        colors: colors,
        baseStyle: codeStyle,
      ),
      imageBuilder: (uri, title, alt) =>
          _BlockedMarkdownImage(uri: uri, description: alt ?? title),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        a: bodyStyle?.copyWith(
          color: colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: colorScheme.primary,
        ),
        p: bodyStyle,
        code: codeStyle?.copyWith(backgroundColor: colors.codeBackground),
        h1: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        strong: const TextStyle(fontWeight: FontWeight.w700),
        blockSpacing: 12,
        listIndent: 28,
        blockquote: bodyStyle?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        blockquoteDecoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          border: Border(
            left: BorderSide(color: colorScheme.primary, width: 4),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: colors.codeBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        tableBorder: TableBorder.all(color: colorScheme.outlineVariant),
        tableHead: bodyStyle?.copyWith(fontWeight: FontWeight.w700),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
      ),
    );
  }
}

class _BlockedMarkdownImage extends StatelessWidget {
  const _BlockedMarkdownImage({required this.uri, this.description});

  final Uri uri;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = description?.trim();
    return Container(
      key: const ValueKey('workspace-markdown-image-placeholder'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_not_supported_outlined, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              [
                if (label != null && label.isNotEmpty) label,
                uri.toString(),
              ].join(' - '),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
