import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/threads/codex_thread_shell_command_runner.dart';

void main() {
  test('runShellCommand normalizes input and calls app-server', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });
    final runner = CodexThreadShellCommandRunner(
      CodexAppServerClient(transport),
    );

    await runner.runShellCommand(threadId: ' thr_1 ', command: ' echo hi ');

    expect(requests.single.method, 'thread/shellCommand');
    expect(requests.single.params, {'threadId': 'thr_1', 'command': 'echo hi'});
  });

  test('runShellCommand rejects empty values before calling app-server', () {
    final requests = <JsonRpcRequest>[];
    final runner = CodexThreadShellCommandRunner(
      CodexAppServerClient(
        MemoryJsonRpcTransport((request) {
          requests.add(request);
          return {};
        }),
      ),
    );

    expect(
      () => runner.runShellCommand(threadId: ' ', command: 'echo hi'),
      throwsArgumentError,
    );
    expect(
      () => runner.runShellCommand(threadId: 'thr_1', command: '   '),
      throwsArgumentError,
    );
    expect(requests, isEmpty);
  });
}
