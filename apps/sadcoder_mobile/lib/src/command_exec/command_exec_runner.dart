import 'dart:typed_data';

import '../workspace/workspace_command_runner.dart';

class CommandExecRequest {
  const CommandExecRequest({
    required this.command,
    this.cwd,
    this.env = const {},
    this.tty = true,
    this.size,
    this.timeoutMs,
    this.disableTimeout = false,
    this.outputBytesCap,
    this.disableOutputCap = false,
    this.sandboxPolicy,
  });

  final List<String> command;
  final String? cwd;
  final Map<String, String?> env;
  final bool tty;
  final CommandExecTerminalSize? size;
  final int? timeoutMs;
  final bool disableTimeout;
  final int? outputBytesCap;
  final bool disableOutputCap;
  final Map<String, Object?>? sandboxPolicy;
}

class CommandExecTerminalSize {
  const CommandExecTerminalSize({required this.rows, required this.cols});

  final int rows;
  final int cols;

  Map<String, Object?> toJson() => {'rows': rows, 'cols': cols};
}

enum CommandExecOutputStream { stdout, stderr }

class CommandExecOutputChunk {
  const CommandExecOutputChunk({
    required this.processId,
    required this.stream,
    required this.bytes,
    required this.capReached,
  });

  final String processId;
  final CommandExecOutputStream stream;
  final Uint8List bytes;
  final bool capReached;
}

abstract interface class CommandExecSession {
  String get processId;

  Stream<CommandExecOutputChunk> get output;

  Future<WorkspaceCommandResult> get done;

  bool get isCompleted;

  Future<void> write(List<int> bytes, {bool closeStdin = false});

  Future<void> closeStdin();

  Future<void> resize(CommandExecTerminalSize size);

  Future<void> terminate();
}

abstract interface class CommandExecRunner {
  Future<CommandExecSession> start(CommandExecRequest request);
}
