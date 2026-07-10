import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../theme/sadcoder_theme.dart';

class DiffTextBlock extends StatefulWidget {
  const DiffTextBlock({
    super.key,
    required this.text,
    this.label,
    this.initialLineLimit = 600,
  });

  final String text;
  final String? label;
  final int initialLineLimit;

  @override
  State<DiffTextBlock> createState() => _DiffTextBlockState();
}

class _DiffTextBlockState extends State<DiffTextBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = SadCoderThemeColors.of(context);
    final lines = widget.text.trimRight().split('\n');
    final lineLimit = widget.initialLineLimit <= 0
        ? lines.length
        : widget.initialLineLimit;
    final truncated = !_expanded && lines.length > lineLimit;
    final visibleLines = truncated ? lines.take(lineLimit) : lines;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.label != null && widget.label!.trim().isNotEmpty)
            Container(
              color: colors.diffHeaderBackground,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                widget.label!,
                style: TextStyle(
                  color: colors.diffHeaderForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (final line in visibleLines) _DiffLine(line: line),
          if (truncated)
            _DiffTruncationFooter(
              shownLines: lineLimit,
              totalLines: lines.length,
              onShowFull: () => setState(() => _expanded = true),
            ),
        ],
      ),
    );
  }
}

class _DiffTruncationFooter extends StatelessWidget {
  const _DiffTruncationFooter({
    required this.shownLines,
    required this.totalLines,
    required this.onShowFull,
  });

  final int shownLines;
  final int totalLines;
  final VoidCallback onShowFull;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              l10n.diffTruncated(shownLines, totalLines),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton.icon(
              key: const ValueKey('diff-show-full'),
              onPressed: onShowFull,
              icon: const Icon(Icons.unfold_more),
              label: Text(l10n.diffShowFull),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiffLine extends StatelessWidget {
  const _DiffLine({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final colors = SadCoderThemeColors.of(context);
    final isAdded = line.startsWith('+') && !line.startsWith('+++');
    final isRemoved = line.startsWith('-') && !line.startsWith('---');
    final isHeader =
        line.startsWith('diff ') ||
        line.startsWith('index ') ||
        line.startsWith('@@') ||
        line.startsWith('---') ||
        line.startsWith('+++');
    return Container(
      color: isAdded
          ? colors.diffAddedBackground
          : isRemoved
          ? colors.diffRemovedBackground
          : isHeader
          ? colors.diffHeaderBackground
          : colors.codeBackground,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: SelectableText(
        line,
        style: TextStyle(
          color: isAdded
              ? colors.diffAddedForeground
              : isRemoved
              ? colors.diffRemovedForeground
              : isHeader
              ? colors.diffHeaderForeground
              : colors.codeForeground,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
