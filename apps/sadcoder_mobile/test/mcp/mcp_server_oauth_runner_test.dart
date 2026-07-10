import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/mcp/codex_mcp_server_oauth_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('startOAuthLogin starts MCP OAuth login', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'serverName': 'github',
        'authorizationUrl': 'https://example.test/oauth',
        'userCode': 'ABCD-1234',
      };
    });
    final runner = CodexMcpServerOAuthRunner(CodexAppServerClient(transport));

    final result = await runner.startOAuthLogin(serverName: ' github ');

    expect(result.serverName, 'github');
    expect(result.bestUrl, 'https://example.test/oauth');
    expect(result.userCode, 'ABCD-1234');
    expect(requests.single.method, 'mcpServer/oauth/login');
    expect(requests.single.params, {'serverName': 'github'});
  });
}
