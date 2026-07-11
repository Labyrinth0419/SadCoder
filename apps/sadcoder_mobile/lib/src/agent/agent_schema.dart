class AgentSchemaResult {
  const AgentSchemaResult({
    required this.schemaVersion,
    required this.source,
    required this.experimental,
    required this.generated,
    required this.cacheDir,
    required this.metadataPath,
    required this.fileCount,
    required this.totalBytes,
    required this.files,
    this.codexVersion,
    this.generatedAtUnixMs,
    this.bundlePath,
    this.digest,
  });

  factory AgentSchemaResult.fromJson(Map<String, Object?> json) {
    return AgentSchemaResult(
      schemaVersion: _intField(json, ['schemaVersion', 'schema_version']) ?? 1,
      source:
          _stringField(json, ['source']) ??
          'codex app-server generate-json-schema',
      experimental: _boolField(json, ['experimental']) ?? false,
      generated: _boolField(json, ['generated']) ?? false,
      cacheDir: _stringField(json, ['cacheDir', 'cache_dir']) ?? '',
      metadataPath: _stringField(json, ['metadataPath', 'metadata_path']) ?? '',
      codexVersion: _stringField(json, ['codexVersion', 'codex_version']),
      generatedAtUnixMs: _intField(json, [
        'generatedAtUnixMs',
        'generated_at_unix_ms',
      ]),
      bundlePath: _stringField(json, ['bundlePath', 'bundle_path']),
      fileCount: _intField(json, ['fileCount', 'file_count']) ?? 0,
      totalBytes: _intField(json, ['totalBytes', 'total_bytes']) ?? 0,
      digest: _stringField(json, ['digest']),
      files: _listOfMaps(
        _valueField(json, ['files']),
      ).map(AgentSchemaFile.fromJson).toList(growable: false),
    );
  }

  final int schemaVersion;
  final String source;
  final bool experimental;
  final bool generated;
  final String cacheDir;
  final String metadataPath;
  final String? codexVersion;
  final int? generatedAtUnixMs;
  final String? bundlePath;
  final int fileCount;
  final int totalBytes;
  final String? digest;
  final List<AgentSchemaFile> files;

  DateTime? get generatedAt {
    final timestamp = generatedAtUnixMs;
    if (timestamp == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
  }
}

class AgentSchemaFile {
  const AgentSchemaFile({
    required this.path,
    required this.sizeBytes,
    required this.digest,
    this.modifiedAtUnixMs,
  });

  factory AgentSchemaFile.fromJson(Map<String, Object?> json) {
    return AgentSchemaFile(
      path: _stringField(json, ['path']) ?? '',
      sizeBytes: _intField(json, ['sizeBytes', 'size_bytes']) ?? 0,
      modifiedAtUnixMs: _intField(json, [
        'modifiedAtUnixMs',
        'modified_at_unix_ms',
      ]),
      digest: _stringField(json, ['digest']) ?? '',
    );
  }

  final String path;
  final int sizeBytes;
  final int? modifiedAtUnixMs;
  final String digest;

  DateTime? get modifiedAt {
    final timestamp = modifiedAtUnixMs;
    if (timestamp == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
  }
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
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
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

bool? _boolField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) {
      return value;
    }
  }
  return null;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

int? _intField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _intValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
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
