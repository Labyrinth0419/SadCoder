import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/codex_config_snapshot_controller.dart';
import '../../experimental_features/experimental_feature_runner.dart';
import '../../i18n/app_localizations.dart';
import 'chat_config_summary_commands.dart';
import 'chat_experimental_feature_sheet.dart';

Future<String?> showExperimentalFeaturesFromCommand({
  required BuildContext context,
  required ExperimentalFeatureRunner? runner,
  required CodexConfigSnapshotController? configController,
  required List<String> cwds,
  required String? threadId,
  required String arguments,
}) async {
  final l10n = context.l10n;
  if (arguments.trim().isNotEmpty) {
    return null;
  }
  final runnerValue = runner;
  if (runnerValue == null) {
    return buildExperimentalSummaryFromCommand(
      l10n: l10n,
      controller: configController,
      cwds: cwds,
      arguments: arguments,
    );
  }

  unawaited(
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
              Flexible(child: Text(l10n.experimentalFeatureLoading)),
            ],
          ),
        ),
      ),
    ),
  );
  late final List<ExperimentalFeature> features;
  try {
    await configController?.refresh(cwd: cwds.isEmpty ? null : cwds.first);
    features = await runnerValue.listFeatures(threadId: threadId);
  } on Object {
    return buildExperimentalSummaryFromCommand(
      l10n: l10n,
      controller: configController,
      cwds: cwds,
      arguments: arguments,
    );
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
  if (!context.mounted) {
    return l10n.experimentalFeatureNoChanges;
  }
  final changes = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ChatExperimentalFeatureSheet(
      runner: runnerValue,
      features: features,
      threadId: threadId,
      expectedVersion: configController?.snapshot?.userConfigVersion,
    ),
  );
  final changeCount = changes ?? 0;
  if (changeCount > 0) {
    await configController?.refresh(cwd: cwds.isEmpty ? null : cwds.first);
  }
  if (!context.mounted) {
    return null;
  }
  return changeCount == 0
      ? l10n.experimentalFeatureNoChanges
      : l10n.experimentalFeatureChangesApplied(changeCount);
}
