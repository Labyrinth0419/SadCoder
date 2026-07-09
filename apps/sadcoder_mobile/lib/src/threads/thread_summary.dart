class ThreadListPage {
  const ThreadListPage({
    required this.threads,
    this.nextCursor,
    this.backwardsCursor,
  });

  factory ThreadListPage.fromJson(Map<String, Object?> json) {
    return ThreadListPage(
      threads: _listOfMaps(
        json['data'],
      ).map(ThreadSummary.fromJson).toList(growable: false),
      nextCursor: json['nextCursor'] as String?,
      backwardsCursor: json['backwardsCursor'] as String?,
    );
  }

  final List<ThreadSummary> threads;
  final String? nextCursor;
  final String? backwardsCursor;
}

class ThreadSummary {
  const ThreadSummary({
    required this.id,
    required this.sessionId,
    required this.preview,
    required this.ephemeral,
    required this.status,
    required this.cwd,
    required this.updatedAtSeconds,
    this.name,
    this.parentThreadId,
    this.forkedFromId,
    this.agentNickname,
    this.agentRole,
    this.raw = const {},
  });

  factory ThreadSummary.fromJson(Map<String, Object?> json) {
    return ThreadSummary(
      id: _stringValue(json['id']) ?? '',
      sessionId: _stringValue(json['sessionId']) ?? '',
      preview: _stringValue(json['preview']) ?? '',
      ephemeral: _boolValue(json['ephemeral']) ?? false,
      status: _stringValue(json['status']) ?? 'unknown',
      cwd: _stringValue(json['cwd']) ?? '',
      updatedAtSeconds: _intValue(json['updatedAt']) ?? 0,
      name: _stringValue(json['name']),
      parentThreadId: _stringValue(json['parentThreadId']),
      forkedFromId: _stringValue(json['forkedFromId']),
      agentNickname: _stringValue(json['agentNickname']),
      agentRole: _stringValue(json['agentRole']),
      raw: Map.unmodifiable(json),
    );
  }

  final String id;
  final String sessionId;
  final String preview;
  final bool ephemeral;
  final String status;
  final String cwd;
  final int updatedAtSeconds;
  final String? name;
  final String? parentThreadId;
  final String? forkedFromId;
  final String? agentNickname;
  final String? agentRole;
  final Map<String, Object?> raw;

  String get title {
    final name = this.name;
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }
    if (preview.trim().isNotEmpty) {
      return preview;
    }
    return id;
  }

  bool get isSubagent => parentThreadId != null;
  bool get isFork => forkedFromId != null;
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

String? _stringValue(Object? value) => value is String ? value : null;

bool? _boolValue(Object? value) => value is bool ? value : null;

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
