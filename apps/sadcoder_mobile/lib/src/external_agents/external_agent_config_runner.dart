abstract interface class ExternalAgentConfigRunner {
  Future<ExternalAgentConfigDetection> detect({
    bool includeHome = true,
    List<String> cwds = const [],
  });

  Future<ExternalAgentConfigImportStart> startImport({
    required List<ExternalAgentConfigMigrationItem> items,
    String? source,
  });

  Future<List<ExternalAgentConfigImportHistory>> readImportHistories();
}

enum ExternalAgentConfigMigrationItemType {
  agentsMd('AGENTS_MD'),
  config('CONFIG'),
  skills('SKILLS'),
  plugins('PLUGINS'),
  mcpServerConfig('MCP_SERVER_CONFIG'),
  subagents('SUBAGENTS'),
  hooks('HOOKS'),
  commands('COMMANDS'),
  sessions('SESSIONS'),
  unknown('UNKNOWN');

  const ExternalAgentConfigMigrationItemType(this.wireName);

  final String wireName;

  static ExternalAgentConfigMigrationItemType fromWireName(String value) {
    return ExternalAgentConfigMigrationItemType.values.firstWhere(
      (candidate) => candidate.wireName == value,
      orElse: () => ExternalAgentConfigMigrationItemType.unknown,
    );
  }
}

class ExternalAgentConfigMigrationItem {
  const ExternalAgentConfigMigrationItem({
    required this.type,
    required this.rawType,
    required this.description,
    required this.raw,
    this.cwd,
    this.detailCount = 0,
  });

  static ExternalAgentConfigMigrationItem? fromJson(Object? value) {
    final raw = _objectMap(value);
    final rawType = _stringValue(raw['itemType']);
    final description = _stringValue(raw['description']);
    if (rawType == null || description == null) {
      return null;
    }
    return ExternalAgentConfigMigrationItem(
      type: ExternalAgentConfigMigrationItemType.fromWireName(rawType),
      rawType: rawType,
      description: description,
      cwd: _stringValue(raw['cwd']),
      detailCount: _migrationDetailCount(raw['details']),
      raw: raw,
    );
  }

  final ExternalAgentConfigMigrationItemType type;
  final String rawType;
  final String description;
  final String? cwd;
  final int detailCount;
  final Map<String, Object?> raw;

  Map<String, Object?> toJson() => Map<String, Object?>.from(raw);
}

class ExternalAgentConfigDetection {
  const ExternalAgentConfigDetection({required this.items});

  factory ExternalAgentConfigDetection.fromJson(Map<String, Object?> json) {
    return ExternalAgentConfigDetection(
      items: _list(json['items'])
          .map(ExternalAgentConfigMigrationItem.fromJson)
          .nonNulls
          .toList(growable: false),
    );
  }

  final List<ExternalAgentConfigMigrationItem> items;
}

class ExternalAgentConfigImportStart {
  const ExternalAgentConfigImportStart({
    required this.importId,
    required this.raw,
  });

  factory ExternalAgentConfigImportStart.fromJson(Map<String, Object?> json) {
    final importId = _stringValue(json['importId']);
    if (importId == null) {
      throw const FormatException(
        'externalAgentConfig/import response is missing importId',
      );
    }
    return ExternalAgentConfigImportStart(
      importId: importId,
      raw: Map.unmodifiable(json),
    );
  }

  final String importId;
  final Map<String, Object?> raw;
}

class ExternalAgentConfigImportHistory {
  const ExternalAgentConfigImportHistory({
    required this.importId,
    required this.completedAtMs,
    required this.successes,
    required this.failures,
    required this.raw,
  });

  static ExternalAgentConfigImportHistory? fromJson(Object? value) {
    final raw = _objectMap(value);
    final importId = _stringValue(raw['importId']);
    final completedAtMs = _intValue(raw['completedAtMs']);
    if (importId == null || completedAtMs == null) {
      return null;
    }
    return ExternalAgentConfigImportHistory(
      importId: importId,
      completedAtMs: completedAtMs,
      successes: _list(raw['successes'])
          .map(ExternalAgentConfigImportSuccess.fromJson)
          .nonNulls
          .toList(growable: false),
      failures: _list(raw['failures'])
          .map(ExternalAgentConfigImportFailure.fromJson)
          .nonNulls
          .toList(growable: false),
      raw: raw,
    );
  }

  final String importId;
  final int completedAtMs;
  final List<ExternalAgentConfigImportSuccess> successes;
  final List<ExternalAgentConfigImportFailure> failures;
  final Map<String, Object?> raw;

