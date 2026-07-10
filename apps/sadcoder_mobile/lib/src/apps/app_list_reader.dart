abstract interface class AppListReader {
  Future<AppListPage> listApps({
    String? cursor,
    int? limit,
    String? threadId,
    bool forceRefetch = false,
  });
}

class AppListPage {
  const AppListPage({required this.apps, this.nextCursor});

  factory AppListPage.fromJson(Map<String, Object?> json) {
    return AppListPage(
      apps: _list(
        json['data'],
      ).map(CodexAppSummary.fromJson).nonNulls.toList(growable: false),
      nextCursor: _stringField(json, ['nextCursor', 'next_cursor']),
    );
  }

  final List<CodexAppSummary> apps;
  final String? nextCursor;
}

class CodexAppSummary {
  const CodexAppSummary({
    required this.id,
    required this.name,
    required this.isAccessible,
    required this.isEnabled,
    required this.pluginDisplayNames,
    required this.raw,
    this.description,
    this.installUrl,
    this.distributionChannel,
    this.category,
    this.developer,
    this.website,
    this.version,
    this.reviewStatus,
  });

  static CodexAppSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    final id = _stringValue(map['id']);
    final name = _stringValue(map['name']);
    if (id == null || name == null) {
      return null;
    }
    final branding = _objectMap(map['branding']);
    final metadata = _objectMap(
      _valueField(map, ['appMetadata', 'app_metadata']),
    );
    final review = _objectMap(metadata['review']);
    return CodexAppSummary(
      id: id,
      name: name,
      description: _stringValue(map['description']),
      installUrl: _stringField(map, ['installUrl', 'install_url']),
      distributionChannel: _stringField(map, [
        'distributionChannel',
        'distribution_channel',
      ]),
      category:
          _stringValue(branding['category']) ??
          _firstString(metadata['categories']),
      developer:
          _stringValue(branding['developer']) ??
          _stringValue(metadata['developer']),
      website: _stringValue(branding['website']),
      version: _stringValue(metadata['version']),
      reviewStatus: _stringValue(review['status']),
      isAccessible: _boolField(map, ['isAccessible', 'is_accessible']) ?? false,
      isEnabled: _boolField(map, ['isEnabled', 'is_enabled']) ?? true,
      pluginDisplayNames: _stringList(
        _valueField(map, ['pluginDisplayNames', 'plugin_display_names']),
      ),
      raw: map,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? installUrl;
  final String? distributionChannel;
  final String? category;
  final String? developer;
  final String? website;
  final String? version;
  final String? reviewStatus;
  final bool isAccessible;
  final bool isEnabled;
  final List<String> pluginDisplayNames;
  final Map<String, Object?> raw;
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

String? _stringField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _stringValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

bool? _boolValue(Object? value) => value is bool ? value : null;

bool? _boolField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _boolValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

String? _firstString(Object? value) {
  if (value is! List) {
    return null;
  }
  for (final item in value) {
    final stringValue = _stringValue(item);
    if (stringValue != null) {
      return stringValue;
    }
  }
  return null;
}

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

Object? _valueField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value != null) {
      return value;
    }
  }
  return null;
}
