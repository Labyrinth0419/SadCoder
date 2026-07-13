import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../session/codex_session_state_controller.dart';
import '../../theme/sadcoder_theme.dart';
import '../../turns/turn_controller.dart';
import 'chat_status_summary.dart';
import 'chat_timeline_controller.dart';

class ChatActivityStrip extends StatelessWidget {
  const ChatActivityStrip({
    super.key,
    required this.sidebarVisible,
    required this.onToggleSidebar,
    required this.sessionController,
    required this.turnController,
    required this.timelineController,
    required this.statusLineParts,
    required this.connectionControls,
  });

  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;
  final CodexSessionStateController? sessionController;
  final TurnController? turnController;
  final ChatTimelineController? timelineController;
  final List<String> statusLineParts;
  final Widget connectionControls;

  @override
  Widget build(BuildContext context) {
    final timelineController = this.timelineController;
    if (timelineController == null) {
      return _buildBody();
    }
    return AnimatedBuilder(
      animation: timelineController,
      builder: (context, _) => _buildBody(),
    );
  }

  Widget _buildBody() {
    return _ChatActivityStripBody(
      sidebarVisible: sidebarVisible,
      onToggleSidebar: onToggleSidebar,
      sessionController: sessionController,
      turnController: turnController,
      timelineController: timelineController,
      statusLineParts: statusLineParts,
      connectionControls: connectionControls,
    );
  }
}

class _ChatActivityStripBody extends StatelessWidget {
  const _ChatActivityStripBody({
    required this.sidebarVisible,
    required this.onToggleSidebar,
    required this.sessionController,
    required this.turnController,
    required this.timelineController,
    required this.statusLineParts,
    required this.connectionControls,
  });

  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;
  final CodexSessionStateController? sessionController;
  final TurnController? turnController;
  final ChatTimelineController? timelineController;
  final List<String> statusLineParts;
  final Widget connectionControls;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final turn = turnController;
    final failed = turn?.status == TurnControllerStatus.failed;
    final busy = turn?.isBusy == true;
    final running = turn?.activeTurnId?.trim().isNotEmpty == true;
    final indicator = failed
        ? colorScheme.error
        : busy
        ? colorScheme.tertiary
        : running
        ? colorScheme.primary
        : colorScheme.outline;
    final status = _chatActivityStateLabel(
      l10n,
      turn,
      sessionController?.status,
    );
    final hostState = sessionStatusLabel(l10n, sessionController?.status);
    final turnStatus = turn == null
        ? null
        : _chatActivityTurnStatusLabel(l10n, turn);
    final activityDetail = _timelineActivityDetail(l10n, timelineController);
    final details = [
      if (turnStatus != null && turnStatus != status) turnStatus,
      ?activityDetail,
      if (hostState != status && hostState != turnStatus) hostState,
    ];

