import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/command_exec/command_exec_runner.dart';
import 'package:sadcoder_mobile/src/processes/codex_process_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('streams and controls an unsandboxed host process', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return <String, Object?>{};
    });
    final runner = CodexProcessRunner(
      CodexAppServerClient(transport),
      processHandleFactory: () => 'host_1',
    );

    final session = await runner.start(
      const CommandExecRequest(
        command: ['bash', '-lc', 'printf hello'],
        cwd: '/repo',
        env: {'TERM': 'xterm-256color', 'REMOVE_ME': null},
        size: CommandExecTerminalSize(rows: 24, cols: 80),
        disableTimeout: true,
        outputBytesCap: 4096,
      ),
    );
    final outputFuture = session.output.take(3).toList();

    transport.emitNotification({
      'method': 'process/outputDelta',
      'params': {
        'processHandle': 'other_process',
        'stream': 'stdout',
        'deltaBase64': base64Encode(utf8.encode('ignored')),
        'capReached': false,
      },
    });
    transport.emitNotification({
      'method': 'process/outputDelta',
      'params': {
        'processHandle': 'host_1',
        'stream': 'stdout',
        'deltaBase64': base64Encode(utf8.encode('hello')),
        'capReached': false,
      },
    });
    transport.emitNotification({
      'method': 'process/outputDelta',
      'params': {
        'process_handle': 'host_1',
        'stream': 'stderr',
        'delta_base64': base64Encode([0xff, 0x00]),
        'cap_reached': true,
      },
    });

    await session.write(utf8.encode('input\n'));
    await session.closeStdin();
    await session.resize(const CommandExecTerminalSize(rows: 40, cols: 120));
    await session.terminate();

    transport.emitNotification({
      'method': 'process/exited',
      'params': {
        'processHandle': 'host_1',
        'exitCode': 7,
        'stdout': 'tail',
        'stdoutCapReached': false,
        'stderr': '',
        'stderrCapReached': false,
      },
    });
    final result = await session.done;
    final output = await outputFuture;

    expect(session.processId, 'host_1');
    expect(session.isCompleted, isTrue);
    expect(result.exitCode, 7);
    expect(output, hasLength(3));
    expect(utf8.decode(output.first.bytes), 'hello');
    expect(output.first.stream, CommandExecOutputStream.stdout);
    expect(output[1].stream, CommandExecOutputStream.stderr);
    expect(output[1].bytes, [0xff, 0x00]);
    expect(output[1].capReached, isTrue);
    expect(utf8.decode(output.last.bytes), 'tail');
    expect(requests.map((request) => request.method), [
      'process/spawn',
      'process/writeStdin',
      'process/writeStdin',
      'process/resizePty',
      'process/kill',
    ]);
    expect(requests.first.params, {
      'command': ['bash', '-lc', 'printf hello'],
      'processHandle': 'host_1',
      'cwd': '/repo',
      'tty': true,
      'streamStdin': true,
      'streamStdoutStderr': true,
      'env': {'TERM': 'xterm-256color', 'REMOVE_ME': null},
      'size': {'rows': 24, 'cols': 80},
      'outputBytesCap': 4096,
      'timeoutMs': null,
    });
    expect(requests[1].params, {
      'processHandle': 'host_1',
      'deltaBase64': base64Encode(utf8.encode('input\n')),
    });
    expect(requests[2].params, {'processHandle': 'host_1', 'closeStdin': true});
    expect(requests[3].params, {
      'processHandle': 'host_1',
      'size': {'rows': 40, 'cols': 120},
    });
    expect(requests[4].params, {'processHandle': 'host_1'});
    await expectLater(session.write(utf8.encode('late')), throwsStateError);
  });

  test('validates host process request invariants', () async {
    final runner = CodexProcessRunner(
      CodexAppServerClient(
        MemoryJsonRpcTransport((request) => <String, Object?>{}),
      ),
      processHandleFactory: () => 'host_1',
    );

    await expectLater(
      runner.start(const CommandExecRequest(command: [], cwd: '/repo')),
      throwsArgumentError,
    );
    await expectLater(
      runner.start(const CommandExecRequest(command: ['echo'])),
      throwsArgumentError,
    );
    await expectLater(
      runner.start(
        const CommandExecRequest(
          command: ['echo'],
          cwd: '/repo',
          sandboxPolicy: {'type': 'workspaceWrite'},
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      runner.start(
        const CommandExecRequest(
          command: ['echo'],
          cwd: '/repo',
          timeoutMs: 1000,
          disableTimeout: true,
        ),
      ),
      throwsArgumentError,
    );
  });
}
