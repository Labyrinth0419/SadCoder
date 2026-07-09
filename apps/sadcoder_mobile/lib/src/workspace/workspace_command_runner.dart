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
      exitCode: json['exitCode'] as int? ?? -1,
      stdout: json['stdout'] as String? ?? '',
      stderr: json['stderr'] as String? ?? '',
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
