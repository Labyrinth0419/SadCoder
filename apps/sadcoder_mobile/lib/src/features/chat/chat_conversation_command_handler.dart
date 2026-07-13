import 'dart:async';

import 'package:flutter/material.dart';

import '../../commands/slash_command_action_dispatcher.dart';
import '../../i18n/app_localizations.dart';
import '../../session/codex_session_state_controller.dart';
import '../../threads/agent_thread_topology.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_list_controller.dart';
import '../../threads/thread_summary.dart';
import '../../turns/turn_controller.dart';
import 'chat_agent_topology_sheet.dart';
import 'chat_side_conversation_panel.dart';
import 'chat_timeline_controller.dart';

typedef ChatConversationThreadIdProvider = String? Function();
typedef ChatSideConversationProvider = ChatSideConversation? Function();
typedef ChatSideConversationSetter =
    void Function(ChatSideConversation conversation);
typedef ChatConversationRefresher = void Function({int limit});
typedef ChatActiveTurnTimelineSync = void Function({String? submittedText});
typedef ChatConversationSnackBar = void Function(String message);

class ChatConversationCommandHandler {
  const ChatConversationCommandHandler({
    required this.context,
    required this.mounted,
    required this.sessionController,
    required this.threadListController,
    required this.threadDetailController,
    required this.turnController,
    required this.timelineController,
    required this.currentThreadIdProvider,
    required this.sideConversationProvider,
    required this.setSideConversation,
    required this.clearSideConversation,
    required this.refreshVisibleThreads,
    required this.syncActiveTurnToTimeline,
    required this.showSnackBar,
  });

  final BuildContext context;
  final bool Function() mounted;
  final CodexSessionStateController? sessionController;
  final ThreadListController? threadListController;
  final ThreadDetailController? threadDetailController;
  final TurnController? turnController;
  final ChatTimelineController? timelineController;
  final ChatConversationThreadIdProvider currentThreadIdProvider;
  final ChatSideConversationProvider sideConversationProvider;
  final ChatSideConversationSetter setSideConversation;
  final VoidCallback clearSideConversation;
  final ChatConversationRefresher refreshVisibleThreads;
  final ChatActiveTurnTimelineSync syncActiveTurnToTimeline;
  final ChatConversationSnackBar showSnackBar;

  Future<SlashCommandCallbackResult> startSideConversation(
    String arguments, {
    required bool btw,
  }) async {
    final runner = sessionController?.threadMutationRunner;
    final controller = turnController;
    final parentThreadId = currentThreadIdProvider();
    if (runner == null || controller == null || parentThreadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    if (!controller.canSubmit || sideConversationProvider() != null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final sideThread = await runner.startSideConversation(
      threadId: parentThreadId,
    );
    if (!mounted()) {
      return SlashCommandCallbackResult.cancelled;
    }
    if (sideThread.id.trim().isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }
    final activated = controller.activateThread(sideThread.id);
    if (!activated) {
      return SlashCommandCallbackResult.unavailable;
    }

    setSideConversation(
      ChatSideConversation(
        parentThreadId: parentThreadId,
        sideThreadId: sideThread.id,
        slash: btw ? '/btw' : '/side',
      ),
    );
    timelineController?.showThread(sideThread);
    unawaited(
      threadDetailController?.readThread(sideThread.id, includeTurns: false),
    );
    refreshVisibleThreads();

    final initialPrompt = arguments.trim();
    if (initialPrompt.isNotEmpty) {
      await controller.submitText(initialPrompt);
      if (controller.status != TurnControllerStatus.failed) {
        syncActiveTurnToTimeline(submittedText: initialPrompt);
      }
    }
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> showAgentTopology({
    required bool subagentsOnly,
  }) async {
    final listController = threadListController;
    final controller = turnController;
    if (listController == null || controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    await listController.refresh(limit: 100);
    if (!mounted() || !context.mounted) {
      return SlashCommandCallbackResult.cancelled;
    }
    final activeThreadDetail = await _readActiveThreadForAgentTopology();
    if (!mounted() || !context.mounted) {
      return SlashCommandCallbackResult.cancelled;
    }
    final topology = AgentThreadTopology.fromThreads(
      _agentTopologyThreads(listController.threads, activeThreadDetail),
    );
    final entries = subagentsOnly ? topology.subagentEntries : topology.entries;
    if (entries.isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }

    final selectedThread = await showModalBottomSheet<ThreadSummary>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChatAgentTopologySheet(
        entries: entries,
        subagentsOnly: subagentsOnly,
        activeThreadId: currentThreadIdProvider(),
      ),
    );
    if (!mounted() || selectedThread == null) {
      return SlashCommandCallbackResult.cancelled;
    }
    if (!controller.canSubmit) {
      return SlashCommandCallbackResult.unavailable;
    }
    final activated = controller.activateThread(selectedThread.id);
    if (!activated) {
      return SlashCommandCallbackResult.unavailable;
    }

    clearSideConversation();
    timelineController?.selectThread(selectedThread.id);
    unawaited(
      threadDetailController?.readThread(
        selectedThread.id,
        includeTurns: false,
      ),
    );
    return SlashCommandCallbackResult.executed;
  }

  Future<void> returnToMainThread() async {
    final sideConversation = sideConversationProvider();
    final controller = turnController;
    if (sideConversation == null ||
        controller == null ||
        !controller.canSubmit) {
      return;
    }
    final activated = controller.activateThread(
      sideConversation.parentThreadId,
    );
    if (!activated) {
      return;
    }
    clearSideConversation();
    timelineController?.selectThread(sideConversation.parentThreadId);
    unawaited(
      threadDetailController?.readThread(
        sideConversation.parentThreadId,
        includeTurns: false,
      ),
    );
    if (!mounted()) {
      return;
    }
    showSnackBar(context.l10n.slashCommandReturnedToMainThread);
  }

  Future<ThreadSummary?> _readActiveThreadForAgentTopology() async {
    final threadId = currentThreadIdProvider();
    if (threadId == null) {
      return null;
    }
    final cachedThread = threadDetailController?.detail?.thread;
    if (cachedThread?.id == threadId && cachedThread!.turns.isNotEmpty) {
      return cachedThread;
    }
    final reader = sessionController?.threadDetailReader;
    if (reader == null) {
      return cachedThread?.id == threadId ? cachedThread : null;
    }
    try {
      final detail = await reader.readThread(threadId: threadId);
      if (detail.thread.id == threadId) {
        return detail.thread;
      }
      return cachedThread?.id == threadId ? cachedThread : null;
    } on Object {
      return cachedThread?.id == threadId ? cachedThread : null;
    }
  }

  List<ThreadSummary> _agentTopologyThreads(
    List<ThreadSummary> threads,
    ThreadSummary? detailThread,
  ) {
    if (detailThread == null || detailThread.id.trim().isEmpty) {
      return threads;
    }
    final merged = List<ThreadSummary>.from(threads);
    final index = merged.indexWhere((thread) => thread.id == detailThread.id);
    if (index == -1) {
      merged.add(detailThread);
    } else {
      merged[index] = detailThread;
    }
    return merged;
  }
}
