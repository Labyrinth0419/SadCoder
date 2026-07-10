import '../protocol/codex_app_server_client.dart';
import 'mcp_server_oauth_runner.dart';

class CodexMcpServerOAuthRunner implements McpServerOAuthRunner {
  const CodexMcpServerOAuthRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<McpServerOAuthLoginResult> startOAuthLogin({
    required String serverName,
  }) async {
    final normalized = serverName.trim();
    final result = await _client.startMcpServerOAuthLogin(
      serverName: normalized,
    );
    return McpServerOAuthLoginResult.fromJson(
      serverName: normalized,
      json: result,
    );
  }
}
