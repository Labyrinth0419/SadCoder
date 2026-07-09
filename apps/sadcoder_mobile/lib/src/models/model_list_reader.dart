abstract interface class ModelListReader {
  Future<ModelListPage> listModels();
}

class ModelListPage {
  const ModelListPage({required this.models});

  factory ModelListPage.fromJson(Map<String, Object?> json) {
    final rawModels = json['models'];
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
  const CodexModelSummary({required this.id, this.name, this.provider});

  final String id;
  final String? name;
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
    final id = _stringValue(map['id']) ?? _stringValue(map['name']);
    if (!_hasText(id)) {
      return null;
    }
    return CodexModelSummary(
      id: id!.trim(),
      name:
          _stringValue(map['displayName']) ??
          _stringValue(map['display_name']) ??
          _stringValue(map['name']),
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
