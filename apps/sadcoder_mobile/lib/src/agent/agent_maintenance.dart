import '../ssh/ssh_profile.dart';
import '../ssh/remote_command_runner.dart';

enum AgentMaintenanceOperation {
  doctor,
  update,
  apply,
  cloudList,
  cloudStatus,
  cloudDiff,
  cloudApply,
}

class AgentMaintenanceRequest {
  const AgentMaintenanceRequest._({
    required this.operation,
    this.taskId,
    this.environment,
    this.limit = 20,
    this.cursor,
    this.attempt,
    this.cwd,
  });

  const AgentMaintenanceRequest.doctor()
    : this._(operation: AgentMaintenanceOperation.doctor);

  const AgentMaintenanceRequest.update()
    : this._(operation: AgentMaintenanceOperation.update);

  const AgentMaintenanceRequest.apply({required String taskId, String? cwd})
    : this._(
        operation: AgentMaintenanceOperation.apply,
        taskId: taskId,
        cwd: cwd,
      );

  const AgentMaintenanceRequest.cloudList({
    String? environment,
    int limit = 20,
    String? cursor,
  }) : this._(
         operation: AgentMaintenanceOperation.cloudList,
         environment: environment,
         limit: limit,
         cursor: cursor,
       );

  const AgentMaintenanceRequest.cloudStatus({required String taskId})
    : this._(operation: AgentMaintenanceOperation.cloudStatus, taskId: taskId);

  const AgentMaintenanceRequest.cloudDiff({
    required String taskId,
    int? attempt,
  }) : this._(
         operation: AgentMaintenanceOperation.cloudDiff,
         taskId: taskId,
         attempt: attempt,
       );

  const AgentMaintenanceRequest.cloudApply({
    required String taskId,
    int? attempt,
    String? cwd,
  }) : this._(
         operation: AgentMaintenanceOperation.cloudApply,
         taskId: taskId,
         attempt: attempt,
         cwd: cwd,
       );

  final AgentMaintenanceOperation operation;
  final String? taskId;
  final String? environment;
  final int limit;
  final String? cursor;
  final int? attempt;
  final String? cwd;

  bool get isMutating => switch (operation) {
    AgentMaintenanceOperation.update ||
    AgentMaintenanceOperation.apply ||
    AgentMaintenanceOperation.cloudApply => true,
    _ => false,
  };

  bool get requiresChatGptAuth => switch (operation) {
    AgentMaintenanceOperation.cloudList ||
    AgentMaintenanceOperation.cloudStatus ||
    AgentMaintenanceOperation.cloudDiff ||
    AgentMaintenanceOperation.cloudApply => true,
    _ => false,
  };

  bool get restartRequired => operation == AgentMaintenanceOperation.update;

  String get label => switch (operation) {
    AgentMaintenanceOperation.doctor => 'doctor',
    AgentMaintenanceOperation.update => 'update',
    AgentMaintenanceOperation.apply => 'apply',
    AgentMaintenanceOperation.cloudList => 'cloud list',
    AgentMaintenanceOperation.cloudStatus => 'cloud status',
    AgentMaintenanceOperation.cloudDiff => 'cloud diff',
    AgentMaintenanceOperation.cloudApply => 'cloud apply',
  };

  String buildCommand(SshProfile profile) {
    final parts = <String>[profile.agentCommand, 'codex', '--json'];
    switch (operation) {
      case AgentMaintenanceOperation.doctor:
        parts.add('doctor');
      case AgentMaintenanceOperation.update:
        parts.add('update');
      case AgentMaintenanceOperation.apply:
        parts.addAll(['apply', _quoteRequired(taskId, 'task id')]);
        _appendCwd(parts);
      case AgentMaintenanceOperation.cloudList:
        parts.addAll(['cloud-list']);
        final environment = this.environment?.trim();
        if (environment != null && environment.isNotEmpty) {
          parts.addAll(['--env', _quote(environment)]);
        }
        parts.addAll(['--limit', _positiveInt(limit, 'limit').toString()]);
        final cursor = this.cursor?.trim();
        if (cursor != null && cursor.isNotEmpty) {
          parts.addAll(['--cursor', _quote(cursor)]);
        }
      case AgentMaintenanceOperation.cloudStatus:
        parts.addAll(['cloud-status', _quoteRequired(taskId, 'task id')]);
      case AgentMaintenanceOperation.cloudDiff:
        parts.addAll(['cloud-diff', _quoteRequired(taskId, 'task id')]);
        _appendAttempt(parts);
      case AgentMaintenanceOperation.cloudApply:
        parts.addAll(['cloud-apply', _quoteRequired(taskId, 'task id')]);
        _appendAttempt(parts);
        _appendCwd(parts);
    }
    return parts.join(' ');
  }

  void _appendAttempt(List<String> parts) {
    final attempt = this.attempt;
    if (attempt != null) {
      parts.addAll(['--attempt', _positiveInt(attempt, 'attempt').toString()]);
    }
  }

  void _appendCwd(List<String> parts) {
    final cwd = this.cwd?.trim();
    if (cwd != null && cwd.isNotEmpty) {
      parts.addAll(['--cwd', _quote(cwd)]);
    }
  }
}

class AgentMaintenanceResult {
  const AgentMaintenanceResult({
    required this.operation,
    required this.success,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.restartRequired,
    required this.requiresChatGptAuth,
  });

  factory AgentMaintenanceResult.fromJson(Map<String, Object?> json) {
    return AgentMaintenanceResult(
      operation: _string(json, 'operation') ?? 'unknown',
      success: _bool(json, 'success') ?? false,
      exitCode: _int(json, ['exitCode', 'exit_code']),
      stdout: _string(json, 'stdout') ?? '',
      stderr: _string(json, 'stderr') ?? '',
      restartRequired: _bool(json, 'restartRequired') ?? false,
      requiresChatGptAuth:
          _bool(json, 'requiresChatgptAuth') ??
          _bool(json, 'requiresChatGPTAuth') ??
          _bool(json, 'requires_chatgpt_auth') ??
          false,
    );
  }

  final String operation;
  final bool success;
  final int? exitCode;
  final String stdout;
  final String stderr;
  final bool restartRequired;
  final bool requiresChatGptAuth;
}

String _quoteRequired(String? value, String label) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    throw RemoteCommandException('$label is required.');
  }
  return _quote(trimmed);
}

String _quote(String value) {
  if (value.contains("'")) {
    throw const RemoteCommandException(
      'Remote command arguments containing single quotes are not supported.',
    );
  }
  return "'$value'";
}

int _positiveInt(int value, String label) {
  final max = label == 'limit' ? 20 : 4;
  if (value < 1 || value > max) {
    throw RemoteCommandException('$label must be between 1 and $max.');
  }
  return value;
}

String? _string(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

bool? _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is bool ? value : null;
}

int? _int(Map<String, Object?> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
  }
  return null;
}
