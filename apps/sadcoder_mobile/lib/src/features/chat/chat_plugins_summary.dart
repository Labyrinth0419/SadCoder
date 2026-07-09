import '../../i18n/app_localizations.dart';
import '../../plugins/plugin_list_reader.dart';

String buildPluginsSummary({
  required AppLocalizations l10n,
  required PluginListPage page,
}) {
  final lines = <String>[l10n.pluginsTitle];
  if (page.marketplaces.isEmpty && page.marketplaceLoadErrors.isEmpty) {
    lines.add(l10n.pluginsEmpty);
    return lines.join('\n');
  }

  for (final marketplace in page.marketplaces) {
    lines.add('${l10n.pluginMarketplace}: ${marketplace.displayName}');
    if (marketplace.path != null) {
      lines.add('  ${l10n.pluginMarketplacePath}: ${marketplace.path}');
    }
    if (marketplace.plugins.isEmpty) {
      lines.add('  ${l10n.pluginsEmpty}');
      continue;
    }
    for (final plugin in marketplace.plugins) {
      lines.add(_pluginLine(l10n, plugin));
      final description = plugin.description;
      if (description.isNotEmpty) {
        lines.add('  ${l10n.pluginDescription}: $description');
      }
      final version = _versionLabel(plugin);
      if (version.isNotEmpty) {
        lines.add('  ${l10n.pluginVersion}: $version');
      }
      final source = _sourceLabel(plugin.source);
      if (source.isNotEmpty) {
        lines.add('  ${l10n.pluginSource}: $source');
      }
      final capabilities = plugin.interface?.capabilities ?? const [];
      if (capabilities.isNotEmpty) {
        lines.add('  ${l10n.pluginCapabilities}: ${capabilities.join(', ')}');
      }
    }
  }

  if (page.marketplaceLoadErrors.isNotEmpty) {
    lines.add(l10n.pluginMarketplaceErrors);
    for (final error in page.marketplaceLoadErrors) {
      lines.add('  ${error.marketplacePath}: ${error.message}');
    }
  }

  return lines.join('\n');
}

String _pluginLine(AppLocalizations l10n, PluginSummary plugin) {
  final installed = plugin.installed
      ? l10n.pluginInstalled
      : l10n.pluginNotInstalled;
  final enabled = plugin.enabled ? l10n.pluginEnabled : l10n.pluginDisabled;
  return '${plugin.displayName} (${plugin.name}): $installed, $enabled, ${l10n.pluginAvailability}: ${plugin.availability}';
}

String _versionLabel(PluginSummary plugin) {
  return [
    if (plugin.version != null) plugin.version!,
    if (plugin.localVersion != null) 'local ${plugin.localVersion}',
  ].join(', ');
}

String _sourceLabel(PluginSourceSummary source) {
  final detail = source.detail;
  if (detail.isEmpty) {
    return source.type;
  }
  return '${source.type}: $detail';
}
