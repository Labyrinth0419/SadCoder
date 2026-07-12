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

  test(
    'McpServerStatusPage upserts startup status without clearing inventory',
    () {
      final page = McpServerStatusPage.fromJson({
        'data': [
          {
            'name': 'github',
            'authStatus': 'oAuth',
            'tools': {
              'search_issues': {'name': 'search_issues', 'inputSchema': {}},
            },
            'resources': [],
            'resourceTemplates': [],
          },
        ],
      });
      final update = McpServerStatus.fromStartupStatusUpdated({
        'threadId': 'thr_1',
        'name': 'github',
        'status': 'failed',
        'error': 'missing command',
        'failureReason': 'reauthenticationRequired',
      });

      final updated = page.upsertStartupStatus(update!);

      expect(updated.servers, hasLength(1));
      final server = updated.servers.single;
      expect(server.authStatus, 'oAuth');
      expect(server.tools, contains('search_issues'));
      expect(server.startupStatus, 'failed');
      expect(server.startupError, 'missing command');
      expect(server.startupFailureReason, 'reauthenticationRequired');
      expect(server.startupThreadId, 'thr_1');
    },
  );

  test('McpServerStatus parses standalone startup status updates', () {
    final update = McpServerStatus.fromStartupStatusUpdated({
      'name': 'filesystem',
      'status': 'starting',
    });

    expect(update?.name, 'filesystem');
    expect(update?.authStatus, 'unknown');
    expect(update?.startupStatus, 'starting');
    expect(update?.tools, isEmpty);
    expect(
      McpServerStatus.fromStartupStatusUpdated({'name': 'broken'}),
      isNull,
    );
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
