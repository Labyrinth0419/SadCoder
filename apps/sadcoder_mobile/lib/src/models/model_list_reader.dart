abstract interface class ModelListReader {
  Future<ModelListPage> listModels();
}

class ModelListPage {
  const ModelListPage({required this.models});

  factory ModelListPage.fromJson(Map<String, Object?> json) {
    final rawModels = json['data'] ?? json['models'];
    if (rawModels is! List) {
      return const ModelListPage(models: []);
    }
    return ModelListPage(
      models: List.unmodifiable(rawModels.map(_modelFromJson).nonNulls),
    );
  }

  final List<CodexModelSummary> models;
}

class CodexModelSummary {
  const CodexModelSummary({
    required this.id,
    this.catalogId,
    this.name,
    this.description,
    this.provider,
  });

  /// Model slug to pass back to app-server overrides, thread/start, or turn/start.
  final String id;

  /// Optional app-server catalog id. This can differ from [id] when a preset
  /// has a stable UI/catalog identity separate from the model slug.
  final String? catalogId;

  final String? name;
  final String? description;
  final String? provider;

  String get label {
    final displayName = _hasText(name) ? name!.trim() : id;
    if (_hasText(provider)) {
      return '$displayName (${provider!.trim()})';
    }
    return displayName;
  }
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
    );
  }
  return null;
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
