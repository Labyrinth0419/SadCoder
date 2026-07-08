import 'dart:convert';

import '../ssh/remote_command_runner.dart';
import '../ssh/ssh_profile.dart';
import 'agent_status.dart';

class AgentRemoteService {
  const AgentRemoteService(this._runner);

  final RemoteCommandRunner _runner;

  Future<AgentStatus> readStatus(SshProfile profile) async {
    final result = await _runner.run(
      profile,
      '${profile.agentCommand} status --json',
      timeout: const Duration(seconds: 20),
    );

    if (!result.succeeded) {
      throw RemoteCommandException(
        'Agent status failed with exit code ${result.exitCode}: ${result.stderr}',
      );
    }

    final decoded = jsonDecode(result.stdout);
    if (decoded is! Map<String, Object?>) {
      throw const RemoteCommandException(
        'Agent status did not return a JSON object.',
      );
    }
    return AgentStatus.fromJson(decoded);
  }
}
