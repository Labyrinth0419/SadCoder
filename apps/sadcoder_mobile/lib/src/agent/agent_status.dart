enum BackendKind {
  sadcoderAgentService,
  codexAppServerStdio,
  codexAppServerDaemon,
  unknown;

  static BackendKind fromWire(String value) => switch (value) {
    'sadcoder-agent-service' => BackendKind.sadcoderAgentService,
    'codex-app-server-stdio' => BackendKind.codexAppServerStdio,
    'codex-app-server-daemon' => BackendKind.codexAppServerDaemon,
    _ => BackendKind.unknown,
  };
}

enum BackendState {
  ready,
  notStarted,
  unavailable;

  static BackendState fromWire(String value) => switch (value) {
    'ready' => BackendState.ready,
    'not-started' => BackendState.notStarted,
    _ => BackendState.unavailable,
  };
}

class AgentStatus {
  const AgentStatus({
    required this.agentVersion,
    required this.platformOs,
    required this.platformArch,
    required this.codexPath,
    required this.codexAvailable,
    required this.backendKind,
    required this.backendState,
    this.codexVersion,
    this.codexFailure,
    this.backendDetail,
    this.reconnectCache = const AgentReconnectCacheStatus(),
  });

  factory AgentStatus.fromJson(Map<String, Object?> json) {
    final backend = _stringKeyedMap(json['backend']);
    return AgentStatus(
      agentVersion:
          _stringField(json, ['agentVersion', 'agent_version']) ?? 'unknown',
      platformOs:
          _stringField(json, ['platformOs', 'platform_os']) ?? 'unknown',
      platformArch:
          _stringField(json, ['platformArch', 'platform_arch']) ?? 'unknown',
      codexPath: _stringField(json, ['codexPath', 'codex_path']) ?? 'codex',
      codexAvailable:
          _boolField(json, ['codexAvailable', 'codex_available']) ?? false,
      codexVersion: _stringField(json, ['codexVersion', 'codex_version']),
      codexFailure: AgentCodexFailure.fromJsonOrNull(
        _stringKeyedMap(_valueField(json, ['codexFailure', 'codex_failure'])),
      ),
      backendKind: BackendKind.fromWire(_stringValue(backend['kind']) ?? ''),
      backendState: BackendState.fromWire(_stringValue(backend['state']) ?? ''),
      backendDetail: _stringValue(backend['detail']),
      reconnectCache: AgentReconnectCacheStatus.fromJson(
        _stringKeyedMap(
          _valueField(json, ['reconnectCache', 'reconnect_cache']),
        ),
      ),
    );
  }

  final String agentVersion;
  final String platformOs;
  final String platformArch;
  final String codexPath;
  final bool codexAvailable;
  final String? codexVersion;
  final AgentCodexFailure? codexFailure;
  final BackendKind backendKind;
  final BackendState backendState;
  final String? backendDetail;
  final AgentReconnectCacheStatus reconnectCache;
}

class AgentStopResult {
  const AgentStopResult({
    required this.stopped,
    required this.backendKind,
    required this.backendState,
    this.backendDetail,
  });

  factory AgentStopResult.fromJson(Map<String, Object?> json) {
    final backend = _stringKeyedMap(json['backend']);
    return AgentStopResult(
      stopped: _boolField(json, ['stopped']) ?? false,
      backendKind: BackendKind.fromWire(_stringValue(backend['kind']) ?? ''),
      backendState: BackendState.fromWire(_stringValue(backend['state']) ?? ''),
      backendDetail: _stringValue(backend['detail']),
    );
  }

  final bool stopped;
  final BackendKind backendKind;
  final BackendState backendState;
  final String? backendDetail;
}

class AgentCodexFailure {
  const AgentCodexFailure({required this.kind, required this.detail});

  factory AgentCodexFailure.fromJson(Map<String, Object?> json) {
    return AgentCodexFailure(
      kind: _stringField(json, ['kind']) ?? 'unknown',
      detail: _stringField(json, ['detail']) ?? '',
    );
  }

  static AgentCodexFailure? fromJsonOrNull(Map<String, Object?> json) {
    if (json.isEmpty) {
      return null;
    }
    return AgentCodexFailure.fromJson(json);
  }

  final String kind;
  final String detail;

  String get message {
    final trimmedDetail = detail.trim();
    if (trimmedDetail.isEmpty) {
      return kind;
    }
    return '$kind: $trimmedDetail';
  }
}

class AgentReconnectCacheStatus {
  const AgentReconnectCacheStatus({
    this.statePath = '',
    this.schemaVersion = 1,
    this.pendingApprovals = 0,
    this.recentEvents = 0,
    this.deliveredCursor,
    this.loadError,
  });

  factory AgentReconnectCacheStatus.fromJson(Map<String, Object?> json) {
    return AgentReconnectCacheStatus(
      statePath: _stringField(json, ['statePath', 'state_path']) ?? '',
      schemaVersion: _intField(json, ['schemaVersion', 'schema_version']) ?? 1,
      pendingApprovals:
          _intField(json, ['pendingApprovals', 'pending_approvals']) ?? 0,
      recentEvents: _intField(json, ['recentEvents', 'recent_events']) ?? 0,
      deliveredCursor: _stringField(json, [
        'deliveredCursor',
        'delivered_cursor',
      ]),
      loadError: _stringField(json, ['loadError', 'load_error']),
    );
  }

  final String statePath;
  final int schemaVersion;
  final int pendingApprovals;
  final int recentEvents;
  final String? deliveredCursor;
  final String? loadError;
}

Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
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

bool? _boolValue(Object? value) {
  return value is bool ? value : null;
}

bool? _boolField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _boolValue(map[key]);
    if (value != null) {
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
