import '../protocol/codex_app_server_client.dart';
import 'environment_runner.dart';

class CodexEnvironmentRunner implements EnvironmentRunner {
  const CodexEnvironmentRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<EnvironmentAddResult> addEnvironment({
    required String environmentId,
    required String execServerUrl,
    int? connectTimeoutMs,
  }) async {
    final result = await _client.addEnvironment(
      environmentId: environmentId,
      execServerUrl: execServerUrl,
      connectTimeoutMs: connectTimeoutMs,
    );
    return EnvironmentAddResult(raw: result);
  }

  @override
  Future<EnvironmentInfoResult> readEnvironmentInfo({
    required String environmentId,
  }) async {
    final result = await _client.readEnvironmentInfo(
      environmentId: environmentId,
    );
    final shell = _objectMap(result['shell']);
    return EnvironmentInfoResult(
      shell: EnvironmentShellInfo(
        name: _stringValue(shell['name']) ?? 'unknown',
        path: _stringValue(shell['path']) ?? '',
      ),
      cwd: _stringValue(result['cwd']),
      raw: result,
    );
  }

  @override
  Future<EnvironmentStatusResult> readEnvironmentStatus({
    required String environmentId,
  }) async {
    final result = await _client.readEnvironmentStatus(
      environmentId: environmentId,
    );
    return EnvironmentStatusResult(
      status: _statusFromWire(result['status']),
      error: _stringValue(result['error']),
      raw: result,
    );
  }
}

EnvironmentStatusKind _statusFromWire(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'ready' => EnvironmentStatusKind.ready,
    'pending' => EnvironmentStatusKind.pending,
    'disconnected' => EnvironmentStatusKind.disconnected,
    _ => EnvironmentStatusKind.unknown,
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

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
