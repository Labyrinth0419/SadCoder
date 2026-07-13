import 'package:flutter/material.dart';

import '../../accounts/account_snapshot_controller.dart';
import '../../commands/slash_command_action_dispatcher.dart';
import '../../i18n/app_localizations.dart';
import '../../session/codex_session_state_controller.dart';
import '../../usage/account_usage_snapshot_controller.dart';
import 'chat_feedback_sheet.dart';

typedef ChatOptionalStringProvider = String? Function();

class ChatAccountCommandHandler {
  const ChatAccountCommandHandler({
    required this.context,
    required this.mounted,
    required this.sessionController,
    required this.accountSnapshotController,
    required this.accountUsageSnapshotController,
    required this.currentThreadIdProvider,
    required this.activeTurnIdProvider,
  });

  final BuildContext context;
  final bool Function() mounted;
  final CodexSessionStateController? sessionController;
  final AccountSnapshotController? accountSnapshotController;
  final AccountUsageSnapshotController? accountUsageSnapshotController;
  final ChatOptionalStringProvider currentThreadIdProvider;
  final ChatOptionalStringProvider activeTurnIdProvider;

  Future<SlashCommandCallbackResult> submitFeedback() async {
    final runner = sessionController?.feedbackUploadRunner;
    if (runner == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final result = await showModalBottomSheet<ChatFeedbackFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ChatFeedbackSheet(),
    );
    if (!mounted() || result == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    await runner.uploadFeedback(
      classification: result.category.classification,
      reason: result.note,
      threadId: currentThreadIdProvider(),
      turnId: activeTurnIdProvider(),
      includeLogs: result.includeLogs,
    );
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> logoutAccount() async {
    final runner = sessionController?.accountLogoutRunner;
    if (runner == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logoutAccountTitle),
        content: Text(l10n.logoutAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.logoutAccountConfirm),
          ),
        ],
      ),
    );
    if (!mounted() || confirmed != true) {
      return SlashCommandCallbackResult.cancelled;
    }

    await runner.logout();
    await Future.wait([
      if (accountSnapshotController != null)
        accountSnapshotController!.refresh(),
      if (accountUsageSnapshotController != null)
        accountUsageSnapshotController!.refresh(),
    ]);
    return SlashCommandCallbackResult.executed;
  }
}
