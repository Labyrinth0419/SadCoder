import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/environments/codex_environment_runner.dart';
import 'package:sadcoder_mobile/src/environments/environment_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('parses environment info and status results', () async {
    final requests = <JsonRpcRequest>[];
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        requests.add(request);
        return switch (request.method) {
          'environment/add' => const <String, Object?>{},
          'environment/info' => {
            'shell': {'name': 'bash', 'path': '/bin/bash'},
            'cwd': 'file:///workspace',
          },
          'environment/status' => {
            'status': 'disconnected',
            'error': 'connection refused',
          },
          _ => const <String, Object?>{},
        };
      }),
    );
    final runner = CodexEnvironmentRunner(client);

    final added = await runner.addEnvironment(
      environmentId: 'env-1',
      execServerUrl: 'ws://exec.example/ws',
    );
    final info = await runner.readEnvironmentInfo(environmentId: 'env-1');
    final status = await runner.readEnvironmentStatus(environmentId: 'env-1');

    expect(added.raw, isEmpty);
    expect(info.shell.name, 'bash');
    expect(info.shell.path, '/bin/bash');
    expect(info.cwd, 'file:///workspace');
    expect(status.status, EnvironmentStatusKind.disconnected);
    expect(status.error, 'connection refused');
    expect(requests.map((request) => request.method), [
      'environment/add',
      'environment/info',
      'environment/status',
    ]);
  });

  test('unknown status values remain forward compatible', () async {
    final runner = CodexEnvironmentRunner(
      CodexAppServerClient(
        MemoryJsonRpcTransport((_) => {'status': 'recovering'}),
      ),
    );

    final status = await runner.readEnvironmentStatus(environmentId: 'env-1');

    expect(status.status, EnvironmentStatusKind.unknown);
  });
}
