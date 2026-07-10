import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/files/codex_workspace_file_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_failure.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_kind.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('statFile parses metadata and language hints', () async {
    final requests = <JsonRpcRequest>[];
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        requests.add(request);
        expect(request.method, 'workspace/fileStat');
        expect(request.params?['root'], '/repo');
        final path = request.params?['path'];
        if (path == 'lib') {
          return {'type': 'directory', 'isSymlink': false};
        }
        expect(path, 'lib/main.dart');
        return {
          'type': 'file',
          'isSymlink': false,
          'modifiedAtMs': 1700000000000,
        };
      }),
    );
    final reader = CodexWorkspaceFileReader(client);

    final stat = await reader.statFile(root: '/repo', path: 'lib/main.dart');

    expect(stat.root, '/repo');
    expect(stat.path, 'lib/main.dart');
    expect(stat.kind, WorkspaceFileKind.file);
    expect(stat.isSymlink, false);
    expect(
      stat.modifiedAt,
      DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );
    expect(stat.language, 'dart');
    expect(requests.map((request) => request.params?['path']), [
      'lib',
      'lib/main.dart',
    ]);
  });

  test('readFile parses app-server range chunks', () async {
    final requests = <JsonRpcRequest>[];
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        requests.add(request);
        switch (request.method) {
          case 'workspace/fileStat':
            expect(request.params, {'root': '/repo', 'path': 'README.md'});
            return {'type': 'file', 'isSymlink': false};
          case 'workspace/fileRead':
            expect(request.params, {
              'root': '/repo',
              'path': 'README.md',
              'offset': 6,
              'limitBytes': 8,
              'encoding': 'utf-8',
            });
            return {
              'content': '  hi\n',
              'sizeBytes': 42,
              'offset': 6,
              'bytesRead': 5,
              'nextOffset': 11,
              'hasMore': true,
              'encoding': 'utf-8',
              'contentHash': 'hash-1',
            };
          default:
            throw StateError('unexpected method ${request.method}');
        }
      }),
    );
    final reader = CodexWorkspaceFileReader(client);

    final chunk = await reader.readFile(
      root: '/repo',
      path: 'README.md',
      offset: 6,
      limitBytes: 8,
      encoding: 'UTF_8',
    );

    expect(chunk.content, '  hi\n');
    expect(chunk.sizeBytes, 42);
    expect(chunk.offset, 6);
    expect(chunk.bytesRead, 5);
    expect(chunk.nextOffset, 11);
    expect(chunk.hasMore, true);
    expect(chunk.contentVersion, 'hash-1');
    expect(requests.map((request) => request.method), [
      'workspace/fileStat',
      'workspace/fileRead',
    ]);
  });

  test(
    'readFile falls back to UTF-8 byte slicing for legacy full-file responses',
    () async {
      final requests = <JsonRpcRequest>[];
      final content = 'a🙂b';
      final client = CodexAppServerClient(
        MemoryJsonRpcTransport((request) {
          requests.add(request);
          switch (request.method) {
            case 'workspace/fileStat':
              return {'type': 'file', 'isSymlink': false};
            case 'workspace/fileRead':
              expect(request.params?['root'], '/repo');
              expect(request.params?['path'], 'README.md');
              expect(request.params?['limitBytes'], 2);
              expect(request.params?['encoding'], 'utf-8');
              return {'dataBase64': base64.encode(utf8.encode(content))};
            default:
              throw StateError('unexpected method ${request.method}');
          }
        }),
      );
      final reader = CodexWorkspaceFileReader(client);

      final firstChunk = await reader.readFile(
        root: '/repo/',
        path: 'README.md',
        limitBytes: 2,
      );
      final secondChunk = await reader.readFile(
        root: '/repo/',
        path: 'README.md',
        offset: firstChunk.nextOffset!,
        limitBytes: 2,
      );
      final thirdChunk = await reader.readFile(
        root: '/repo/',
        path: 'README.md',
        offset: secondChunk.nextOffset!,
        limitBytes: 2,
      );

      expect(firstChunk.content, 'a');
      expect(firstChunk.offset, 0);
      expect(firstChunk.bytesRead, 1);
      expect(firstChunk.nextOffset, 1);
      expect(firstChunk.hasMore, true);
      expect(secondChunk.content, '🙂');
      expect(secondChunk.offset, 1);
      expect(secondChunk.bytesRead, 4);
      expect(secondChunk.nextOffset, 5);
      expect(secondChunk.hasMore, true);
      expect(thirdChunk.content, 'b');
      expect(thirdChunk.offset, 5);
      expect(thirdChunk.bytesRead, 1);
      expect(thirdChunk.nextOffset, isNull);
      expect(thirdChunk.hasMore, false);
      expect(thirdChunk.sizeBytes, 6);
      expect(requests.map((request) => request.method), [
        'workspace/fileStat',
        'workspace/fileRead',
        'workspace/fileStat',
        'workspace/fileRead',
        'workspace/fileStat',
        'workspace/fileRead',
      ]);
    },
  );

  test('readFile rejects binary content', () async {
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        return switch (request.method) {
          'workspace/fileStat' => {'type': 'file', 'isSymlink': false},
          'workspace/fileRead' => {
            'dataBase64': base64.encode([0, 1, 2, 3]),
          },
          _ => throw StateError('unexpected method ${request.method}'),
        };
      }),
    );
    final reader = CodexWorkspaceFileReader(client);

    await expectLater(
      reader.readFile(root: '/repo', path: 'image.png'),
      throwsA(
        isA<WorkspaceFileException>().having(
          (error) => error.code,
          'code',
          WorkspaceFileFailureCode.binaryNotPreviewable,
        ),
      ),
    );
  });

  test('readFile rejects symlinks to avoid root escape', () async {
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        expect(request.method, 'workspace/fileStat');
        return {'type': 'file', 'isSymlink': true};
      }),
    );
    final reader = CodexWorkspaceFileReader(client);

    await expectLater(
      reader.readFile(root: '/repo', path: 'linked.dart'),
      throwsA(
        isA<WorkspaceFileException>().having(
          (error) => error.code,
          'code',
          WorkspaceFileFailureCode.pathOutsideRoot,
        ),
      ),
    );
  });

  test('readFile rejects symlink ancestors before reading file', () async {
    final requests = <JsonRpcRequest>[];
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        requests.add(request);
        expect(request.method, 'workspace/fileStat');
        expect(request.params, {'root': '/repo', 'path': 'linked'});
        return {'type': 'directory', 'isSymlink': true};
      }),
    );
    final reader = CodexWorkspaceFileReader(client);

    await expectLater(
      reader.readFile(root: '/repo', path: 'linked/secret.txt'),
      throwsA(
        isA<WorkspaceFileException>().having(
          (error) => error.code,
          'code',
          WorkspaceFileFailureCode.pathOutsideRoot,
        ),
      ),
    );
    expect(requests.map((request) => request.method), ['workspace/fileStat']);
  });

  test('readFile rejects traversal paths before calling app-server', () async {
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((_) => throw StateError('should not call server')),
    );
    final reader = CodexWorkspaceFileReader(client);

    await expectLater(
      reader.readFile(root: '/repo', path: 'lib/../../secret.txt'),
      throwsA(
        isA<WorkspaceFileException>().having(
          (error) => error.code,
          'code',
          WorkspaceFileFailureCode.pathOutsideRoot,
        ),
      ),
    );
  });

  test('readFile falls back to legacy fs methods', () async {
    final requests = <JsonRpcRequest>[];
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        requests.add(request);
        switch (request.method) {
          case 'workspace/fileStat':
          case 'workspace/fileRead':
            throw StateError('Method not found');
          case 'fs/getMetadata':
            expect(request.params, {'path': '/repo/README.md'});
            return {'isDirectory': false, 'isFile': true, 'isSymlink': false};
          case 'fs/readFile':
            expect(request.params, {
              'path': '/repo/README.md',
              'offset': 0,
              'limitBytes': 64,
              'encoding': 'utf-8',
            });
            return {
              'content': 'legacy',
              'sizeBytes': 6,
              'offset': 0,
              'bytesRead': 6,
              'hasMore': false,
            };
          default:
            throw StateError('unexpected method ${request.method}');
        }
      }),
    );
    final reader = CodexWorkspaceFileReader(client);

    final chunk = await reader.readFile(
      root: '/repo',
      path: 'README.md',
      limitBytes: 64,
    );

    expect(chunk.content, 'legacy');
    expect(requests.map((request) => request.method), [
      'workspace/fileStat',
      'fs/getMetadata',
      'workspace/fileRead',
      'fs/readFile',
    ]);
  });
}
