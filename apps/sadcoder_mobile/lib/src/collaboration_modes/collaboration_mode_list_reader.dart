abstract interface class CollaborationModeListReader {
  Future<CollaborationModeCatalog> listCollaborationModes();
}

class CollaborationModeCatalog {
  const CollaborationModeCatalog({
    required this.supported,
    required this.presets,
  });

  factory CollaborationModeCatalog.fromJson(Map<String, Object?> json) {
    final data = json['data'];
    final presets = data is List
        ? data
              .map(CodexCollaborationModePreset.fromJson)
              .whereType<CodexCollaborationModePreset>()
              .toList(growable: false)
        : const <CodexCollaborationModePreset>[];
    return CollaborationModeCatalog(
      supported: true,
      presets: List.unmodifiable(presets),
    );
  }

  static const unsupported = CollaborationModeCatalog(
    supported: false,
    presets: [],
  );

  final bool supported;
  final List<CodexCollaborationModePreset> presets;

  CodexCollaborationModePreset? presetForMode(String mode) {
    final normalized = mode.trim().toLowerCase();
    for (final preset in presets) {
      if (preset.mode?.toLowerCase() == normalized) {
        return preset;
      }
    }
    return null;
  }
}

class CodexCollaborationModePreset {
  const CodexCollaborationModePreset({
    required this.name,
    required this.mode,
    required this.model,
    required this.reasoningEffort,
    required this.raw,
  });

  static CodexCollaborationModePreset? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final raw = value.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    final name = _stringValue(raw['name']);
    if (name == null) {
      return null;
    }
    return CodexCollaborationModePreset(
      name: name,
      mode: _stringValue(raw['mode']),
      model: _stringValue(raw['model']),
      reasoningEffort: _stringValue(
        raw['reasoning_effort'] ?? raw['reasoningEffort'],
      ),
      raw: Map.unmodifiable(raw),
    );
  }

  final String name;
  final String? mode;
  final String? model;
  final String? reasoningEffort;
  final Map<String, Object?> raw;
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
