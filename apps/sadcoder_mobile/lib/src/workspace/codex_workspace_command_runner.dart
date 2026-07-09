import '../protocol/codex_app_server_client.dart';
import 'workspace_command_runner.dart';

class CodexWorkspaceCommandRunner implements WorkspaceCommandRunner {
  const CodexWorkspaceCommandRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<WorkspaceCommandResult> runCommand(WorkspaceCommand command) async {
    final response = await _client.execCommand(
      command: command.command,
      cwd: command.cwd,
      env: command.env,
      timeoutMs: command.timeoutMs,
      outputBytesCap: command.outputBytesCap,
      disableOutputCap: command.disableOutputCap,
    );
    return WorkspaceCommandResult.fromJson(response);
  }
}
