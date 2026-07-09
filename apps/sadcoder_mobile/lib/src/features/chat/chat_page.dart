import 'dart:async';

import 'package:flutter/material.dart';

import '../../commands/slash_command_registry.dart';
import '../../i18n/app_localizations.dart';
import '../../session/codex_session_state_controller.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_list_controller.dart';
import '../../threads/thread_summary.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.registry = const SlashCommandRegistry(),
    this.sessionController,
    this.threadListController,
    this.threadDetailController,
  });

  final SlashCommandRegistry registry;
  final CodexSessionStateController? sessionController;
  final ThreadListController? threadListController;
  final ThreadDetailController? threadDetailController;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  SlashCommandParseResult _slashCommand =
      const SlashCommandParseResult.notSlash();
  CodexSessionStatus? _lastSessionStatus;

  @override
  void initState() {
    super.initState();
    widget.sessionController?.addListener(_handleSessionChanged);
    _lastSessionStatus = widget.sessionController?.status;
    _refreshThreadsIfConnected();
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionController != widget.sessionController) {
      oldWidget.sessionController?.removeListener(_handleSessionChanged);
      widget.sessionController?.addListener(_handleSessionChanged);
      _lastSessionStatus = widget.sessionController?.status;
      _refreshThreadsIfConnected();
    }
  }

  @override
  void dispose() {
    widget.sessionController?.removeListener(_handleSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sessionController = widget.sessionController;
    final threadListController = widget.threadListController;
    final threadDetailController = widget.threadDetailController;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.chat,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              _StateChip(
                label: _connectionLabel(l10n, sessionController?.status),
                connected:
                    sessionController?.status == CodexSessionStatus.connected,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MessageBlock(
                title: l10n.m0ProtocolClient,
                body: l10n.m0ProtocolClientBody,
              ),
              _MessageBlock(
                title: l10n.slashCommandSurface,
                body: l10n.slashCommandSurfaceBody,
              ),
              _ThreadListPanel(
                controller: threadListController,
                detailController: threadDetailController,
              ),
              _ThreadDetailPanel(controller: threadDetailController),
              _SlashCommandPreview(result: _slashCommand),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const ValueKey('chat-composer-field'),
              onChanged: _handleComposerChanged,
              decoration: InputDecoration(
                hintText: l10n.connectBeforeTurn,
                prefixIcon: const Icon(Icons.code),
                suffixIcon: IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.send),
                  tooltip: l10n.send,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleComposerChanged(String value) {
    setState(() => _slashCommand = widget.registry.parseComposerText(value));
  }

  void _handleSessionChanged() {
    final status = widget.sessionController?.status;
    if (_lastSessionStatus != CodexSessionStatus.connected &&
        status == CodexSessionStatus.connected) {
      unawaited(widget.threadListController?.refresh());
    }
    _lastSessionStatus = status;
    if (mounted) {
      setState(() {});
    }
  }

  void _refreshThreadsIfConnected() {
    if (widget.sessionController?.status == CodexSessionStatus.connected) {
      unawaited(widget.threadListController?.refresh());
    }
  }

  String _connectionLabel(AppLocalizations l10n, CodexSessionStatus? status) {
    return switch (status) {
      CodexSessionStatus.connected => l10n.connected,
      CodexSessionStatus.connecting => l10n.connecting,
      CodexSessionStatus.reconnecting => l10n.reconnecting,
      CodexSessionStatus.disconnecting => l10n.disconnecting,
      CodexSessionStatus.failed => l10n.connectionFailed,
      CodexSessionStatus.idle || null => l10n.disconnected,
    };
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.connected});

  final String label;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(connected ? Icons.link : Icons.link_off, size: 18),
      label: Text(label),
    );
  }
}

class _ThreadListPanel extends StatelessWidget {
  const _ThreadListPanel({
    required this.controller,
    required this.detailController,
  });

  final ThreadListController? controller;
  final ThreadDetailController? detailController;

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
      ),
    );
  }
}

class _ThreadListContent extends StatelessWidget {
  const _ThreadListContent({
    required this.controller,
    required this.detailController,
  });

