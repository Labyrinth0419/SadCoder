import 'dart:convert';

import '../commands/slash_command_manifest_reader.dart';
import '../commands/slash_command_registry.dart';
import '../ssh/remote_command_runner.dart';
import '../ssh/ssh_profile.dart';
import 'agent_snapshot.dart';
import 'agent_snapshot_reader.dart';
import 'agent_status.dart';

abstract interface class AgentStatusReader {
  Future<AgentStatus> readStatus(SshProfile profile);
}

abstract interface class AgentStartRunner {
  Future<AgentStatus> start(SshProfile profile);
}

class AgentRemoteService
    implements
        AgentStatusReader,
        AgentStartRunner,
        AgentSnapshotReader,
        SlashCommandManifestReader {
  const AgentRemoteService(this._runner);

  final RemoteCommandRunner _runner;

  @override
  Future<AgentStatus> readStatus(SshProfile profile) async {
    return _readStatusCommand(
      profile,
      '${profile.agentCommand} status --json',
      failurePrefix: 'Agent status',
    );
  }

  @override
  Future<AgentStatus> start(SshProfile profile) {
    return _readStatusCommand(
      profile,
      '${profile.agentCommand} start --json',
      failurePrefix: 'Agent start',
      timeout: const Duration(seconds: 60),
    );
  }

  Future<AgentStatus> _readStatusCommand(
    SshProfile profile,
    String command, {
    required String failurePrefix,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final result = await _runner.run(profile, command, timeout: timeout);

    if (!result.succeeded) {
      throw RemoteCommandException(
        '$failurePrefix failed with exit code ${result.exitCode}: ${result.stderr}',
      );
    }

    final decoded = jsonDecode(result.stdout);
    if (decoded is! Map<String, Object?>) {
      throw const RemoteCommandException(
        'Agent command did not return a JSON object.',
      );
    }
    return AgentStatus.fromJson(decoded);
  }

  @override
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
