import '../protocol/codex_app_server_client.dart';
import '../ssh/ssh_profile.dart';
import 'agent_logs.dart';
import 'agent_logs_reader.dart';

class CodexAgentLogsReader implements AgentLogsReader {
  const CodexAgentLogsReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<AgentLogsResult> readLogs(SshProfile profile, {int? tailBytes}) async {
    return AgentLogsResult.fromJson(
      await _client.agentLogs(tailBytes: tailBytes),
    );
  }
}
