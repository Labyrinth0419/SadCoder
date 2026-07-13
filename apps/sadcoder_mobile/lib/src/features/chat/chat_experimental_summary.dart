import '../../config/codex_config_snapshot.dart';
import '../../config/codex_config_snapshot_controller.dart';
import '../../i18n/app_localizations.dart';
import 'chat_summary_formatting.dart';

String buildExperimentalSummary({
  required AppLocalizations l10n,
  required CodexConfigSnapshotController? controller,
  bool experimentalApiEnabled = true,
}) {
  final lines = <String>[l10n.experimentalTitle];
  lines.add(
    '${l10n.experimentalApiCapability}: '
    '${experimentalApiEnabled ? l10n.appEnabled : l10n.appDisabled}',
  );

  if (controller == null) {
    lines.add(l10n.experimentalUnavailable);
    return lines.join('\n');
  }
  if (controller.status == CodexConfigSnapshotStatus.failed) {
    lines.add(
      chatSummaryMessageWithOptionalDetail(
        l10n,
        l10n.experimentalLoadFailed,
        controller.error,
      ),
    );
    return lines.join('\n');
  }

  final snapshot = controller.snapshot;
  if (snapshot == null) {
    lines.add(l10n.experimentalNoSnapshot);
    return lines.join('\n');
  }

  lines.add(l10n.experimentalConfigValues);
  final entries =
      snapshot.config.entries
          .where((entry) => _isExperimentalConfigKey(entry.key))
          .toList()
        ..sort((left, right) => left.key.compareTo(right.key));
  if (entries.isEmpty) {
    lines.add('  ${l10n.experimentalNoConfigValues}');
  } else {
    for (final entry in entries) {
      final value = displayConfigValue(entry.value) ?? l10n.serverValueUnset;
      final origin =
          snapshot.originLabelFor(entry.key) ?? l10n.sourceServerDefault;
      lines.add('  ${entry.key}: $value (${l10n.overrideSource}: $origin)');
    }
  }

  return lines.join('\n');
}

bool _isExperimentalConfigKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized.contains('experimental') ||
      normalized == 'features' ||
      normalized == 'feature' ||
      normalized.startsWith('feature_') ||
      normalized.startsWith('features_') ||
      normalized.contains('feature_flag');
}
