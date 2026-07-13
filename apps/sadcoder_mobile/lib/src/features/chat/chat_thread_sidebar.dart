import 'dart:async';

import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_list_controller.dart';
import '../../threads/thread_summary.dart';

class ChatThreadSidebar extends StatelessWidget {
  const ChatThreadSidebar({
    super.key,
    required this.overlay,
    required this.child,
  });

  final bool overlay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: overlay ? 8 : 0,
      color: colorScheme.surfaceContainerLowest,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            end: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: ListView(
          key: const ValueKey('chat-session-sidebar'),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          children: [child],
        ),
      ),
    );
  }
}

class ChatSidebarWorkspaceHeader extends StatelessWidget {
  const ChatSidebarWorkspaceHeader({
    super.key,
    required this.workspace,
    required this.onOpenAdvanced,
  });

  final String workspace;
  final VoidCallback? onOpenAdvanced;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      key: const ValueKey('chat-sidebar-workspace-header'),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                Icons.folder_copy_outlined,
                size: 17,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.workspaceFilesRootLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    workspace,
                    key: const ValueKey('chat-sidebar-workspace-summary'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              key: const ValueKey('chat-sidebar-advanced-controls'),
              onPressed: onOpenAdvanced,
              tooltip: l10n.showChatAdvancedControls,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: const Icon(Icons.tune, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatThreadListPanel extends StatelessWidget {
  const ChatThreadListPanel({
    super.key,
    required this.controller,
    required this.detailController,
    required this.archived,
    required this.onArchivedChanged,
    required this.onUnarchiveThread,
  });

  final ThreadListController? controller;
  final ThreadDetailController? detailController;
  final bool archived;
  final ValueChanged<bool> onArchivedChanged;
  final Future<void> Function(ThreadSummary thread)? onUnarchiveThread;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return _ThreadListCard(
        title: context.l10n.sessions,
        child: Text(context.l10n.connectBeforeLoadingThreads),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _ThreadListContent(
        controller: controller,
        detailController: detailController,
        archived: archived,
        onArchivedChanged: onArchivedChanged,
        onUnarchiveThread: onUnarchiveThread,
      ),
    );
  }
}

class _ThreadListContent extends StatelessWidget {
  const _ThreadListContent({
    required this.controller,
    required this.detailController,
    required this.archived,
    required this.onArchivedChanged,
    required this.onUnarchiveThread,
  });

  final ThreadListController controller;
  final ThreadDetailController? detailController;
  final bool archived;
  final ValueChanged<bool> onArchivedChanged;
  final Future<void> Function(ThreadSummary thread)? onUnarchiveThread;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = l10n.sessions;
    return switch (controller.status) {
      ThreadListStatus.idle => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(
          controller: controller,
          archived: archived,
        ),
        modeControl: _ThreadListModeSelector(
          archived: archived,
          onChanged: onArchivedChanged,
        ),
        child: Text(l10n.connectBeforeLoadingThreads),
      ),
      ThreadListStatus.loading => _ThreadListCard(
        title: title,
        modeControl: _ThreadListModeSelector(
          archived: archived,
          onChanged: onArchivedChanged,
        ),
        child: const LinearProgressIndicator(),
      ),
      ThreadListStatus.failed => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(
          controller: controller,
          archived: archived,
        ),
        modeControl: _ThreadListModeSelector(
          archived: archived,
          onChanged: onArchivedChanged,
        ),
        child: Text(
          controller.error?.toString() ?? l10n.threadListFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      ThreadListStatus.loaded when controller.threads.isEmpty =>
        _ThreadListCard(
          title: title,
          action: _RefreshThreadsButton(
            controller: controller,
            archived: archived,
          ),
          modeControl: _ThreadListModeSelector(
            archived: archived,
            onChanged: onArchivedChanged,
          ),
          child: Text(archived ? l10n.noArchivedThreads : l10n.noThreads),
        ),
      ThreadListStatus.loaded => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(
          controller: controller,
          archived: archived,
        ),
        modeControl: _ThreadListModeSelector(
          archived: archived,
          onChanged: onArchivedChanged,
        ),
        child: Column(
          children: [
            for (final thread in controller.threads)
              _ThreadListTile(
                thread: thread,
                detailController: detailController,
                archived: archived,
                onUnarchiveThread: onUnarchiveThread,
              ),
          ],
        ),
      ),
    };
  }
}

class _ThreadListCard extends StatelessWidget {
  const _ThreadListCard({
    required this.title,
    required this.child,
    this.action,
    this.modeControl,
  });

  final String title;
  final Widget child;
  final Widget? action;
  final Widget? modeControl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 0, 4),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const SizedBox(width: 4, height: 20),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.forum_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ),
        if (modeControl != null) ...[const SizedBox(height: 4), modeControl!],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, color: colorScheme.outlineVariant),
        ),
        child,
      ],
    );
  }
}

class _RefreshThreadsButton extends StatelessWidget {
  const _RefreshThreadsButton({
    required this.controller,
    required this.archived,
  });

  final ThreadListController controller;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.refreshThreads,
      onPressed: () => controller.refresh(archived: archived),
      icon: const Icon(Icons.refresh),
    );
  }
}

class _ThreadListModeSelector extends StatelessWidget {
  const _ThreadListModeSelector({
    required this.archived,
    required this.onChanged,
  });

  final bool archived;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThreadListModeButton(
              key: const ValueKey('chat-thread-mode-active'),
              selected: !archived,
              icon: Icons.forum_outlined,
              label: l10n.activeThreads,
              onPressed: () => onChanged(false),
            ),
            const SizedBox(height: 4),
            _ThreadListModeButton(
              key: const ValueKey('chat-thread-mode-archived'),
              selected: archived,
              icon: Icons.archive_outlined,
              label: l10n.archivedThreads,
              onPressed: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadListModeButton extends StatelessWidget {
  const _ThreadListModeButton({
    super.key,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return Tooltip(
      message: label,
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.68)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: Stack(
            children: [
              PositionedDirectional(
                start: 0,
                top: 5,
                bottom: 5,
                width: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 8, 7),
                child: Row(
                  children: [
                    Icon(icon, size: 17, color: foreground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check, size: 16, color: colorScheme.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadListTile extends StatelessWidget {
  const _ThreadListTile({
    required this.thread,
    required this.detailController,
    required this.archived,
    required this.onUnarchiveThread,
  });

  final ThreadSummary thread;
  final ThreadDetailController? detailController;
  final bool archived;
  final Future<void> Function(ThreadSummary thread)? onUnarchiveThread;

  @override
  Widget build(BuildContext context) {
    final selected = detailController?.selectedThreadId == thread.id;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    return Material(
      key: ValueKey('thread-summary-${thread.id}'),
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.52)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: detailController == null
            ? null
            : () =>
                  detailController!.readThread(thread.id, includeTurns: false),
        child: Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 5,
              bottom: 5,
              width: 3,
              child: DecoratedBox(
                key: ValueKey('thread-summary-rail-${thread.id}'),
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 2, 5),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primary.withValues(alpha: 0.14)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      selected ? Icons.chat_bubble : Icons.chat_bubble_outline,
                      size: 16,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      thread.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (archived)
                    SizedBox.square(
                      dimension: 30,
                      child: IconButton(
                        tooltip: context.l10n.unarchiveThread,
                        onPressed: onUnarchiveThread == null
                            ? null
                            : () => unawaited(onUnarchiveThread!(thread)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.unarchive_outlined, size: 17),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
