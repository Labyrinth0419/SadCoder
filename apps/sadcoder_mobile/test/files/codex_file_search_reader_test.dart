import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/files/codex_file_search_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('searchFiles parses fuzzy file search results', () async {
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        expect(request.method, 'fuzzyFileSearch');
        expect(request.params, {
          'query': 'main',
          'roots': ['/repo'],
        });
        return {
          'files': [
            {
              'root': '/repo',
              'path': 'lib/main.dart',
              'match_type': 'fuzzy',
              'file_name': 'main.dart',
              'score': 42,
              'indices': [4, 5],
            },
            {'path': 'missing-root.dart'},
          ],
        };
      }),
    );
    final reader = CodexFileSearchReader(client);

    final page = await reader.searchFiles(query: 'main', roots: ['/repo']);

    expect(page.files, hasLength(1));
    expect(page.files.single.root, '/repo');
    expect(page.files.single.path, 'lib/main.dart');
    expect(page.files.single.matchType, 'fuzzy');
    expect(page.files.single.fileName, 'main.dart');
    expect(page.files.single.score, 42);
    expect(page.files.single.indices, [4, 5]);
  });
}
