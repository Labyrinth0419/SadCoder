import '../../config/codex_config_overrides.dart';
import '../../i18n/app_localizations.dart';

String configOverrideSourceLabel(
  AppLocalizations l10n,
  CodexConfigOverrideSource source,
) {
  return switch (source) {
    CodexConfigOverrideSource.serverDefault => l10n.sourceServerDefault,
    CodexConfigOverrideSource.appDefault => l10n.sourceAppDefault,
    CodexConfigOverrideSource.session => l10n.sourceSessionOverride,
    CodexConfigOverrideSource.turn => l10n.sourceTurnOverride,
  };
}

String? configOverrideValueLabel(Object? value) {
  return switch (value) {
    null => null,
    String text => text,
    Map<String, Object?> map when map['type'] is String =>
      map['type']! as String,
    Map map when map['type'] is String => map['type']! as String,
    Map map when map.isEmpty => null,
    Map map =>
      map.entries.map((entry) => '${entry.key}: ${entry.value}').join(', '),
    _ => value.toString(),
  };
}
