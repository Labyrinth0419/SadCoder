import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/mcp/codex_mcp_server_config_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('reloadMcpServers reloads MCP server configuration', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });
    final runner = CodexMcpServerConfigRunner(CodexAppServerClient(transport));

    await runner.reloadMcpServers();

    expect(requests.single.method, 'config/mcpServer/reload');
    expect(requests.single.params, isNull);
  });
}
