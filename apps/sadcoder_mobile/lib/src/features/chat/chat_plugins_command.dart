import '../../plugins/plugin_list_reader.dart';

sealed class ChatPluginsCommand {
  const ChatPluginsCommand();
}

class ChatPluginsListCommand extends ChatPluginsCommand {
  const ChatPluginsListCommand({this.marketplaceKinds = const []});

  final List<PluginMarketplaceKind> marketplaceKinds;
}

class ChatPluginsReadCommand extends ChatPluginsCommand {
  const ChatPluginsReadCommand({required this.pluginId});

  final String pluginId;
}

class ChatPluginsInstallCommand extends ChatPluginsCommand {
  const ChatPluginsInstallCommand({required this.pluginId});

  final String pluginId;
}

class ChatPluginsUninstallCommand extends ChatPluginsCommand {
  const ChatPluginsUninstallCommand({required this.pluginId});

  final String pluginId;
}

ChatPluginsCommand? parseChatPluginsCommand(String arguments) {
  final parts = arguments
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return const ChatPluginsListCommand();
  }

  final head = parts.first.toLowerCase();
  if (parts.length == 2) {
    final pluginId = parts[1];
    if (head == 'read' || head == 'show' || head == 'detail') {
      return ChatPluginsReadCommand(pluginId: pluginId);
    }
    if (head == 'install') {
      return ChatPluginsInstallCommand(pluginId: pluginId);
    }
    if (head == 'uninstall' || head == 'remove') {
      return ChatPluginsUninstallCommand(pluginId: pluginId);
    }
  }

  final marketplaceKinds = _pluginMarketplaceKindsFromParts(parts);
  if (marketplaceKinds == null) {
    return null;
  }
  return ChatPluginsListCommand(marketplaceKinds: marketplaceKinds);
}

List<PluginMarketplaceKind>? _pluginMarketplaceKindsFromParts(
  List<String> parts,
) {
  if (parts.isEmpty) {
    return const [];
  }
  final kind = switch (parts) {
    [final rawKind] => _parsePluginMarketplaceKind(rawKind),
    ['marketplace' || 'marketplaces', final rawKind] =>
      _parsePluginMarketplaceKind(rawKind),
    _ => null,
  };
  return kind == null ? null : [kind];
}

PluginMarketplaceKind? _parsePluginMarketplaceKind(String value) {
  final normalized = value.trim().toLowerCase().replaceAll('_', '-');
  for (final kind in PluginMarketplaceKind.values) {
    final normalizedName = kind.name
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '-${match.group(0)!.toLowerCase()}',
        )
        .toLowerCase();
    if (normalized == kind.wireName || normalized == normalizedName) {
      return kind;
    }
  }
  return null;
}
