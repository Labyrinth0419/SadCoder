import '../protocol/codex_app_server_client.dart';
import '../ssh/ssh_profile.dart';
import 'agent_schema.dart';
import 'agent_schema_reader.dart';

class CodexAgentSchemaReader implements AgentSchemaReader {
  const CodexAgentSchemaReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<AgentSchemaResult> readSchema(
    SshProfile profile, {
    bool refresh = false,
    bool experimental = false,
  }) async {
    return AgentSchemaResult.fromJson(
      await _client.agentSchema(refresh: refresh, experimental: experimental),
    );
  }
}
