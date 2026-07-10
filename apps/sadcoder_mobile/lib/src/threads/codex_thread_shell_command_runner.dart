import '../protocol/codex_app_server_client.dart';
import 'thread_shell_command_runner.dart';

class CodexThreadShellCommandRunner implements ThreadShellCommandRunner {
  const CodexThreadShellCommandRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<void> runShellCommand({
    required String threadId,
    required String command,
  }) async {
    final normalizedThreadId = threadId.trim();
    final normalizedCommand = command.trim();
    if (normalizedThreadId.isEmpty) {
      throw ArgumentError.value(threadId, 'threadId', 'must not be empty');
    }
    if (normalizedCommand.isEmpty) {
      throw ArgumentError.value(command, 'command', 'must not be empty');
    }
    await _client.runThreadShellCommand(
      threadId: normalizedThreadId,
      command: normalizedCommand,
    );
  }
}
