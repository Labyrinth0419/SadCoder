import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/mcp/codex_mcp_resource_reader.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_resource_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('resource payload preserves text, blob, MIME, and metadata', () {
    final result = McpResourceReadResult.fromJson({
      'contents': [
        {
          'uri': 'docs://guide',
          'mimeType': 'text/markdown',
          'text': '  First line\nSecond line\n',
          '_meta': {'source': 'docs'},
        },
        {
          'uri': 'docs://logo',
          'mime_type': 'image/png',
          'blob': 'AAEC',
          '_meta': {'width': 32},
        },
        {'uri': 'docs://missing-content'},
        {'text': 'missing uri'},
        'malformed',
      ],
    });

    expect(result.contents, hasLength(2));
    final text = result.contents.first;
    expect(text.kind, McpResourceContentKind.text);
    expect(text.uri, 'docs://guide');
    expect(text.mimeType, 'text/markdown');
    expect(text.text, '  First line\nSecond line\n');
    expect(text.meta, {'source': 'docs'});

    final blob = result.contents.last;
    expect(blob.kind, McpResourceContentKind.blob);
    expect(blob.uri, 'docs://logo');
    expect(blob.mimeType, 'image/png');
    expect(blob.blob, 'AAEC');
    expect(blob.meta, {'width': 32});
  });

  test('reader calls stable resource RPC with the current thread', () async {
    final requests = <JsonRpcRequest>[];
    final reader = CodexMcpResourceReader(
      CodexAppServerClient(
        MemoryJsonRpcTransport((request) {
          requests.add(request);
          return {
            'contents': [
              {
                'uri': 'docs://guide',
                'mimeType': 'text/plain',
                'text': 'Guide',
              },
            ],
          };
        }),
      ),
    );

    final result = await reader.readResource(
      threadId: ' thr_1 ',
      server: ' docs ',
      uri: ' docs://guide ',
    );

    expect(result.contents.single.text, 'Guide');
    expect(requests.single.method, 'mcpServer/resource/read');
    expect(requests.single.params, {
      'threadId': 'thr_1',
      'server': 'docs',
      'uri': 'docs://guide',
    });
  });

  test('reader supports threadless resource reads', () async {
    final requests = <JsonRpcRequest>[];
    final reader = CodexMcpResourceReader(
      CodexAppServerClient(
        MemoryJsonRpcTransport((request) {
          requests.add(request);
          return {'contents': <Object?>[]};
        }),
      ),
    );

    await reader.readResource(
      threadId: '  ',
      server: 'docs',
      uri: 'docs://guide',
    );

    expect(requests.single.params, {'server': 'docs', 'uri': 'docs://guide'});
  });

  test('reader rejects blank server and URI values', () async {
    final reader = CodexMcpResourceReader(
      CodexAppServerClient(MemoryJsonRpcTransport((_) => {})),
    );

    await expectLater(
      reader.readResource(server: '  ', uri: 'docs://guide'),
      throwsArgumentError,
    );
    await expectLater(
      reader.readResource(server: 'docs', uri: '  '),
      throwsArgumentError,
    );
  });
}
