class AgentLogsResult {
  const AgentLogsResult({
    required this.schemaVersion,
    required this.maxTailBytes,
    required this.logs,
  });

  factory AgentLogsResult.fromJson(Map<String, Object?> json) {
    return AgentLogsResult(
      schemaVersion: _intField(json, ['schemaVersion', 'schema_version']) ?? 1,
      maxTailBytes: _intField(json, ['maxTailBytes', 'max_tail_bytes']) ?? 0,
      logs: _listOfMaps(
        _valueField(json, ['logs']),
      ).map(AgentLogEntry.fromJson).toList(growable: false),
    );
  }

  final int schemaVersion;
  final int maxTailBytes;
  final List<AgentLogEntry> logs;
}

class AgentLogEntry {
  const AgentLogEntry({
    required this.name,
    required this.path,
    required this.exists,
    required this.sizeBytes,
    required this.tailBytes,
    required this.truncated,
    required this.content,
    this.error,
  });

  factory AgentLogEntry.fromJson(Map<String, Object?> json) {
    return AgentLogEntry(
      name: _stringField(json, ['name']) ?? 'log',
      path: _stringField(json, ['path']) ?? '',
      exists: _boolField(json, ['exists']) ?? false,
      sizeBytes: _intField(json, ['sizeBytes', 'size_bytes']) ?? 0,
      tailBytes: _intField(json, ['tailBytes', 'tail_bytes']) ?? 0,
      truncated: _boolField(json, ['truncated']) ?? false,
      content: _stringValue(json['content']) ?? '',
      error: _stringField(json, ['error']),
    );
  }

  final String name;
  final String path;
  final bool exists;
  final int sizeBytes;
  final int tailBytes;
  final bool truncated;
  final String content;
  final String? error;
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
    return value;
  }
  return null;
}

String? _stringField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _stringValue(map[key]);
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
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