    final active = busy || running;
    return Material(
      color: active
          ? Color.alphaBlend(
              indicator.withValues(alpha: 0.08),
              colorScheme.surfaceContainerLowest,
            )
          : colorScheme.surfaceContainerLow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active
                  ? indicator.withValues(alpha: 0.48)
                  : colorScheme.outlineVariant,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: (active ? indicator : colorScheme.shadow).withValues(
                alpha: active ? 0.12 : 0.04,
              ),
              blurRadius: active ? 16 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                PositionedDirectional(
                  key: const ValueKey('chat-activity-rail'),
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: ColoredBox(
                    color: active
                        ? indicator
                        : indicator.withValues(alpha: 0.38),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 8, 5),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('chat-session-sidebar-toggle'),
                        tooltip: l10n.sessions,
                        onPressed: onToggleSidebar,
                        style: IconButton.styleFrom(
                          backgroundColor: sidebarVisible
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          foregroundColor: sidebarVisible
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size.square(36),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.menu),
                      ),
                      const SizedBox(width: 5),
                      _ChatTuiStatusMark(
                        key: const ValueKey('chat-tui-status-mark'),
                        color: indicator,
                        active: active,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ChatTuiStatusLine(
                          status: status,
                          details: details,
                          statusLineParts: statusLineParts,
                          color: indicator,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: connectionControls,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (active)
              DecoratedBox(
                key: const ValueKey('chat-running-progress'),
                decoration: BoxDecoration(
                  color: indicator.withValues(alpha: 0.14),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: busy ? 0.42 : 1,
                    child: ColoredBox(
                      color: indicator,
                      child: const SizedBox(height: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatTuiStatusLine extends StatelessWidget {
  const _ChatTuiStatusLine({
    required this.status,
    required this.details,
    required this.statusLineParts,
    required this.color,
  });

  final String status;
  final List<String> details;
  final List<String> statusLineParts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color.withValues(alpha: 0.42)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  child: Text(
                    status,
                    key: const ValueKey('chat-activity-status'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontFamily: sadCoderMonospaceFontFamily,
                    ),
                  ),
                ),
              ),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.72,
                    ),
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    child: Text(
                      details.join('  |  '),
                      key: const ValueKey('chat-activity-detail'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: sadCoderMonospaceFontFamily,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (statusLineParts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            key: const ValueKey('chat-status-line'),
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final part in statusLineParts)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      part,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChatTuiStatusMark extends StatelessWidget {
  const _ChatTuiStatusMark({
    super.key,
    required this.color,
    required this.active,
  });

  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.20 : 0.08),
        border: Border.all(
          color: color.withValues(alpha: active ? 0.72 : 0.45),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Container(
        width: active ? 8 : 6,
        height: active ? 8 : 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

String? _timelineActivityDetail(
  AppLocalizations l10n,
  ChatTimelineController? controller,
) {
  final turns = controller?.turns;
  if (turns == null || turns.isEmpty) {
    return null;
  }
  ChatTimelineTurn? activeTurn;
  for (final turn in turns.reversed) {
    if (!_isTerminalTurnStatus(turn.status)) {
      activeTurn = turn;
      break;
    }
  }
  if (activeTurn == null) {
    return null;
  }
  for (final item in activeTurn.items.reversed) {
    final title = _timelineActivityItemTitle(l10n, item);
    if (title != null) {
      return title;
    }
  }
  return null;
}

String? _timelineActivityItemTitle(
  AppLocalizations l10n,
  ChatTimelineItem item,
) {
  return switch (item.itemType) {
    'commandExecution' when item.command != null =>
      '${l10n.timelineCommand}: ${item.command}',
    'commandExecution' => l10n.timelineCommand,
    'fileChange' when item.fileChanges.isNotEmpty =>
      '${l10n.timelineFileChanges}: ${item.fileChanges.length}',
    'fileChange' => l10n.timelineFileChanges,
    'mcpToolCall' when item.server != null && item.tool != null =>
      '${l10n.timelineTool}: ${item.server}/${item.tool}',
    'mcpToolCall' when item.tool != null =>
      '${l10n.timelineTool}: ${item.tool}',
    'mcpToolCall' ||
    'dynamicToolCall' ||
    'collabAgentToolCall' => l10n.timelineToolCall,
    'reasoning' => l10n.timelineReasoning,
    'plan' => l10n.timelinePlan,
    _ => null,
  };
}

String _chatActivityStateLabel(
  AppLocalizations l10n,
  TurnController? controller,
  CodexSessionStatus? sessionStatus,
) {
  if (controller == null) {
    return sessionStatusLabel(l10n, sessionStatus);
  }
  if (controller.status == TurnControllerStatus.failed) {
    return l10n.statusFailed;
  }
  if (controller.isBusy) {
    return l10n.statusWorking;
  }
  if (controller.activeTurnId?.trim().isNotEmpty == true) {
    return l10n.statusRunning;
  }
  return sessionStatusLabel(l10n, sessionStatus);
}

String _chatActivityTurnStatusLabel(
  AppLocalizations l10n,
  TurnController controller,
) {
  return switch (controller.status) {
    TurnControllerStatus.idle => l10n.statusIdle,
    TurnControllerStatus.startingThread => l10n.startingThread,
    TurnControllerStatus.resumingThread => l10n.resumingThread,
    TurnControllerStatus.sendingTurn => l10n.sendingTurn,
    TurnControllerStatus.submitted => l10n.sendingTurn,
    TurnControllerStatus.completed => l10n.turnCompleted,
    TurnControllerStatus.interrupting => l10n.interruptingTurn,
    TurnControllerStatus.interrupted => l10n.turnInterrupted,
    TurnControllerStatus.failed => turnControllerErrorMessage(
      l10n,
      controller.error,
    ),
  };
}

bool _isTerminalTurnStatus(String status) {
  return status == 'completed' || status == 'failed' || status == 'interrupted';
}
