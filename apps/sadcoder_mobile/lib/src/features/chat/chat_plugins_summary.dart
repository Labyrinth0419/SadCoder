import '../../i18n/app_localizations.dart';
import '../../plugins/plugin_detail_reader.dart';
import '../../plugins/plugin_list_reader.dart';
import '../../plugins/plugin_mutation_runner.dart';

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
      final version = _versionLabel(l10n, plugin);
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

String buildPluginDetailSummary({
  required AppLocalizations l10n,
  required PluginDetail detail,
}) {
  final plugin = detail.plugin;
  final lines = <String>[l10n.pluginsTitle, _pluginLine(l10n, plugin)];
  final description = plugin.description;
  if (description.isNotEmpty) {
    lines.add('${l10n.pluginDescription}: $description');
  }
  if (detail.marketplaceName != null) {
    lines.add('${l10n.pluginMarketplace}: ${detail.marketplaceName}');
  }
  if (detail.marketplacePath != null) {
    lines.add('${l10n.pluginMarketplacePath}: ${detail.marketplacePath}');
  }
  final version = _versionLabel(l10n, plugin);
  if (version.isNotEmpty) {
    lines.add('${l10n.pluginVersion}: $version');
  }
  final source = _sourceLabel(plugin.source);
  if (source.isNotEmpty) {
    lines.add('${l10n.pluginSource}: $source');
  }
  final capabilities = plugin.interface?.capabilities ?? const [];
  if (capabilities.isNotEmpty) {
    lines.add('${l10n.pluginCapabilities}: ${capabilities.join(', ')}');
  }
  final readme = detail.readme;
  if (readme != null) {
    lines.add('${l10n.pluginReadme}:\n$readme');
  }
  return lines.join('\n');
}

String buildPluginMutationSummary({
  required AppLocalizations l10n,
  required PluginMutationResult result,
}) {
  final title = switch (result.operation) {
    PluginMutationOperation.install => l10n.pluginInstallRequested(
      result.pluginId,
    ),
    PluginMutationOperation.uninstall => l10n.pluginUninstallRequested(
      result.pluginId,
    ),
  };
  final message = result.message;
  if (message == null) {
    return title;
  }
  return '$title\n$message';
}

String _pluginLine(AppLocalizations l10n, PluginSummary plugin) {
  final installed = plugin.installed
      ? l10n.pluginInstalled
      : l10n.pluginNotInstalled;
  final enabled = plugin.enabled ? l10n.pluginEnabled : l10n.pluginDisabled;
  return '${plugin.displayName} (${plugin.name}): $installed, $enabled, ${l10n.pluginAvailability}: ${plugin.availability}';
}

String _versionLabel(AppLocalizations l10n, PluginSummary plugin) {
  return [
    if (plugin.version != null) plugin.version!,
    if (plugin.localVersion != null)
      l10n.pluginLocalVersion(plugin.localVersion!),
  ].join(', ');
}

String _sourceLabel(PluginSourceSummary source) {
  final detail = source.detail;
  if (detail.isEmpty) {
    return source.type;
  }
  return '${source.type}: $detail';
}