  final ThreadListController controller;
  final ThreadDetailController? detailController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = l10n.sessions;
    return switch (controller.status) {
      ThreadListStatus.idle => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(controller: controller),
        child: Text(l10n.connectBeforeLoadingThreads),
      ),
      ThreadListStatus.loading => _ThreadListCard(
        title: title,
        child: const LinearProgressIndicator(),
      ),
      ThreadListStatus.failed => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(controller: controller),
        child: Text(
          controller.error?.toString() ?? l10n.threadListFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      ThreadListStatus.loaded when controller.threads.isEmpty =>
        _ThreadListCard(
          title: title,
          action: _RefreshThreadsButton(controller: controller),
          child: Text(l10n.noThreads),
        ),
      ThreadListStatus.loaded => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(controller: controller),
        child: Column(
          children: [
            for (final thread in controller.threads)
              _ThreadListTile(
                thread: thread,
                detailController: detailController,
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
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _RefreshThreadsButton extends StatelessWidget {
  const _RefreshThreadsButton({required this.controller});

  final ThreadListController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.refreshThreads,
      onPressed: () => controller.refresh(),
      icon: const Icon(Icons.refresh),
    );
  }
}

class _ThreadListTile extends StatelessWidget {
  const _ThreadListTile({required this.thread, required this.detailController});

  final ThreadSummary thread;
  final ThreadDetailController? detailController;

  @override
  Widget build(BuildContext context) {
    final badges = <String>[
      thread.status,
      if (thread.isFork) context.l10n.forkedThread,
      if (thread.isSubagent) context.l10n.subagentThread,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.forum_outlined),
      title: Text(thread.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          thread.cwd,
          badges.join(' / '),
        ].where((value) => value.isNotEmpty).join('\n'),
      ),
      isThreeLine: thread.cwd.isNotEmpty && badges.isNotEmpty,
      onTap: detailController == null
          ? null
          : () => detailController!.readThread(thread.id),
    );
  }
}

class _ThreadDetailPanel extends StatelessWidget {
  const _ThreadDetailPanel({required this.controller});

  final ThreadDetailController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _ThreadDetailContent(controller: controller),
    );
  }
}

class _ThreadDetailContent extends StatelessWidget {
  const _ThreadDetailContent({required this.controller});

  final ThreadDetailController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (controller.status) {
      ThreadDetailStatus.idle => const SizedBox.shrink(),
      ThreadDetailStatus.loading => _ThreadDetailCard(
        title: l10n.threadDetail,
        child: const LinearProgressIndicator(),
      ),
      ThreadDetailStatus.failed => _ThreadDetailCard(
        title: l10n.threadDetail,
        child: Text(
          controller.error?.toString() ?? l10n.threadDetailFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      ThreadDetailStatus.loaded => _LoadedThreadDetail(
        detail: controller.detail!,
      ),
    };
  }
}

class _LoadedThreadDetail extends StatelessWidget {
  const _LoadedThreadDetail({required this.detail});

  final ThreadDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thread = detail.thread;
    return _ThreadDetailCard(
      title: l10n.threadDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(thread.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('${l10n.approvalThread}: ${thread.id}'),
          if (thread.cwd.isNotEmpty)
            Text('${l10n.approvalWorkingDirectory}: ${thread.cwd}'),
          Text(l10n.turnCount(thread.turns.length)),
          const SizedBox(height: 8),
          if (thread.turns.isEmpty)
            Text(l10n.noTurns)
          else
            for (final turn in thread.turns) _TurnSummaryTile(turn: turn),
        ],
      ),
    );
  }
}

class _ThreadDetailCard extends StatelessWidget {
  const _ThreadDetailCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _TurnSummaryTile extends StatelessWidget {
  const _TurnSummaryTile({required this.turn});

  final TurnSummary turn;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.notes_outlined),
      title: Text('${context.l10n.approvalTurn}: ${turn.id}'),
      subtitle: Text(
        '${turn.status} / ${turn.itemCount} items / ${turn.itemsView}',
      ),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}

class _SlashCommandPreview extends StatelessWidget {
  const _SlashCommandPreview({required this.result});

  final SlashCommandParseResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
        subtitle: l10n.slashCommandNotSentAsPrompt,
      ),
      SlashCommandParseKind.known => _PreviewCard(
        icon: Icons.terminal,
        title: result.command!.slash,
        subtitle: result.command!.description,
      ),
    };
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
