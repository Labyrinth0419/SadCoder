import 'package:flutter/material.dart';

import '../../commands/slash_command_action_dispatcher.dart';
import '../../events/codex_event.dart';
import '../../external_agents/external_agent_config_import_controller.dart';
import '../../external_agents/external_agent_config_runner.dart';
import '../../i18n/app_localizations.dart';
import 'chat_external_agent_import_progress_sheet.dart';
import 'chat_external_agent_import_sheet.dart';

typedef ChatImportWorkspaceCwdsProvider = List<String> Function();

class ChatExternalAgentImportHandler {
  const ChatExternalAgentImportHandler({
    required this.context,
    required this.mounted,
    required this.runner,
    required this.currentWorkspaceCwdsProvider,
    this.events,
  });

  final BuildContext context;
  final bool Function() mounted;
  final ExternalAgentConfigRunner? runner;
  final ChatImportWorkspaceCwdsProvider currentWorkspaceCwdsProvider;
  final Stream<CodexEvent>? events;

  Future<SlashCommandCallbackResult> importFromClaudeCode() async {
    final runner = this.runner;
    if (runner == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Flexible(child: Text(context.l10n.externalAgentImportDetecting)),
            ],
          ),
        ),
      ),
    );
    late final ExternalAgentConfigDetection detection;
    final historiesFuture = runner.readImportHistories().then(
      (histories) => histories,
      onError: (Object _) => const <ExternalAgentConfigImportHistory>[],
    );
    late final List<ExternalAgentConfigImportHistory> histories;
    try {
      detection = await runner.detect(
        includeHome: true,
        cwds: currentWorkspaceCwdsProvider(),
      );
      histories = await historiesFuture;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!mounted() || !context.mounted) {
      return SlashCommandCallbackResult.cancelled;
    }
    final selectedItems =
        await showModalBottomSheet<List<ExternalAgentConfigMigrationItem>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => ChatExternalAgentImportSheet(
            items: detection.items,
            histories: histories,
          ),
        );
    if (selectedItems == null ||
        selectedItems.isEmpty ||
        !mounted() ||
        !context.mounted) {
      return SlashCommandCallbackResult.cancelled;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.externalAgentImportConfirmTitle),
        content: Text(
          context.l10n.externalAgentImportConfirmBody(selectedItems.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('external-agent-import-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.externalAgentImportConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted() || !context.mounted) {
      return SlashCommandCallbackResult.cancelled;
    }
    final progressController = ExternalAgentConfigImportController(
      events: events,
    );
    final progressSheet = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          ChatExternalAgentImportProgressSheet(controller: progressController),
    );
    try {
      final started = await runner.startImport(
        items: selectedItems,
        source: 'claude',
      );
      progressController.track(started.importId);
      await progressSheet;
      return SlashCommandCallbackResult.executed;
    } on Object catch (error) {
      progressController.fail(error);
      await progressSheet;
      rethrow;
    } finally {
      progressController.dispose();
    }
  }
}
