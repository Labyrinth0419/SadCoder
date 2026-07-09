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
        expect(request.method, 'fs/getMetadata');
        expect(request.params, {'path': '/repo/lib/main.dart'});
        return {
          'isDirectory': false,
          'isFile': true,
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
    expect(requests, hasLength(1));
  });

  test(
    'readFile slices text by UTF-8 byte offsets without cutting characters',
    () async {
      final requests = <JsonRpcRequest>[];
      final content = 'a🙂b';
      final client = CodexAppServerClient(
        MemoryJsonRpcTransport((request) {
          requests.add(request);
          switch (request.method) {
            case 'fs/getMetadata':
              return {'isDirectory': false, 'isFile': true, 'isSymlink': false};
            case 'fs/readFile':
              expect(request.params, {'path': '/repo/README.md'});
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
        'fs/getMetadata',
        'fs/readFile',
        'fs/getMetadata',
        'fs/readFile',
        'fs/getMetadata',
        'fs/readFile',
      ]);
    },
  );

  test('readFile rejects binary content', () async {
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        return switch (request.method) {
          'fs/getMetadata' => {
            'isDirectory': false,
            'isFile': true,
            'isSymlink': false,
          },
          'fs/readFile' => {
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
        expect(request.method, 'fs/getMetadata');
        return {'isDirectory': false, 'isFile': true, 'isSymlink': true};
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
}
