import 'package:flutter/material.dart';

import '../../theme/sadcoder_theme.dart';

class DiffTextBlock extends StatelessWidget {
  const DiffTextBlock({super.key, required this.text, this.label});

  final String text;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = SadCoderThemeColors.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null && label!.trim().isNotEmpty)
            Container(
              color: colors.diffHeaderBackground,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                label!,
                style: TextStyle(
                  color: colors.diffHeaderForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (final line in text.trimRight().split('\n'))
            _DiffLine(line: line),
        ],
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
