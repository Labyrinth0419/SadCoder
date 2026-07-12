import '../protocol/codex_app_server_client.dart';
import '../ssh/ssh_profile.dart';
import 'agent_snapshot.dart';
import 'agent_snapshot_reader.dart';

class CodexAgentSnapshotReader implements AgentSnapshotReader {
  const CodexAgentSnapshotReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<AgentSnapshot> readSnapshot(
    SshProfile profile, {
    String? sinceCursor,
  }) async {
    return AgentSnapshot.fromJson(
      await _client.agentSnapshot(sinceCursor: sinceCursor),
    );
  }
}
