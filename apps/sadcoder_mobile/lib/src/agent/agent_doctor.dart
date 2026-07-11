import 'agent_status.dart';

class AgentDoctorResult {
  const AgentDoctorResult({
    required this.configPath,
    required this.codex,
    required this.status,
  });

  factory AgentDoctorResult.fromJson(Map<String, Object?> json) {
    return AgentDoctorResult(
      configPath: _stringField(json, ['configPath', 'config_path']) ?? '',
      codex: AgentCodexCommandDiagnostic.fromJson(
        _stringKeyedMap(_valueField(json, ['codex'])),
      ),
      status: AgentStatus.fromJson(
        _stringKeyedMap(_valueField(json, ['status'])),
      ),
    );
  }

  final String configPath;
  final AgentCodexCommandDiagnostic codex;
  final AgentStatus status;
}

class AgentCodexCommandDiagnostic {
  const AgentCodexCommandDiagnostic({
    required this.program,
    required this.args,
    required this.pathPrepend,
    required this.source,
    required this.available,
    this.version,
    this.failure,
  });

  factory AgentCodexCommandDiagnostic.fromJson(Map<String, Object?> json) {
    return AgentCodexCommandDiagnostic(
      program: _stringField(json, ['program']) ?? 'codex',
      args: _stringList(_valueField(json, ['args'])),
      pathPrepend: _stringList(
        _valueField(json, ['pathPrepend', 'path_prepend']),
      ),
      source: _stringField(json, ['source']) ?? 'unknown',
      available: _boolField(json, ['available']) ?? false,
      version: _stringField(json, ['version']),
      failure: AgentCodexFailure.fromJsonOrNull(
        _stringKeyedMap(_valueField(json, ['failure'])),
      ),
    );
  }

  final String program;
  final List<String> args;
  final List<String> pathPrepend;
  final String source;
  final bool available;
  final String? version;
  final AgentCodexFailure? failure;
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

bool? _boolField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) {
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

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(
    value.whereType<String>().where((item) => item.trim().isNotEmpty),
  );
}
