import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/files/codex_workspace_directory_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_failure.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_kind.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test(
    'listDirectory normalizes paths, hides dotfiles, sorts, and paginates',
    () async {
      final requests = <JsonRpcRequest>[];
      final client = CodexAppServerClient(
        MemoryJsonRpcTransport((request) {
          requests.add(request);
          switch (request.method) {
            case 'fs/getMetadata':
              expect(
                request.params?['path'],
                anyOf('/repo/lib', '/repo/lib/src'),
              );
              return {'isDirectory': true, 'isFile': false, 'isSymlink': false};
            case 'fs/readDirectory':
              expect(request.params, {'path': '/repo/lib/src'});
              return {
                'entries': [
                  {
                    'fileName': 'main.dart',
                    'isDirectory': false,
                    'isFile': true,
                  },
                  {'fileName': '.env', 'isDirectory': false, 'isFile': true},
                  {
                    'fileName': 'features',
                    'isDirectory': true,
                    'isFile': false,
                  },
                  {
                    'fileName': 'README.md',
                    'isDirectory': false,
                    'isFile': true,
                    'sizeBytes': 42,
                    'modifiedAtMs': 1700000000000,
                  },
                ],
              };
            default:
              throw StateError('unexpected method ${request.method}');
          }
        }),
      );
      final reader = CodexWorkspaceDirectoryReader(client);

      final firstPage = await reader.listDirectory(
        root: '/repo/',
        path: 'lib/./src',
        limit: 2,
      );
      final secondPage = await reader.listDirectory(
        root: '/repo/',
        path: 'lib/src',
        limit: 2,
        cursor: firstPage.nextCursor,
      );

      expect(firstPage.root, '/repo');
      expect(firstPage.path, 'lib/src');
      expect(firstPage.entries.map((entry) => entry.name), [
        'features',
        'main.dart',
      ]);
      expect(firstPage.entries.first.kind, WorkspaceFileKind.directory);
      expect(firstPage.entries.first.path, 'lib/src/features');
      expect(firstPage.nextCursor, '2');
      expect(secondPage.entries.single.name, 'README.md');
      expect(secondPage.entries.single.sizeBytes, 42);
      expect(
        secondPage.entries.single.modifiedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );
      expect(secondPage.nextCursor, isNull);
      expect(requests.map((request) => request.method), [
        'fs/getMetadata',
        'fs/getMetadata',
        'fs/readDirectory',
        'fs/getMetadata',
        'fs/getMetadata',
        'fs/readDirectory',
      ]);
    },
  );

  test('listDirectory can include server-marked hidden files', () async {
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        return {
          'entries': [
            {
              'fileName': 'secret.env',
              'isDirectory': false,
              'isFile': true,
              'isHidden': true,
            },
          ],
        };
      }),
    );
    final reader = CodexWorkspaceDirectoryReader(client);

    final filteredPage = await reader.listDirectory(root: '/repo');
    final page = await reader.listDirectory(root: '/repo', includeHidden: true);

    expect(filteredPage.entries, isEmpty);
    expect(page.entries.single.name, 'secret.env');
    expect(page.entries.single.isHidden, true);
  });

  test('listDirectory preserves symlink metadata', () async {
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        return {
          'entries': [
            {
              'fileName': 'linked',
              'isDirectory': true,
              'isFile': false,
              'isSymlink': true,
            },
          ],
        };
      }),
    );
    final reader = CodexWorkspaceDirectoryReader(client);

    final page = await reader.listDirectory(root: '/repo');

    expect(page.entries.single.name, 'linked');
    expect(page.entries.single.kind, WorkspaceFileKind.directory);
    expect(page.entries.single.isSymlink, true);
  });

  test(
    'listDirectory rejects symlink paths before reading directory',
    () async {
      final requests = <JsonRpcRequest>[];
      final client = CodexAppServerClient(
        MemoryJsonRpcTransport((request) {
          requests.add(request);
          expect(request.params, {'path': '/repo/linked'});
          if (request.method == 'fs/getMetadata') {
            return {'isDirectory': true, 'isFile': false, 'isSymlink': true};
          }
          throw StateError('unexpected method ${request.method}');
        }),
      );
      final reader = CodexWorkspaceDirectoryReader(client);

      await expectLater(
        reader.listDirectory(root: '/repo', path: 'linked'),
        throwsA(
          isA<WorkspaceFileException>().having(
            (error) => error.code,
            'code',
            WorkspaceFileFailureCode.pathOutsideRoot,
          ),
        ),
      );
      expect(requests.map((request) => request.method), ['fs/getMetadata']);
    },
  );

  test(
    'listDirectory rejects symlink ancestors before reading directory',
    () async {
      final requests = <JsonRpcRequest>[];
      final client = CodexAppServerClient(
        MemoryJsonRpcTransport((request) {
          requests.add(request);
          expect(request.method, 'fs/getMetadata');
          expect(request.params, {'path': '/repo/linked'});
          return {'isDirectory': true, 'isFile': false, 'isSymlink': true};
        }),
      );
      final reader = CodexWorkspaceDirectoryReader(client);

      await expectLater(
        reader.listDirectory(root: '/repo', path: 'linked/secret'),
        throwsA(
          isA<WorkspaceFileException>().having(
            (error) => error.code,
            'code',
            WorkspaceFileFailureCode.pathOutsideRoot,
          ),
        ),
      );
      expect(requests.map((request) => request.method), ['fs/getMetadata']);
    },
  );

  test(
    'listDirectory rejects traversal and absolute replacement paths',
    () async {
      final client = CodexAppServerClient(
        MemoryJsonRpcTransport(
          (_) => throw StateError('should not call server'),
        ),
      );
      final reader = CodexWorkspaceDirectoryReader(client);

      await expectLater(
        reader.listDirectory(root: '/repo', path: '../etc'),
        throwsA(
          isA<WorkspaceFileException>().having(
            (error) => error.code,
            'code',
            WorkspaceFileFailureCode.pathOutsideRoot,
          ),
        ),
      );
      await expectLater(
        reader.listDirectory(root: '/repo', path: '/tmp'),
        throwsA(
          isA<WorkspaceFileException>().having(
            (error) => error.code,
            'code',
            WorkspaceFileFailureCode.pathOutsideRoot,
          ),
        ),
      );
    },
  );

  test('listDirectory maps remote not found errors', () async {
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport(
        (_) => throw StateError('No such file or directory'),
      ),
    );
    final reader = CodexWorkspaceDirectoryReader(client);

    await expectLater(
      reader.listDirectory(root: '/repo', path: 'missing'),
      throwsA(
        isA<WorkspaceFileException>().having(
          (error) => error.code,
          'code',
          WorkspaceFileFailureCode.notFound,
        ),
      ),
    );
    await expectLater(
      reader.listDirectory(root: '/repo', path: r'C:secret'),
      throwsA(
        isA<WorkspaceFileException>().having(
          (error) => error.code,
          'code',
          WorkspaceFileFailureCode.pathOutsideRoot,
        ),
      ),
    );
  });
}
