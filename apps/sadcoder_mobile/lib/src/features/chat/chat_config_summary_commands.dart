import '../../config/codex_config_snapshot_controller.dart';
import '../../i18n/app_localizations.dart';
import 'chat_debug_config_summary.dart';
import 'chat_experimental_summary.dart';
import 'chat_memories_summary.dart';

Future<String?> buildDebugConfigSummaryFromCommand({
  required AppLocalizations l10n,
  required CodexConfigSnapshotController? controller,
  required List<String> cwds,
  required String arguments,
}) async {
  if (arguments.trim().isNotEmpty) {
    return null;
  }
  await _refreshConfigSnapshot(controller: controller, cwds: cwds);
  return buildDebugConfigSummary(l10n: l10n, controller: controller);
}

Future<String?> buildExperimentalSummaryFromCommand({
  required AppLocalizations l10n,
  required CodexConfigSnapshotController? controller,
  required List<String> cwds,
  required String arguments,
}) async {
  if (arguments.trim().isNotEmpty) {
    return null;
  }
  await _refreshConfigSnapshot(controller: controller, cwds: cwds);
  return buildExperimentalSummary(l10n: l10n, controller: controller);
}

Future<String?> buildMemoriesSummaryFromCommand({
  required AppLocalizations l10n,
  required CodexConfigSnapshotController? controller,
  required List<String> cwds,
  required Map<String, Object?> threadRaw,
  required String arguments,
}) async {
  if (arguments.trim().isNotEmpty) {
    return null;
  }
  await _refreshConfigSnapshot(controller: controller, cwds: cwds);
  return buildMemoriesSummary(
    l10n: l10n,
    controller: controller,
    threadRaw: threadRaw,
  );
}

Future<void> _refreshConfigSnapshot({
  required CodexConfigSnapshotController? controller,
  required List<String> cwds,
}) async {
  if (controller == null) {
    return;
  }
  await controller.refresh(cwd: cwds.isEmpty ? null : cwds.first);
}
