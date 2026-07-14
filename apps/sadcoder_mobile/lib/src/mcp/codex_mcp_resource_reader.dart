import '../protocol/codex_app_server_client.dart';
import 'mcp_resource_reader.dart';

class CodexMcpResourceReader implements McpResourceReader {
  const CodexMcpResourceReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<McpResourceReadResult> readResource({
    String? threadId,
    required String server,
    required String uri,
  }) async {
    final result = await _client.readMcpResource(
      threadId: threadId,
      server: server,
      uri: uri,
    );
    return McpResourceReadResult.fromJson(result);
  }
}
