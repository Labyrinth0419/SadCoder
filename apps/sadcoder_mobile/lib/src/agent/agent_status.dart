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
  });

  factory AgentStatus.fromJson(Map<String, Object?> json) {
    final backend = json['backend'] as Map<String, Object?>? ?? const {};
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
}
