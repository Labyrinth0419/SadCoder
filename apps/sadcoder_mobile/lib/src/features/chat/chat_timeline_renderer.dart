import 'dart:convert';

import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../theme/sadcoder_theme.dart';
import '../../threads/thread_summary.dart';
import '../diffs/diff_text_block.dart';
import '../files/workspace_markdown_preview.dart';
import 'chat_timeline_controller.dart';

class ChatTimelinePanel extends StatelessWidget {
  const ChatTimelinePanel({
    super.key,
    required this.controller,
    required this.showRaw,
    required this.onRetryOlderHistory,
  });

  final ChatTimelineController? controller;
  final bool showRaw;
  final VoidCallback onRetryOlderHistory;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _ChatTimelineContent(
        controller: controller,
        showRaw: showRaw,
        onRetryOlderHistory: onRetryOlderHistory,
      ),
    );
  }
}

class _ChatTimelineContent extends StatelessWidget {
  const _ChatTimelineContent({
    required this.controller,
    required this.showRaw,
    required this.onRetryOlderHistory,
  });

  final ChatTimelineController controller;
  final bool showRaw;
  final VoidCallback onRetryOlderHistory;

  @override
  Widget build(BuildContext context) {
    final turns = controller.turns
        .where((turn) => turn.items.any((item) => item.itemType != 'reasoning'))
        .toList(growable: false);
    if (turns.isEmpty) {
      return _TimelineEmptyState();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimelineOlderHistoryStatus(
          controller: controller,
          onRetry: onRetryOlderHistory,
        ),
        for (final turn in turns)
          _TimelineTurnView(turn: turn, showRaw: showRaw),
      ],
    );
  }
}

class _TimelineOlderHistoryStatus extends StatelessWidget {
  const _TimelineOlderHistoryStatus({
    required this.controller,
    required this.onRetry,
  });

