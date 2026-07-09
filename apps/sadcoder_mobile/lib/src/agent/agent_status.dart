enum BackendKind {
  codexAppServerStdio,
  codexAppServerDaemon,
  unknown;

  static BackendKind fromWire(String value) => switch (value) {
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
    this.backendDetail,
    this.reconnectCache = const AgentReconnectCacheStatus(),
  });

  factory AgentStatus.fromJson(Map<String, Object?> json) {
    final backend = _stringKeyedMap(json['backend']);
    return AgentStatus(
      agentVersion: json['agentVersion'] as String? ?? 'unknown',
      platformOs: json['platformOs'] as String? ?? 'unknown',
      platformArch: json['platformArch'] as String? ?? 'unknown',
      codexPath: json['codexPath'] as String? ?? 'codex',
      codexAvailable: json['codexAvailable'] as bool? ?? false,
      codexVersion: json['codexVersion'] as String?,
      backendKind: BackendKind.fromWire(backend['kind'] as String? ?? ''),
      backendState: BackendState.fromWire(backend['state'] as String? ?? ''),
      backendDetail: backend['detail'] as String?,
      reconnectCache: AgentReconnectCacheStatus.fromJson(
        _stringKeyedMap(json['reconnectCache']),
      ),
    );
  }

  final String agentVersion;
  final String platformOs;
  final String platformArch;
  final String codexPath;
  final bool codexAvailable;
  final String? codexVersion;
  final BackendKind backendKind;
  final BackendState backendState;
  final String? backendDetail;
  final AgentReconnectCacheStatus reconnectCache;
}

class AgentReconnectCacheStatus {
  const AgentReconnectCacheStatus({
    this.statePath = '',
    this.schemaVersion = 1,
    this.pendingApprovals = 0,
    this.recentEvents = 0,
    this.loadError,
  });

  factory AgentReconnectCacheStatus.fromJson(Map<String, Object?> json) {
    return AgentReconnectCacheStatus(
      statePath: json['statePath'] as String? ?? '',
      schemaVersion: _intValue(json['schemaVersion']) ?? 1,
      pendingApprovals: _intValue(json['pendingApprovals']) ?? 0,
      recentEvents: _intValue(json['recentEvents']) ?? 0,
      loadError: json['loadError'] as String?,
    );
  }

  final String statePath;
  final int schemaVersion;
  final int pendingApprovals;
  final int recentEvents;
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

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
