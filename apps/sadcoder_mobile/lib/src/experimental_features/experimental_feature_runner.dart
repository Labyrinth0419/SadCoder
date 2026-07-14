abstract interface class ExperimentalFeatureRunner {
  Future<List<ExperimentalFeature>> listFeatures({String? threadId});

  Future<ExperimentalFeatureWriteResult> setFeatureEnabled({
    required String featureName,
    required bool enabled,
    String? expectedVersion,
  });
}

enum ExperimentalFeatureStage {
  beta,
  underDevelopment,
  stable,
  deprecated,
  removed,
  unknown;

  static ExperimentalFeatureStage fromWire(Object? value) {
    final normalized = value?.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[_-]'),
      '',
    );
    return switch (normalized) {
      'beta' || 'experimental' => beta,
      'underdevelopment' => underDevelopment,
      'stable' => stable,
      'deprecated' => deprecated,
      'removed' => removed,
      _ => unknown,
    };
  }
}

class ExperimentalFeature {
  const ExperimentalFeature({
    required this.name,
    required this.stage,
    required this.enabled,
    required this.defaultEnabled,
    this.displayName,
    this.description,
    this.announcement,
    this.raw = const {},
  });

  static ExperimentalFeature? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final raw = Map<String, Object?>.fromEntries(
      value.entries.map((entry) => MapEntry(entry.key.toString(), entry.value)),
    );
    final name = _stringValue(raw['name']);
    if (name == null) {
      return null;
    }
    return ExperimentalFeature(
      name: name,
      stage: ExperimentalFeatureStage.fromWire(raw['stage']),
      displayName: _stringValue(raw['displayName'] ?? raw['display_name']),
      description: _stringValue(raw['description']),
      announcement: _stringValue(raw['announcement']),
      enabled: _boolValue(raw['enabled']),
      defaultEnabled: _boolValue(
        raw['defaultEnabled'] ?? raw['default_enabled'],
      ),
      raw: Map.unmodifiable(raw),
    );
  }

  final String name;
  final ExperimentalFeatureStage stage;
  final String? displayName;
  final String? description;
  final String? announcement;
  final bool enabled;
  final bool defaultEnabled;
  final Map<String, Object?> raw;

  String get label => displayName ?? name;

  bool get isUserSelectable => stage == ExperimentalFeatureStage.beta;
}

class ExperimentalFeatureWriteResult {
  const ExperimentalFeatureWriteResult({
    required this.status,
    required this.version,
    required this.filePath,
    required this.raw,
    this.overriddenMessage,
    this.effectiveValue,
  });

  factory ExperimentalFeatureWriteResult.fromJson(Map<String, Object?> json) {
    final overridden = _objectMap(json['overriddenMetadata']);
    return ExperimentalFeatureWriteResult(
      status: _stringValue(json['status']) ?? 'unknown',
      version: _stringValue(json['version']),
      filePath: _stringValue(json['filePath'] ?? json['file_path']),
      overriddenMessage: _stringValue(overridden['message']),
      effectiveValue: overridden['effectiveValue'],
      raw: Map.unmodifiable(json),
    );
  }

  final String status;
  final String? version;
  final String? filePath;
  final String? overriddenMessage;
  final Object? effectiveValue;
  final Map<String, Object?> raw;

  bool get wasOverridden => overriddenMessage != null;
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool _boolValue(Object? value) => value is bool ? value : false;

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}
