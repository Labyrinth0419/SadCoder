import 'dart:convert';

import '../commands/slash_command_registry.dart';
import '../ssh/remote_command_runner.dart';
import '../ssh/ssh_profile.dart';
import 'agent_snapshot.dart';
import 'agent_snapshot_reader.dart';
import 'agent_status.dart';

abstract interface class AgentStatusReader {
  Future<AgentStatus> readStatus(SshProfile profile);
}

class AgentRemoteService implements AgentStatusReader, AgentSnapshotReader {
  const AgentRemoteService(this._runner);

  final RemoteCommandRunner _runner;

  @override
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

  Future<SlashCommandManifest> readSlashCommands(SshProfile profile) async {
    final result = await _runner.run(
      profile,
      '${profile.agentCommand} slash-commands --json',
      timeout: const Duration(seconds: 20),
    );

    if (!result.succeeded) {
      throw RemoteCommandException(
        'Slash command manifest failed with exit code ${result.exitCode}: ${result.stderr}',
      );
    }

    final decoded = jsonDecode(result.stdout);
    if (decoded is! Map<String, Object?>) {
      throw const RemoteCommandException(
        'Slash command manifest did not return a JSON object.',
      );
    }
    return SlashCommandManifest.fromJson(decoded);
  }

  @override
  Future<AgentSnapshot> readSnapshot(SshProfile profile) async {
    final result = await _runner.run(
      profile,
      '${profile.agentCommand} snapshot --json',
      timeout: const Duration(seconds: 20),
    );

    if (!result.succeeded) {
      throw RemoteCommandException(
        'Agent snapshot failed with exit code ${result.exitCode}: ${result.stderr}',
      );
    }

    final decoded = jsonDecode(result.stdout);
    if (decoded is! Map<String, Object?>) {
      throw const RemoteCommandException(
        'Agent snapshot did not return a JSON object.',
      );
    }
    return AgentSnapshot.fromJson(decoded);
  }
}
