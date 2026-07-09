import '../protocol/codex_app_server_client.dart';
import 'mcp_server_status_reader.dart';

class CodexMcpServerStatusReader implements McpServerStatusReader {
  const CodexMcpServerStatusReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<McpServerStatusPage> listMcpServers({
    String? threadId,
    String? cursor,
    int? limit,
    McpServerStatusDetail detail = McpServerStatusDetail.toolsAndAuthOnly,
  }) async {
    final result = await _client.listMcpServerStatus(
      threadId: threadId,
      cursor: cursor,
      limit: limit,
      detail: detail.wireName,
    );
    return McpServerStatusPage.fromJson(result);
  }
}
