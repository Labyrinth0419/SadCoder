abstract interface class PluginListReader {
  Future<PluginListPage> listPlugins({
    List<String> cwds = const [],
    List<PluginMarketplaceKind> marketplaceKinds = const [],
  });
}

enum PluginMarketplaceKind {
  local('local'),
  vertical('vertical'),
  workspaceDirectory('workspace-directory'),
  sharedWithMe('shared-with-me'),
  createdByMeRemote('created-by-me-remote');

  const PluginMarketplaceKind(this.wireName);

  final String wireName;
}

class PluginListPage {
  const PluginListPage({
    required this.marketplaces,
    this.marketplaceLoadErrors = const [],
    this.featuredPluginIds = const [],
  });

  factory PluginListPage.fromJson(Map<String, Object?> json) {
    return PluginListPage(
      marketplaces: _list(
        json['marketplaces'],
      ).map(PluginMarketplaceEntry.fromJson).nonNulls.toList(growable: false),
      marketplaceLoadErrors: _list(
        json['marketplaceLoadErrors'],
      ).map(MarketplaceLoadError.fromJson).nonNulls.toList(growable: false),
      featuredPluginIds: _stringList(json['featuredPluginIds']),
    );
  }

  final List<PluginMarketplaceEntry> marketplaces;
  final List<MarketplaceLoadError> marketplaceLoadErrors;
  final List<String> featuredPluginIds;
}

class PluginMarketplaceEntry {
  const PluginMarketplaceEntry({
    required this.name,
    required this.plugins,
    required this.raw,
    this.path,
    this.interface,
  });

  static PluginMarketplaceEntry? fromJson(Object? value) {
    final map = _objectMap(value);
    final name = _stringValue(map['name']);
    if (name == null) {
      return null;
    }
    return PluginMarketplaceEntry(
      name: name,
      path: _stringValue(map['path']),
      interface: MarketplaceInterfaceSummary.fromJson(map['interface']),
      plugins: _list(
        map['plugins'],
      ).map(PluginSummary.fromJson).nonNulls.toList(growable: false),
      raw: map,
    );
  }

  final String name;
  final String? path;
  final MarketplaceInterfaceSummary? interface;
  final List<PluginSummary> plugins;
  final Map<String, Object?> raw;

  String get displayName => interface?.displayName ?? name;
}

class MarketplaceInterfaceSummary {
  const MarketplaceInterfaceSummary({this.displayName});

  static MarketplaceInterfaceSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    if (map.isEmpty) {
      return null;
    }
    return MarketplaceInterfaceSummary(
      displayName: _stringValue(map['displayName']),
    );
  }

  final String? displayName;
}

class PluginSummary {
  const PluginSummary({
    required this.id,
    required this.name,
    required this.source,
    required this.installed,
    required this.enabled,
    required this.installPolicy,
    required this.authPolicy,
    required this.availability,
    required this.keywords,
    required this.raw,
    this.remotePluginId,
    this.version,
    this.localVersion,
    this.interface,
  });

  static PluginSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    final id = _stringValue(map['id']);
    final name = _stringValue(map['name']);
    if (id == null || name == null) {
      return null;
    }
    return PluginSummary(
      id: id,
      remotePluginId: _stringValue(map['remotePluginId']),
      version: _stringValue(map['version']),
      localVersion: _stringValue(map['localVersion']),
      name: name,
      source: PluginSourceSummary.fromJson(map['source']),
      installed: _boolValue(map['installed']) ?? false,
      enabled: _boolValue(map['enabled']) ?? false,
      installPolicy: _stringValue(map['installPolicy']) ?? 'UNKNOWN',
      authPolicy: _stringValue(map['authPolicy']) ?? 'UNKNOWN',
      availability: _stringValue(map['availability']) ?? 'AVAILABLE',
      interface: PluginInterfaceSummary.fromJson(map['interface']),
      keywords: _stringList(map['keywords']),
      raw: map,
    );
  }

  final String id;
  final String? remotePluginId;
  final String? version;
  final String? localVersion;
  final String name;
  final PluginSourceSummary source;
  final bool installed;
  final bool enabled;
  final String installPolicy;
  final String authPolicy;
  final String availability;
  final PluginInterfaceSummary? interface;
  final List<String> keywords;
  final Map<String, Object?> raw;

  String get displayName => interface?.displayName ?? name;

  String get description {
    final summary = interface?.shortDescription;
    if (summary != null && summary.isNotEmpty) {
      return summary;
    }
    final longDescription = interface?.longDescription;
    if (longDescription != null && longDescription.isNotEmpty) {
      return longDescription;
    }
    return '';
  }
}

class PluginSourceSummary {
  const PluginSourceSummary({required this.type, required this.raw});

  static PluginSourceSummary fromJson(Object? value) {
    final map = _objectMap(value);
    return PluginSourceSummary(
      type: _stringValue(map['type']) ?? 'unknown',
      raw: map,
    );
  }

  final String type;
  final Map<String, Object?> raw;

  String get detail {
    return switch (type) {
      'local' => _stringValue(raw['path']) ?? '',
      'git' => _stringValue(raw['url']) ?? '',
      'npm' => _stringValue(raw['package']) ?? '',
      'remote' => '',
      _ => '',
    };
  }
}

class PluginInterfaceSummary {
  const PluginInterfaceSummary({
    this.displayName,
    this.shortDescription,
    this.longDescription,
    this.developerName,
    this.category,
    this.capabilities = const [],
    this.websiteUrl,
  });

  static PluginInterfaceSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    if (map.isEmpty) {
      return null;
    }
    return PluginInterfaceSummary(
      displayName: _stringValue(map['displayName']),
      shortDescription: _stringValue(map['shortDescription']),
      longDescription: _stringValue(map['longDescription']),
      developerName: _stringValue(map['developerName']),
      category: _stringValue(map['category']),
      capabilities: _stringList(map['capabilities']),
      websiteUrl: _stringValue(map['websiteUrl']),
    );
  }

  final String? displayName;
  final String? shortDescription;
  final String? longDescription;
  final String? developerName;
  final String? category;
  final List<String> capabilities;
  final String? websiteUrl;
}

class MarketplaceLoadError {
  const MarketplaceLoadError({
    required this.marketplacePath,
    required this.message,
  });

  static MarketplaceLoadError? fromJson(Object? value) {
    final map = _objectMap(value);
    final path = _stringValue(map['marketplacePath']);
    final message = _stringValue(map['message']);
    if (path == null || message == null) {
      return null;
    }
    return MarketplaceLoadError(marketplacePath: path, message: message);
  }

  final String marketplacePath;
  final String message;
}

List<Object?> _list(Object? value) {
  return value is List ? value : const [];
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool? _boolValue(Object? value) => value is bool ? value : null;

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(
    value
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty),
  );
}