  int get successCount => successes.length;

  int get failureCount => failures.length;
}

class ExternalAgentConfigImportSuccess {
  const ExternalAgentConfigImportSuccess({
    required this.type,
    required this.rawType,
    required this.raw,
    this.cwd,
    this.source,
    this.target,
  });

  static ExternalAgentConfigImportSuccess? fromJson(Object? value) {
    final raw = _objectMap(value);
    final rawType = _stringValue(raw['itemType']);
    if (rawType == null) {
      return null;
    }
    return ExternalAgentConfigImportSuccess(
      type: ExternalAgentConfigMigrationItemType.fromWireName(rawType),
      rawType: rawType,
      cwd: _stringValue(raw['cwd']),
      source: _stringValue(raw['source']),
      target: _stringValue(raw['target']),
      raw: raw,
    );
  }

  final ExternalAgentConfigMigrationItemType type;
  final String rawType;
  final String? cwd;
  final String? source;
  final String? target;
  final Map<String, Object?> raw;

  String get identity => [rawType, cwd, source, target].join('\u0000');
}

class ExternalAgentConfigImportFailure {
  const ExternalAgentConfigImportFailure({
    required this.type,
    required this.rawType,
    required this.failureStage,
    required this.message,
    required this.raw,
    this.errorType,
    this.cwd,
    this.source,
  });

  static ExternalAgentConfigImportFailure? fromJson(Object? value) {
    final raw = _objectMap(value);
    final rawType = _stringValue(raw['itemType']);
    final message = _stringValue(raw['message']);
    if (rawType == null || message == null) {
      return null;
    }
    return ExternalAgentConfigImportFailure(
      type: ExternalAgentConfigMigrationItemType.fromWireName(rawType),
      rawType: rawType,
      errorType: _stringValue(raw['errorType']),
      failureStage: _stringValue(raw['failureStage']) ?? 'unknown',
      message: message,
      cwd: _stringValue(raw['cwd']),
      source: _stringValue(raw['source']),
      raw: raw,
    );
  }

  final ExternalAgentConfigMigrationItemType type;
  final String rawType;
  final String? errorType;
  final String failureStage;
  final String message;
  final String? cwd;
  final String? source;
  final Map<String, Object?> raw;

  String get identity =>
      [rawType, errorType, failureStage, message, cwd, source].join('\u0000');
}

class ExternalAgentConfigImportTypeResult {
  const ExternalAgentConfigImportTypeResult({
    required this.type,
    required this.rawType,
    required this.successes,
    required this.failures,
    required this.raw,
  });

  static ExternalAgentConfigImportTypeResult? fromJson(Object? value) {
    final raw = _objectMap(value);
    final rawType = _stringValue(raw['itemType']);
    if (rawType == null) {
      return null;
    }
    return ExternalAgentConfigImportTypeResult(
      type: ExternalAgentConfigMigrationItemType.fromWireName(rawType),
      rawType: rawType,
      successes: _list(raw['successes'])
          .map(ExternalAgentConfigImportSuccess.fromJson)
          .nonNulls
          .toList(growable: false),
      failures: _list(raw['failures'])
          .map(ExternalAgentConfigImportFailure.fromJson)
          .nonNulls
          .toList(growable: false),
      raw: raw,
    );
  }

  final ExternalAgentConfigMigrationItemType type;
  final String rawType;
  final List<ExternalAgentConfigImportSuccess> successes;
  final List<ExternalAgentConfigImportFailure> failures;
  final Map<String, Object?> raw;
}

class ExternalAgentConfigImportUpdate {
  const ExternalAgentConfigImportUpdate({
    required this.importId,
    required this.results,
  });

  static ExternalAgentConfigImportUpdate? fromJson(Object? value) {
    final raw = _objectMap(value);
    final importId = _stringValue(raw['importId']);
    if (importId == null) {
      return null;
    }
    return ExternalAgentConfigImportUpdate(
      importId: importId,
      results: _list(raw['itemTypeResults'])
          .map(ExternalAgentConfigImportTypeResult.fromJson)
          .nonNulls
          .toList(growable: false),
    );
  }

  final String importId;
  final List<ExternalAgentConfigImportTypeResult> results;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}

List<Object?> _list(Object? value) => value is List ? value : const [];

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
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

int _migrationDetailCount(Object? value) {
  final details = _objectMap(value);
  var count = 0;
  for (final entry in details.values) {
    if (entry is List) {
      count += entry.length;
    }
  }
  return count;
}
