abstract interface class ModelListReader {
  Future<ModelListPage> listModels({
    String? cursor,
    int? limit,
    bool includeHidden = false,
  });
}

class ModelListPage {
  const ModelListPage({required this.models, this.nextCursor});

  factory ModelListPage.fromJson(Map<String, Object?> json) {
    final rawModels = json['data'] ?? json['models'];
    if (rawModels is! List) {
      return const ModelListPage(models: []);
    }
    return ModelListPage(
      models: List.unmodifiable(rawModels.map(_modelFromJson).nonNulls),
      nextCursor: _stringValue(json['nextCursor'] ?? json['next_cursor']),
    );
  }

  final List<CodexModelSummary> models;
  final String? nextCursor;
}

class CodexModelSummary {
  const CodexModelSummary({
    required this.id,
    this.catalogId,
    this.name,
    this.description,
    this.provider,
    this.hidden = false,
    this.isDefault = false,
    this.upgrade,
    this.serviceTiers = const [],
    this.defaultServiceTier,
  });

  /// Model slug to pass back to app-server overrides, thread/start, or turn/start.
  final String id;

  /// Optional app-server catalog id. This can differ from [id] when a preset
  /// has a stable UI/catalog identity separate from the model slug.
  final String? catalogId;

  final String? name;
  final String? description;
  final String? provider;
  final bool hidden;
  final bool isDefault;
  final CodexModelUpgrade? upgrade;
  final List<CodexModelServiceTier> serviceTiers;
  final String? defaultServiceTier;

  String get label {
    final displayName = _hasText(name) ? name!.trim() : id;
    if (_hasText(provider)) {
      return '$displayName (${provider!.trim()})';
    }
    return displayName;
  }
}

class CodexModelUpgrade {
  const CodexModelUpgrade({
    required this.model,
    this.copy,
    this.link,
    this.migrationMarkdown,
  });

  final String model;
  final String? copy;
  final String? link;
  final String? migrationMarkdown;
}

class CodexModelServiceTier {
  const CodexModelServiceTier({required this.id, this.name, this.description});

  final String id;
  final String? name;
  final String? description;
}

CodexModelSummary? _modelFromJson(Object? value) {
  if (value is String) {
    final id = value.trim();
    if (id.isEmpty) {
      return null;
    }
    return CodexModelSummary(id: id);
  }
  if (value is Map) {
    final map = value.map((key, value) => MapEntry(key.toString(), value));
    final upgradeInfo = _stringKeyedMap(
      map['upgradeInfo'] ?? map['upgrade_info'],
    );
    final modelSlug =
        _stringValue(map['model']) ??
        _stringValue(map['slug']) ??
        _stringValue(map['id']) ??
        _stringValue(map['name']);
    final catalogId = _stringValue(map['id']);
    if (!_hasText(modelSlug)) {
      return null;
    }
    return CodexModelSummary(
      id: modelSlug!.trim(),
      catalogId: catalogId,
      name:
          _stringValue(map['displayName']) ??
          _stringValue(map['display_name']) ??
          _stringValue(map['name']),
      description:
          _stringValue(map['description']) ??
          _stringValue(map['short_description']) ??
          _stringValue(map['shortDescription']),
      provider: _stringValue(map['provider']),
      hidden: _boolValue(map['hidden']),
      isDefault: _boolValue(map['isDefault'] ?? map['is_default']),
      upgrade: _upgradeFromJson(map['upgrade'], upgradeInfo),
      serviceTiers: List.unmodifiable(
        _listOfMaps(
          map['serviceTiers'] ?? map['service_tiers'],
        ).map(_serviceTierFromJson).nonNulls,
      ),
      defaultServiceTier: _stringValue(
        map['defaultServiceTier'] ?? map['default_service_tier'],
      ),
    );
  }
  return null;
}

CodexModelUpgrade? _upgradeFromJson(
  Object? rawUpgrade,
  Map<String, Object?> upgradeInfo,
) {
  final model =
      _stringValue(rawUpgrade) ??
      _stringValue(upgradeInfo['model']) ??
      _stringValue(upgradeInfo['id']);
  if (!_hasText(model)) {
    return null;
  }
  return CodexModelUpgrade(
    model: model!.trim(),
    copy:
        _stringValue(upgradeInfo['upgradeCopy']) ??
        _stringValue(upgradeInfo['upgrade_copy']),
    link:
        _stringValue(upgradeInfo['modelLink']) ??
        _stringValue(upgradeInfo['model_link']),
    migrationMarkdown:
        _stringValue(upgradeInfo['migrationMarkdown']) ??
        _stringValue(upgradeInfo['migration_markdown']),
  );
}

CodexModelServiceTier? _serviceTierFromJson(Map<String, Object?> map) {
  final id = _stringValue(map['id']);
  if (!_hasText(id)) {
    return null;
  }
  return CodexModelServiceTier(
    id: id!.trim(),
    name: _stringValue(map['name']),
    description: _stringValue(map['description']),
  );
}

Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }
  return const {};
}

List<Map<String, Object?>> _listOfMaps(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((entry) => Map<String, Object?>.from(entry))
      .toList(growable: false);
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool _boolValue(Object? value) => value is bool && value;

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
