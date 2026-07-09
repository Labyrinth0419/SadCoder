import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/mcp/codex_mcp_server_status_reader.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('McpServerStatusPage parses server inventory payloads', () {
    final page = McpServerStatusPage.fromJson({
      'data': [
        {
          'name': 'github',
          'authStatus': 'oAuth',
          'serverInfo': {
            'name': 'github-mcp',
            'version': '1.2.3',
            'title': 'GitHub MCP',
            'description': 'GitHub tools',
            'websiteUrl': 'https://github.com',
          },
          'tools': {
            'search_issues': {
              'name': 'search_issues',
              'title': 'Search issues',
              'description': 'Search repository issues',
            },
          },
          'resources': [
            {
              'name': 'readme',
              'title': 'README',
              'uri': 'repo://readme',
              'mimeType': 'text/markdown',
            },
          ],
          'resourceTemplates': [
            {
              'name': 'repo_file',
              'title': 'Repository file',
              'uriTemplate': 'repo://{owner}/{repo}/{path}',
            },
          ],
        },
        {'authStatus': 'unsupported'},
      ],
      'nextCursor': 'cursor_2',
    });

    expect(page.nextCursor, 'cursor_2');
    expect(page.servers, hasLength(1));

    final server = page.servers.single;
    expect(server.name, 'github');
    expect(server.displayName, 'GitHub MCP');
    expect(server.authStatus, 'oAuth');
    expect(server.serverInfo?.version, '1.2.3');
    expect(server.tools['search_issues']?.label, 'Search issues');
    expect(server.resources.single.label, 'README');
    expect(server.resources.single.uri, 'repo://readme');
    expect(server.resourceTemplates.single.uriTemplate, contains('{path}'));
  });

  test('CodexMcpServerStatusReader calls app-server status list', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'data': [
          {'name': 'filesystem', 'authStatus': 'unsupported'},
        ],
        'nextCursor': null,
      };
    });
    final reader = CodexMcpServerStatusReader(CodexAppServerClient(transport));

    final page = await reader.listMcpServers(
      threadId: 'thr_1',
      cursor: 'cursor_1',
      limit: 25,
      detail: McpServerStatusDetail.toolsAndAuthOnly,
    );

    expect(page.servers.single.name, 'filesystem');
    expect(requests.single.method, 'mcpServerStatus/list');
    expect(requests.single.params, {
      'threadId': 'thr_1',
      'cursor': 'cursor_1',
      'limit': 25,
      'detail': 'toolsAndAuthOnly',
    });
  });
}
