import 'dart:convert';

class CodexConfigSnapshot {
  const CodexConfigSnapshot({
    required this.config,
    required this.origins,
    required this.layers,
  });

  factory CodexConfigSnapshot.fromJson(Map<String, Object?> json) {
    return CodexConfigSnapshot(
      config: _objectMap(json['config']),
      origins: _originMap(json['origins']),
      layers: _objectList(json['layers']),
    );
  }

  final Map<String, Object?> config;
  final Map<String, CodexConfigOrigin> origins;
  final List<Map<String, Object?>> layers;

  Object? valueFor(String key) => config[key];

  String? displayValueFor(String key) => displayConfigValue(config[key]);

  String? originLabelFor(String key) => origins[key]?.displayLabel;

  String? get userConfigVersion {
    for (final layer in layers) {
      final source = _objectMap(layer['name']);
      if (_stringValue(source['type']) == 'user' &&
          !_hasText(_stringValue(source['profile']))) {
        return _stringValue(layer['version']);
      }
    }
    return null;
  }

  Map<String, Object?> toRawJson() => {
    'config': config,
    'origins': origins.map((key, value) => MapEntry(key, value.raw)),
    'layers': layers,
  };
}

class CodexConfigOrigin {
  const CodexConfigOrigin({required this.raw});

  factory CodexConfigOrigin.fromJson(Map<String, Object?> json) {
    return CodexConfigOrigin(raw: Map.unmodifiable(json));
  }

  final Map<String, Object?> raw;

  String? get version => _stringValue(raw['version']);

  String get displayLabel {
    final name = raw['name'];
    if (name is Map) {
      final source = _objectMap(name);
      final type = _stringValue(source['type']);
      final profile = _stringValue(source['profile']);
      final file = _stringValue(source['file']);
      final projectFolder = _stringValue(source['dot_codex_folder']);
      if (_hasText(profile)) {
        return '$type/$profile';
      }
      if (_hasText(file)) {
        return '$type: $file';
      }
      if (_hasText(projectFolder)) {
        return '$type: $projectFolder';
      }
      if (_hasText(type)) {
        return type!;
      }
    }
    final text = _stringValue(name);
    if (_hasText(text)) {
      return text!;
    }
    return version ?? 'unknown';
  }
}

String? displayConfigValue(Object? value) {
  return switch (value) {
    null => null,
    String text when text.trim().isEmpty => null,
    String text => text,
    num number => number.toString(),
    bool boolean => boolean.toString(),
    Map map when map['type'] is String => map['type'] as String,
    List list when list.isEmpty => null,
    List list => jsonEncode(list),
    Map map when map.isEmpty => null,
    Map map => jsonEncode(map),
    _ => value.toString(),
  };
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}

Map<String, CodexConfigOrigin> _originMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return Map.unmodifiable(
    value.map((key, value) {
      final origin = value is Map
          ? CodexConfigOrigin.fromJson(_objectMap(value))
          : CodexConfigOrigin.fromJson({'name': value});
      return MapEntry(key.toString(), origin);
    }),
  );
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(value.map(_objectMap));
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
