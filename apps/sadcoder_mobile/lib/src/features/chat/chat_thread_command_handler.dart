import 'dart:async';

import 'package:flutter/material.dart';

import '../../commands/slash_command_action_dispatcher.dart';
import '../../i18n/app_localizations.dart';
import '../../session/codex_session_state_controller.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_mutation_runner.dart';
import '../../threads/thread_summary.dart';
import '../../turns/turn_controller.dart';
import 'chat_timeline_controller.dart';

class ChatThreadCommandHandler {
  const ChatThreadCommandHandler({
    required this.context,
    required this.mounted,
    required this.sessionController,
    required this.threadDetailController,
    required this.turnController,
    required this.timelineController,
    required this.clearSideConversation,
    required this.clearLocalTranscript,
    required this.refreshVisibleThreads,
    required this.showSnackBar,
  });

  final BuildContext context;
  final bool Function() mounted;
  final CodexSessionStateController? sessionController;
  final ThreadDetailController? threadDetailController;
  final TurnController? turnController;
  final ChatTimelineController? timelineController;
  final VoidCallback clearSideConversation;
  final VoidCallback clearLocalTranscript;
  final VoidCallback refreshVisibleThreads;
  final ValueChanged<String> showSnackBar;

  Future<bool> startNewThread() async {
    final turnController = this.turnController;
    if (turnController == null) {
      return false;
    }
    final started = await turnController.startNewThread();
    if (!started) {
      return false;
    }
    clearSideConversation();
    threadDetailController?.clear();
    timelineController?.selectThread(turnController.activeThreadId);
    refreshVisibleThreads();
    return true;
  }

  Future<bool> resumeThread(String threadId) async {
    final turnController = this.turnController;
    if (turnController == null) {
      return false;
    }
    final resumed = await turnController.resumeThread(threadId);
    if (!resumed) {
      return false;
    }
    final activeThreadId = turnController.activeThreadId;
    if (activeThreadId == null || activeThreadId.isEmpty) {
      return false;
    }
    clearSideConversation();
    timelineController?.selectThread(activeThreadId);
    unawaited(
      threadDetailController?.readThread(activeThreadId, includeTurns: false),
    );
    refreshVisibleThreads();
    return true;
  }

  Future<bool> renameThread(String name) async {
    final runner = sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return false;
    }
    await runner.setThreadName(threadId: threadId, name: name);
    refreshVisibleThreads();
    if (threadDetailController?.selectedThreadId == threadId) {
      unawaited(
        threadDetailController?.readThread(threadId, includeTurns: false),
      );
    }
    return true;
  }

  Future<SlashCommandCallbackResult> forkCurrentThread() async {
    final runner = sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    final turnController = this.turnController;
    if (runner == null || threadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    if (turnController != null && !turnController.canSubmit) {
      return SlashCommandCallbackResult.unavailable;
    }
    final forked = await runner.forkThread(threadId: threadId);
    return _activateForkedThread(forked);
  }

  Future<SlashCommandCallbackResult> duplicateCurrentThread() async {
    final runner = sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    final turnController = this.turnController;
    if (runner == null || threadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    if (turnController != null && !turnController.canSubmit) {
      return SlashCommandCallbackResult.unavailable;
    }
    final duplicated = await runner.duplicateThread(threadId: threadId);
    return _activateForkedThread(duplicated);
  }

  Future<SlashCommandCallbackResult> rewindCurrentThread(
    String lastTurnId,
  ) async {
    final runner = sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    final checkpoint = lastTurnId.trim();
    final turnController = this.turnController;
    if (runner == null || threadId == null || checkpoint.isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }
    if (turnController != null && !turnController.canSubmit) {
      return SlashCommandCallbackResult.unavailable;
    }
    final rewound = await runner.rewindThread(
      threadId: threadId,
      lastTurnId: checkpoint,
    );
    return _activateForkedThread(rewound);
  }

  Future<SlashCommandCallbackResult> compactCurrentThread() async {
    final runner = sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    await runner.compactThread(threadId: threadId);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> archiveCurrentThread() {
    final l10n = context.l10n;
    return _confirmThreadMutation(
      title: l10n.archiveThreadTitle,
      body: l10n.archiveThreadBody,
      confirmLabel: l10n.archiveThreadConfirm,
      mutate: (runner, threadId) => runner.archiveThread(threadId: threadId),
    );
  }

  Future<SlashCommandCallbackResult> deleteCurrentThread() {
    final l10n = context.l10n;
    return _confirmThreadMutation(
      title: l10n.deleteThreadTitle,
      body: l10n.deleteThreadBody,
      confirmLabel: l10n.deleteThreadConfirm,
      mutate: (runner, threadId) => runner.deleteThread(threadId: threadId),
    );
  }

  Future<void> unarchiveThread(ThreadSummary thread) async {
    final runner = sessionController?.threadMutationRunner;
    if (runner == null) {
      return;
    }
    final successMessage = context.l10n.threadUnarchived;
    await runner.unarchiveThread(threadId: thread.id);
    refreshVisibleThreads();
    if (!mounted()) {
      return;
    }
    showSnackBar(successMessage);
  }

  SlashCommandCallbackResult _activateForkedThread(ThreadSummary thread) {
    if (thread.id.trim().isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }
    final activated = turnController?.activateThread(thread.id) ?? true;
    if (!activated) {
      return SlashCommandCallbackResult.unavailable;
    }
    clearSideConversation();
    timelineController?.showThread(thread);
    unawaited(
      threadDetailController?.readThread(thread.id, includeTurns: false),
    );
    refreshVisibleThreads();
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _confirmThreadMutation({
    required String title,
    required String body,
    required String confirmLabel,
    required Future<void> Function(ThreadMutationRunner runner, String threadId)
    mutate,
  }) async {
    final runner = sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    final cancelLabel = context.l10n.approvalCancel;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (!mounted() || confirmed != true) {
      return SlashCommandCallbackResult.cancelled;
    }
    await mutate(runner, threadId);
    clearLocalTranscript();
    refreshVisibleThreads();
    return SlashCommandCallbackResult.executed;
  }

  String? _currentThreadId() {
    final selectedThreadId = threadDetailController?.selectedThreadId;
    if (selectedThreadId != null && selectedThreadId.trim().isNotEmpty) {
      return selectedThreadId;
    }
    final activeThreadId = turnController?.activeThreadId;
    if (activeThreadId != null && activeThreadId.trim().isNotEmpty) {
      return activeThreadId;
    }
    return null;
  }
}
