import '../../apps/app_list_reader.dart';
import '../../i18n/app_localizations.dart';

String buildAppsSummary({
  required AppLocalizations l10n,
  required AppListPage page,
}) {
  final lines = <String>[l10n.appsTitle];
  if (page.apps.isEmpty) {
    lines.add(l10n.appsEmpty);
    return lines.join('\n');
  }

  for (final app in page.apps) {
    lines.add(_appLine(l10n, app));
    if (app.description != null) {
      lines.add('  ${l10n.appDescription}: ${app.description}');
    }
    if (app.category != null) {
      lines.add('  ${l10n.appCategory}: ${app.category}');
    }
    if (app.developer != null) {
      lines.add('  ${l10n.appDeveloper}: ${app.developer}');
    }
    if (app.version != null) {
      lines.add('  ${l10n.appVersion}: ${app.version}');
    }
    if (app.distributionChannel != null) {
      lines.add('  ${l10n.appDistribution}: ${app.distributionChannel}');
    }
    if (app.reviewStatus != null) {
      lines.add('  ${l10n.appReview}: ${app.reviewStatus}');
    }
    if (app.pluginDisplayNames.isNotEmpty) {
      lines.add('  ${l10n.appPlugins}: ${app.pluginDisplayNames.join(', ')}');
    }
    if (app.website != null) {
      lines.add('  ${l10n.appWebsite}: ${app.website}');
    }
    if (app.installUrl != null) {
      lines.add('  ${l10n.appInstallUrl}: ${app.installUrl}');
    }
  }

  if (page.nextCursor != null) {
    lines.add('${l10n.appsNextCursor}: ${page.nextCursor}');
  }

  return lines.join('\n');
}

String _appLine(AppLocalizations l10n, CodexAppSummary app) {
  final accessible = app.isAccessible
      ? l10n.appAccessible
      : l10n.appNotAccessible;
  final enabled = app.isEnabled ? l10n.appEnabled : l10n.appDisabled;
  return '${app.name} (${app.id}): $accessible, $enabled';
}
