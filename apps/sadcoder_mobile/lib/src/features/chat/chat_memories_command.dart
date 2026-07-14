import 'package:flutter/material.dart';

import '../../config/codex_config_snapshot_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../memories/memory_runner.dart';
import 'chat_config_summary_commands.dart';
import 'chat_memories_sheet.dart';

typedef ChatMemoriesThreadRefresher = Future<void> Function();

Future<String?> showMemoriesFromCommand({
  required BuildContext context,
  required MemoryRunner? runner,
  required CodexConfigSnapshotController? configController,
  required List<String> cwds,
  required String? threadId,
  required Map<String, Object?> threadRaw,
  required String arguments,
  ChatMemoriesThreadRefresher? refreshThread,
}) async {
  if (arguments.trim().isNotEmpty) {
    return null;
  }
  final l10n = context.l10n;
  final mode = threadMemoryModeFromRaw(threadRaw);
  final runnerValue = runner;
  if (runnerValue == null || mode == null) {
    return buildMemoriesSummaryFromCommand(
      l10n: l10n,
      controller: configController,
      cwds: cwds,
      threadRaw: threadRaw,
      arguments: arguments,
    );
  }
  final changes = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ChatMemoriesSheet(
      runner: runnerValue,
      threadId: threadId,
      initialMode: mode,
    ),
  );
  final changeCount = changes ?? 0;
  if (changeCount > 0) {
    await refreshThread?.call();
  }
  if (!context.mounted) {
    return null;
  }
  return changeCount == 0
      ? l10n.memoriesNoChanges
      : l10n.memoriesChangesApplied(changeCount);
}
