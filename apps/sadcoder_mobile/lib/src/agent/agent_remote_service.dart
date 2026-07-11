import 'dart:convert';

import '../commands/slash_command_manifest_reader.dart';
import '../commands/slash_command_registry.dart';
import '../ssh/remote_command_runner.dart';
import '../ssh/ssh_profile.dart';
import 'agent_doctor.dart';
import 'agent_doctor_reader.dart';
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
        AgentDoctorReader,
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
    return AgentStatus.fromJson(
      await _readJsonObjectCommand(
        profile,
        command,
        failurePrefix: failurePrefix,
        invalidJsonMessage: 'Agent command did not return a JSON object.',
        timeout: timeout,
      ),
    );
  }

  @override
  Future<AgentDoctorResult> readDoctor(SshProfile profile) async {
    final json = await _readJsonObjectCommand(
      profile,
      '${profile.agentCommand} doctor --json',
      failurePrefix: 'Agent doctor',
      invalidJsonMessage: 'Agent doctor did not return a JSON object.',
      timeout: const Duration(seconds: 20),
    );
    return AgentDoctorResult.fromJson(json);
  }

  @override
  Future<SlashCommandManifest> readSlashCommands(SshProfile profile) async {
    final decoded = await _readJsonObjectCommand(
      profile,
      '${profile.agentCommand} slash-commands --json',
      failurePrefix: 'Slash command manifest',
      invalidJsonMessage:
          'Slash command manifest did not return a JSON object.',
      timeout: const Duration(seconds: 20),
    );
    return SlashCommandManifest.fromJson(decoded);
  }

  @override
  Future<AgentSnapshot> readSnapshot(SshProfile profile) async {
    final decoded = await _readJsonObjectCommand(
      profile,
      '${profile.agentCommand} snapshot --json',
      failurePrefix: 'Agent snapshot',
      invalidJsonMessage: 'Agent snapshot did not return a JSON object.',
      timeout: const Duration(seconds: 20),
    );
    return AgentSnapshot.fromJson(decoded);
  }

  Future<Map<String, Object?>> _readJsonObjectCommand(
    SshProfile profile,
    String command, {
    required String failurePrefix,
    required String invalidJsonMessage,
    required Duration timeout,
  }) async {
    final result = await _runner.run(profile, command, timeout: timeout);

    if (!result.succeeded) {
      throw RemoteCommandException(
        '$failurePrefix failed with exit code ${result.exitCode}: ${result.stderr}',
      );
    }

    final decoded = jsonDecode(result.stdout);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    throw RemoteCommandException(invalidJsonMessage);
  }
}
