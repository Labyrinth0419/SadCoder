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
    this.availabilityNux,
    this.supportedReasoningEfforts = const [],
    this.defaultReasoningEffort,
    this.inputModalities = const [],
    this.supportsPersonality = false,
    this.additionalSpeedTiers = const [],
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
  final CodexModelAvailabilityNux? availabilityNux;
  final List<CodexModelReasoningEffort> supportedReasoningEfforts;
  final String? defaultReasoningEffort;
  final List<String> inputModalities;
  final bool supportsPersonality;
  final List<String> additionalSpeedTiers;
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

class CodexModelAvailabilityNux {
  const CodexModelAvailabilityNux({required this.message});

  final String message;
}

class CodexModelReasoningEffort {
  const CodexModelReasoningEffort({
    required this.id,
    required this.description,
  });

  final String id;
  final String description;
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
    final additionalSpeedTiers = _stringList(
      map['additionalSpeedTiers'] ?? map['additional_speed_tiers'],
    );
    final serviceTiers = _serviceTiersFromJson(
      map['serviceTiers'] ?? map['service_tiers'],
      additionalSpeedTiers: additionalSpeedTiers,
    );
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
      availabilityNux: _availabilityNuxFromJson(
        map['availabilityNux'] ?? map['availability_nux'],
      ),
      supportedReasoningEfforts: List.unmodifiable(
        _listOfMaps(
          map['supportedReasoningEfforts'] ??
              map['supported_reasoning_efforts'],
        ).map(_reasoningEffortFromJson).nonNulls,
      ),
      defaultReasoningEffort: _stringValue(
        map['defaultReasoningEffort'] ?? map['default_reasoning_effort'],
      ),
      inputModalities: List.unmodifiable(
        _stringList(map['inputModalities'] ?? map['input_modalities']),
      ),
      supportsPersonality: _boolValue(
        map['supportsPersonality'] ?? map['supports_personality'],
      ),
      additionalSpeedTiers: List.unmodifiable(additionalSpeedTiers),
      serviceTiers: List.unmodifiable(serviceTiers),
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

CodexModelAvailabilityNux? _availabilityNuxFromJson(Object? value) {
  final map = _stringKeyedMap(value);
  final message = _stringValue(map['message']);
  if (!_hasText(message)) {
    return null;
  }
  return CodexModelAvailabilityNux(message: message!.trim());
}

CodexModelReasoningEffort? _reasoningEffortFromJson(Map<String, Object?> map) {
  final id = _stringValue(map['reasoningEffort'] ?? map['reasoning_effort']);
  final description = _stringValue(map['description']);
  if (!_hasText(id)) {
    return null;
  }
  return CodexModelReasoningEffort(
    id: id!.trim(),
    description: description ?? '',
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

List<CodexModelServiceTier> _serviceTiersFromJson(
  Object? value, {
  required List<String> additionalSpeedTiers,
}) {
  final serviceTiers = _listOfMaps(
    value,
  ).map(_serviceTierFromJson).nonNulls.toList(growable: false);
  if (serviceTiers.isNotEmpty) {
    return serviceTiers;
  }
  return additionalSpeedTiers
      .map((tier) => CodexModelServiceTier(id: tier, name: tier))
      .toList(growable: false);
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

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<String>()
      .map((entry) => entry.trim())
      .where(_hasText)
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
