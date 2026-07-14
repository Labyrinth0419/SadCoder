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

class ChatMarketplaceAddCommand extends ChatPluginsCommand {
  const ChatMarketplaceAddCommand({
    required this.source,
    this.refName,
    this.sparsePaths = const [],
  });

  final String source;
  final String? refName;
  final List<String> sparsePaths;
}

class ChatMarketplaceRemoveCommand extends ChatPluginsCommand {
  const ChatMarketplaceRemoveCommand({required this.marketplaceName});

  final String marketplaceName;
}

class ChatMarketplaceUpgradeCommand extends ChatPluginsCommand {
  const ChatMarketplaceUpgradeCommand({this.marketplaceName});

  final String? marketplaceName;
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
  if (head == 'marketplace' || head == 'marketplaces') {
    final marketplaceMutation = _parseMarketplaceMutation(parts);
    if (marketplaceMutation != null) {
      return marketplaceMutation;
    }
  }
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

ChatPluginsCommand? _parseMarketplaceMutation(List<String> parts) {
  if (parts.length < 2) {
    return null;
  }
  return switch (parts[1].toLowerCase()) {
    'add' => _parseMarketplaceAdd(parts),
    'remove' when parts.length == 3 && !parts[2].startsWith('--') =>
      ChatMarketplaceRemoveCommand(marketplaceName: parts[2]),
    'upgrade' when parts.length == 2 => const ChatMarketplaceUpgradeCommand(),
    'upgrade' when parts.length == 3 && !parts[2].startsWith('--') =>
      ChatMarketplaceUpgradeCommand(marketplaceName: parts[2]),
    _ => null,
  };
}

ChatMarketplaceAddCommand? _parseMarketplaceAdd(List<String> parts) {
  if (parts.length < 3 || parts[2].startsWith('--')) {
    return null;
  }
  String? refName;
  final sparsePaths = <String>[];
  var index = 3;
  while (index < parts.length) {
    final token = parts[index];
    if (token == '--ref') {
      if (refName != null ||
          index + 1 >= parts.length ||
          parts[index + 1].startsWith('--')) {
        return null;
      }
      refName = parts[index + 1];
      index += 2;
      continue;
    }
    if (token.startsWith('--ref=')) {
      final value = token.substring('--ref='.length);
      if (refName != null || value.isEmpty) {
        return null;
      }
      refName = value;
      index++;
      continue;
    }
    if (token == '--sparse') {
      if (index + 1 >= parts.length || parts[index + 1].startsWith('--')) {
        return null;
      }
      sparsePaths.add(parts[index + 1]);
      index += 2;
      continue;
    }
    if (token.startsWith('--sparse=')) {
      final value = token.substring('--sparse='.length);
      if (value.isEmpty) {
        return null;
      }
      sparsePaths.add(value);
      index++;
      continue;
    }
    return null;
  }
  return ChatMarketplaceAddCommand(
    source: parts[2],
    refName: refName,
    sparsePaths: List.unmodifiable(sparsePaths),
  );
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
