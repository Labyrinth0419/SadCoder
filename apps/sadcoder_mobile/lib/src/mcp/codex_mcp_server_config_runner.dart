import '../protocol/codex_app_server_client.dart';
import 'mcp_server_config_runner.dart';

class CodexMcpServerConfigRunner implements McpServerConfigRunner {
  const CodexMcpServerConfigRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<void> reloadMcpServers() async {
    await _client.reloadMcpServers();
  }
}
