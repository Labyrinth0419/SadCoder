import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_failure.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_kind.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_mutation_runner.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test(
    'writes only after optimistic version check and returns new stat',
    () async {
      final requests = <JsonRpcRequest>[];
      late final _MutableWorkspaceFileReader reader;
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        if (request.method == 'fs/writeFile') {
          reader.contentVersion = 'v2';
          reader.content = 'after';
        }
        return {};
      });
      final events = StreamController<CodexEvent>.broadcast();
      reader = _MutableWorkspaceFileReader(
        content: 'before',
        contentVersion: 'v1',
      );
      final runner = CodexWorkspaceFileMutationRunner(
        client: CodexAppServerClient(transport),
        fileReader: reader,
        events: events.stream,
      );
      addTearDown(() async {
        await runner.close();
        await events.close();
        await transport.close();
      });

      final result = await runner.writeText(
        root: '/repo',
        path: 'src/main.dart',
        content: 'after',
        expectedContent: 'before',
        expectedContentVersion: 'v1',
      );

      expect(requests.map((request) => request.method), [
        'workspace/fileStat',
        'fs/writeFile',
      ]);
      expect(requests.last.params, {
        'path': '/repo/src/main.dart',
        'dataBase64': 'YWZ0ZXI=',
      });
      expect(result.path, 'src/main.dart');
      expect(result.stat.contentVersion, 'v2');
    },
  );

  test('rejects a stale version without sending fs/writeFile', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });
    final runner = CodexWorkspaceFileMutationRunner(
      client: CodexAppServerClient(transport),
      fileReader: _MutableWorkspaceFileReader(
        content: 'server',
        contentVersion: 'v2',
      ),
      events: const Stream<CodexEvent>.empty(),
    );
    addTearDown(() async {
      await runner.close();
      await transport.close();
    });

    await expectLater(
      runner.writeText(
        root: '/repo',
        path: 'main.dart',
        content: 'client',
        expectedContent: 'before',
        expectedContentVersion: 'v1',
      ),
      throwsA(isA<WorkspaceFileConflictException>()),
    );
    expect(requests, isEmpty);
  });

  test('watch forwards fs/changed and sends fs/unwatch on close', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return request.method == 'fs/watch'
          ? {'path': '/repo/lib'}
          : <String, Object?>{};
    });
    final events = StreamController<CodexEvent>.broadcast();
    final runner = CodexWorkspaceFileMutationRunner(
      client: CodexAppServerClient(transport),
      fileReader: _MutableWorkspaceFileReader(
        content: '',
        contentVersion: 'v1',
      ),
      events: events.stream,
    );
    addTearDown(() async {
      await runner.close();
      await events.close();
      await transport.close();
    });

    final watch = await runner.watch(root: '/repo', path: 'lib');
    final eventFuture = watch.events.first;
    events.add(
      CodexEvent.fromNotification({
        'method': 'fs/changed',
        'params': {
          'watchId': watch.watchId,
          'changedPaths': ['/repo/lib/main.dart'],
        },
      }),
    );
    final event = await eventFuture;
    expect(event.changedPaths, ['/repo/lib/main.dart']);

    await watch.close();
    expect(requests.map((request) => request.method), [
      'fs/watch',
      'fs/unwatch',
    ]);
  });

  test('rejects binary files and unsafe paths before writing', () async {
    final runner = CodexWorkspaceFileMutationRunner(
      client: CodexAppServerClient(MemoryJsonRpcTransport((_) => {})),
      fileReader: _MutableWorkspaceFileReader(
        content: 'binary',
        contentVersion: 'v1',
        isBinary: true,
      ),
      events: const Stream<CodexEvent>.empty(),
    );
    addTearDown(runner.close);

    await expectLater(
      runner.writeText(
        root: '/repo',
        path: '../secret',
        content: 'x',
        expectedContent: 'binary',
      ),
      throwsA(isA<WorkspaceFileException>()),
    );
    await expectLater(
      runner.writeText(
        root: '/repo',
        path: 'file.bin',
        content: 'x',
        expectedContent: 'binary',
      ),
      throwsA(isA<WorkspaceFileException>()),
    );
  });
}

class _MutableWorkspaceFileReader implements WorkspaceFileReader {
  _MutableWorkspaceFileReader({
    required this.content,
    required this.contentVersion,
    this.isBinary = false,
  });

  String content;
  String? contentVersion;
  bool isBinary;

  @override
  Future<WorkspaceFileStat> statFile({
    required String root,
    required String path,
  }) async {
    return WorkspaceFileStat(
      root: root,
      path: path,
      kind: WorkspaceFileKind.file,
      sizeBytes: content.length,
      isBinary: isBinary,
      contentVersion: contentVersion,
    );
  }

  @override
  Future<WorkspaceFileReadChunk> readFile({
    required String root,
    required String path,
    int offset = 0,
    int limitBytes = 64 * 1024,
    String encoding = 'utf-8',
  }) async {
    return WorkspaceFileReadChunk(
      root: root,
      path: path,
      sizeBytes: content.length,
      offset: offset,
      bytesRead: content.length,
      hasMore: false,
      encoding: encoding,
      isBinary: isBinary,
      content: content,
      contentVersion: contentVersion,
    );
  }
}
