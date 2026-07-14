abstract interface class EnvironmentRunner {
  Future<EnvironmentAddResult> addEnvironment({
    required String environmentId,
    required String execServerUrl,
    int? connectTimeoutMs,
  });

  Future<EnvironmentInfoResult> readEnvironmentInfo({
    required String environmentId,
  });

  Future<EnvironmentStatusResult> readEnvironmentStatus({
    required String environmentId,
  });
}

class EnvironmentAddResult {
  const EnvironmentAddResult({required this.raw});

  final Map<String, Object?> raw;
}

enum EnvironmentStatusKind { ready, pending, disconnected, unknown }

class EnvironmentStatusResult {
  const EnvironmentStatusResult({
    required this.status,
    required this.error,
    required this.raw,
  });

  final EnvironmentStatusKind status;
  final String? error;
  final Map<String, Object?> raw;
}

class EnvironmentInfoResult {
  const EnvironmentInfoResult({
    required this.shell,
    required this.cwd,
    required this.raw,
  });

  final EnvironmentShellInfo shell;
  final String? cwd;
  final Map<String, Object?> raw;
}

class EnvironmentShellInfo {
  const EnvironmentShellInfo({required this.name, required this.path});

  final String name;
  final String path;
}
