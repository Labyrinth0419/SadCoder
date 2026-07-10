class WorkspaceCommand {
  const WorkspaceCommand({
    required this.command,
    this.cwd,
    this.env = const {},
    this.timeoutMs,
    this.outputBytesCap,
    this.disableOutputCap = false,
  });

  final List<String> command;
  final String? cwd;
  final Map<String, String?> env;
  final int? timeoutMs;
  final int? outputBytesCap;
  final bool disableOutputCap;
}

class WorkspaceCommandResult {
  const WorkspaceCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  factory WorkspaceCommandResult.fromJson(Map<String, Object?> json) {
    return WorkspaceCommandResult(
      exitCode: _intValue(json['exitCode'] ?? json['exit_code']) ?? -1,
      stdout: _stringValue(json['stdout'] ?? json['stdOut'] ?? json['std_out']),
      stderr: _stringValue(json['stderr'] ?? json['stdErr'] ?? json['std_err']),
    );
  }

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get success => exitCode == 0;
}

abstract interface class WorkspaceCommandRunner {
  Future<WorkspaceCommandResult> runCommand(WorkspaceCommand command);
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

String _stringValue(Object? value) => value is String ? value : '';
