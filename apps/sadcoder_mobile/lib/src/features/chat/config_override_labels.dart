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