  final ChatTimelineController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final status = controller.olderHistoryStatus;
    if (status == ChatTimelineHistoryStatus.idle) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        key: const ValueKey('timeline-older-history-status'),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              if (status == ChatTimelineHistoryStatus.loading)
                const SizedBox(
                  key: ValueKey('timeline-older-history-loading'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.error_outline, size: 17, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status == ChatTimelineHistoryStatus.loading
                      ? 'Loading earlier history'
                      : 'Earlier history failed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: status == ChatTimelineHistoryStatus.failed
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (status == ChatTimelineHistoryStatus.failed)
                TextButton(
                  key: const ValueKey('timeline-older-history-retry'),
                  onPressed: onRetry,
                  child: Text(context.l10n.workspaceFilesRetry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 36,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.noTimelineEvents,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTurnView extends StatelessWidget {
  const _TimelineTurnView({required this.turn, required this.showRaw});

  final ChatTimelineTurn turn;
  final bool showRaw;

  @override
  Widget build(BuildContext context) {
    final items = turn.items
        .where((item) => item.itemType != 'reasoning')
        .toList(growable: false);
    return Padding(
      key: ValueKey('timeline-turn-${turn.turnId}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Text(context.l10n.noTimelineEvents)
          else
            for (final item in items)
              _TimelineItemView(item: item, showRaw: showRaw),
        ],
      ),
    );
  }
}

class _TimelineItemView extends StatelessWidget {
  const _TimelineItemView({required this.item, required this.showRaw});

  final ChatTimelineItem item;
  final bool showRaw;

  @override
  Widget build(BuildContext context) {
    final body = _body(context);
    final title = _title(context);
    final icon = _iconFor(item.itemType);
    if (item.itemType == 'queuedInstruction' ||
        item.itemType == 'interruptInstruction') {
      return _TimelineInstructionItem(
        item: item,
        title: title,
        icon: icon,
        body: body,
      );
    }
    if (item.itemType == 'userMessage' ||
        item.itemType == 'agentMessage' ||
        item.itemType == 'threadGoalUpdate') {
      return _TimelineMessageItem(
        item: item,
        title: title,
        body: body,
        rawJson: _rawJson,
        showRaw: showRaw,
      );
    }
    return _TimelineExecutionItem(
      item: item,
      title: title,
      icon: icon,
      body: body,
      rawJson: _rawJson,
      showRaw: showRaw,
    );
  }

  String get _rawJson {
    const encoder = JsonEncoder.withIndent('  ');
    final raw = item.raw.isEmpty
        ? <String, Object?>{
            'id': item.itemId,
            'type': item.itemType,
            if (item.text.isNotEmpty) 'text': item.text,
            if (item.output.isNotEmpty) 'output': item.output,
          }
        : item.raw;
    return encoder.convert(raw);
  }

  String _title(BuildContext context) {
    final l10n = context.l10n;
    return switch (item.itemType) {
      'userMessage' => l10n.timelineUser,
      'agentMessage' => l10n.timelineCodex,
      'queuedInstruction' => l10n.timelineQueuedInstruction,
      'interruptInstruction' => l10n.timelineConversationInterrupted,
      'threadGoalUpdate' => l10n.threadGoalStatus,
      'reasoning' => l10n.timelineReasoning,
      'plan' => l10n.timelinePlan,
      'commandExecution' when item.command != null => item.command!,
      'commandExecution' => l10n.timelineCommand,
      'fileChange' => l10n.timelineFileChanges,
      'mcpToolCall' when item.server != null && item.tool != null =>
        '${item.server}/${item.tool}',
      'mcpToolCall' when item.tool != null => item.tool!,
      'mcpToolCall' ||
      'dynamicToolCall' ||
      'collabAgentToolCall' => l10n.timelineToolCall,
      _ => '${l10n.timelineItem}: ${item.itemType}',
    };
  }

  String _body(BuildContext context) {
    final goal = item.threadGoal;
    if (item.itemType == 'threadGoalUpdate' && goal != null) {
      final l10n = context.l10n;
      return [
        item.text,
        '${l10n.timelineStatus}: ${goal.status}',
        '${l10n.threadGoalTokensUsed}: ${l10n.tokenCount(goal.tokensUsed)}',
        if (goal.tokenBudget != null)
          '${l10n.threadGoalTokenBudget}: ${l10n.tokenCount(goal.tokenBudget!)}',
        '${l10n.threadGoalTimeUsed}: ${l10n.secondCount(goal.timeUsedSeconds)}',
      ].join('\n');
    }
    if (item.output.isNotEmpty) {
      return item.output;
    }
    if (item.text.isNotEmpty) {
      return item.text;
    }
    if (item.itemType == 'interruptInstruction') {
      return '';
    }
    if (item.itemType == 'commandExecution' ||
        item.itemType == 'fileChange' ||
        item.itemType == 'mcpToolCall') {
      return '';
    }
    return item.itemId;
  }

  IconData _iconFor(String itemType) {
    return switch (itemType) {
      'userMessage' => Icons.person_outline,
      'agentMessage' => Icons.smart_toy_outlined,
      'queuedInstruction' => Icons.schedule_send_outlined,
      'interruptInstruction' => Icons.stop_circle_outlined,
      'threadGoalUpdate' => Icons.flag_outlined,
      'commandExecution' => Icons.terminal,
      'fileChange' => Icons.difference_outlined,
      'mcpToolCall' => Icons.extension_outlined,
      'reasoning' => Icons.psychology_outlined,
      'plan' => Icons.checklist,
      _ => Icons.notes_outlined,
    };
  }
}

class _TimelineInstructionItem extends StatelessWidget {
  const _TimelineInstructionItem({
    required this.item,
    required this.title,
    required this.icon,
    required this.body,
  });

  final ChatTimelineItem item;
  final String title;
  final IconData icon;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isInterrupt = item.itemType == 'interruptInstruction';
    final typeKey = isInterrupt
        ? 'interrupt-instruction'
        : 'queued-instruction';
    final accent = isInterrupt ? colorScheme.error : colorScheme.secondary;
    return Container(
      key: ValueKey('timeline-$typeKey-${item.itemId}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              icon,
              key: ValueKey('timeline-$typeKey-icon-${item.itemId}'),
              size: 19,
              color: accent,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  key: ValueKey('timeline-$typeKey-label-${item.itemId}'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _TimelineMarkdownMessage(
                    key: ValueKey('timeline-$typeKey-markdown-${item.itemId}'),
                    text: body,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineMessageItem extends StatelessWidget {
  const _TimelineMessageItem({
    required this.item,
    required this.title,
    required this.body,
    required this.rawJson,
    required this.showRaw,
  });

  final ChatTimelineItem item;
  final String title;
  final String body;
  final String rawJson;
  final bool showRaw;

  static const _maxBubbleWidth = 720.0;
  static const _widthFactor = 0.92;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser =
        item.itemType == 'userMessage' || item.itemType == 'threadGoalUpdate';
    final accent = isUser ? colorScheme.primary : colorScheme.tertiary;
    final bubbleColor = isUser
        ? colorScheme.primaryContainer.withValues(alpha: 0.58)
        : colorScheme.tertiaryContainer.withValues(alpha: 0.52);
    final borderColor = isUser
        ? colorScheme.primary.withValues(alpha: 0.22)
        : colorScheme.tertiary.withValues(alpha: 0.22);
    final alignment = isUser
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxBubbleWidth),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          key: ValueKey('timeline-message-bubble-${item.itemId}'),
          decoration: BoxDecoration(
            color: bubbleColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(8),
              topEnd: const Radius.circular(8),
              bottomStart: Radius.circular(isUser ? 8 : 2),
              bottomEnd: Radius.circular(isUser ? 2 : 8),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _TimelineRoleLabel(
                  label: title,
                  foreground: accent,
                  background: accent.withValues(alpha: 0.10),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  _TimelineMarkdownMessage(
                    key: ValueKey('timeline-message-markdown-${item.itemId}'),
                    text: body,
                  ),
                ],
                if (showRaw) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    rawJson,
                    key: ValueKey('timeline-raw-${item.itemId}'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Align(
        key: ValueKey('timeline-message-align-${item.itemId}'),
        alignment: alignment,
        child: FractionallySizedBox(
          key: ValueKey('timeline-message-width-${item.itemId}'),
          widthFactor: _widthFactor,
          alignment: alignment,
          child: bubble,
        ),
      ),
    );
  }
}

const _markdownMessageRawFallbackChars = 12000;
const _markdownMessageRawFallbackLines = 160;

class _TimelineMarkdownMessage extends StatelessWidget {
  const _TimelineMarkdownMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (_shouldUsePlainMessage(text)) {
      return SelectableText(
        text,
        key: const ValueKey('timeline-message-plain-raw'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.38),
      );
    }
    return WorkspaceMarkdownPreview(content: text);
  }

  bool _shouldUsePlainMessage(String value) {
    if (value.length > _markdownMessageRawFallbackChars) {
      return true;
    }
    return '\n'.allMatches(value).length > _markdownMessageRawFallbackLines;
  }
}

class _TimelineExecutionItem extends StatelessWidget {
  const _TimelineExecutionItem({
    required this.item,
    required this.title,
    required this.icon,
    required this.body,
    required this.rawJson,
    required this.showRaw,
  });

  final ChatTimelineItem item;
  final String title;
  final IconData icon;
  final String body;
  final String rawJson;
  final bool showRaw;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDiffs = item.fileChanges.any(
      (change) => change.diff.trim().isNotEmpty,
    );
    final hasBody = body.isNotEmpty;
    final accent = _timelineExecutionAccent(colorScheme, item.itemType);
    return Container(
      key: ValueKey('timeline-execution-${item.itemId}'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(
              key: ValueKey('timeline-execution-rail-${item.itemId}'),
              color: accent,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _TimelineGlyph(icon: icon, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                if (hasBody) ...[
                  const SizedBox(height: 10),
                  _TimelineBodyBlock(item: item, body: body),
                ],
                if (hasDiffs) ...[
                  const SizedBox(height: 10),
                  for (final change in item.fileChanges)
                    if (change.diff.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TimelineDiffBlock(change: change),
                      ),
                ],
                if (showRaw) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    rawJson,
                    key: ValueKey('timeline-raw-${item.itemId}'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _timelineExecutionAccent(ColorScheme colorScheme, String itemType) {
  return switch (itemType) {
    'commandExecution' => colorScheme.tertiary,
    'fileChange' => colorScheme.secondary,
    'mcpToolCall' ||
    'dynamicToolCall' ||
    'collabAgentToolCall' => colorScheme.primary,
    _ => colorScheme.outline,
  };
}

class _TimelineGlyph extends StatelessWidget {
  const _TimelineGlyph({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }
}

class _TimelineRoleLabel extends StatelessWidget {
  const _TimelineRoleLabel({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TimelineBodyBlock extends StatelessWidget {
  const _TimelineBodyBlock({required this.item, required this.body});

  final ChatTimelineItem item;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (item.itemType == 'commandExecution') {
      return _TerminalOutputSummaryBlock(itemId: item.itemId, text: body);
    }
    if (item.itemType == 'fileChange') {
      return DiffTextBlock(
        key: const ValueKey('timeline-diff-output'),
        text: body,
      );
    }
    return SelectableText(body);
  }
}

const _terminalOutputHeadLines = 4;
const _terminalOutputTailLines = 4;

class _TerminalOutputSummaryBlock extends StatelessWidget {
  const _TerminalOutputSummaryBlock({required this.itemId, required this.text});

  final String itemId;
  final String text;

  @override
  Widget build(BuildContext context) {
    final lines = _terminalLines(text);
    final bytes = utf8.encode(text).length;
    final preview = _terminalOutputPreview(lines, text);
    final colors = SadCoderThemeColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('timeline-command-output-collapsed-$itemId'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.terminalBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.timelineCommandOutputSummary(lines.length, bytes),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.terminalForeground.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (preview.head.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              preview.head,
              key: ValueKey('timeline-command-output-head-$itemId'),
              style: TextStyle(
                color: colors.terminalForeground,
                fontFamily: sadCoderMonospaceFontFamily,
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(
              context.l10n.timelineCommandOutputOmitted,
              key: ValueKey('timeline-command-output-omitted-$itemId'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.terminalForeground.withValues(alpha: 0.62),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (preview.tail.isNotEmpty)
            SelectableText(
              preview.tail,
              key: ValueKey('timeline-command-output-tail-$itemId'),
              style: TextStyle(
                color: colors.terminalForeground,
                fontFamily: sadCoderMonospaceFontFamily,
              ),
            ),
        ],
      ),
    );
  }
}

({String head, String tail}) _terminalOutputPreview(
  List<String> lines,
  String text,
) {
  if (text.isEmpty) {
    return (head: '', tail: '');
  }
  if (lines.length >= 3) {
    final visibleLines = lines.length - 1;
    final headCount = (visibleLines ~/ 2).clamp(1, _terminalOutputHeadLines);
    final tailCount = (visibleLines - headCount).clamp(
      1,
      _terminalOutputTailLines,
    );
    return (
      head: lines.take(headCount).join('\n').trimRight(),
      tail: lines.skip(lines.length - tailCount).join('\n').trimRight(),
    );
  }

  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalized.length == 1) {
    return (head: '', tail: '');
  }
  final visibleChars = normalized.length - 1;
  final headChars = (visibleChars / 2).ceil();
  final tailChars = visibleChars - headChars;
  return (
    head: normalized.substring(0, headChars),
    tail: tailChars == 0
        ? ''
        : normalized.substring(normalized.length - tailChars),
  );
}

List<String> _terminalLines(String text) {
  if (text.isEmpty) {
    return const [];
  }
  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
}

class _TimelineDiffBlock extends StatelessWidget {
  const _TimelineDiffBlock({required this.change});

  final ThreadFileChangeSummary change;

  @override
  Widget build(BuildContext context) {
    final label = change.path.isEmpty
        ? change.kind
        : '${change.kind} ${change.path}';
    return DiffTextBlock(
      key: ValueKey('timeline-diff-output-$label'),
      text: change.diff,
      label: label,
    );
  }
}
