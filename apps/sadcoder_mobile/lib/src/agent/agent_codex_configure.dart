import 'agent_doctor.dart';

class AgentCodexConfigureRequest {
  const AgentCodexConfigureRequest({
    required this.program,
    this.args = const [],
    this.pathPrepend = const [],
  });

  final String program;
  final List<String> args;
  final List<String> pathPrepend;
}

class AgentCodexConfigureResult {
  const AgentCodexConfigureResult({
    required this.configPath,
    required this.codex,
  });

  factory AgentCodexConfigureResult.fromJson(Map<String, Object?> json) {
    return AgentCodexConfigureResult(
      configPath: _stringField(json, ['configPath', 'config_path']) ?? '',
      codex: AgentCodexCommandDiagnostic.fromJson(
        _stringKeyedMap(_valueField(json, ['codex'])),
      ),
    );
  }

  final String configPath;
  final AgentCodexCommandDiagnostic codex;
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

Object? _valueField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value != null) {
      return value;
    }
  }
  return null;
}
