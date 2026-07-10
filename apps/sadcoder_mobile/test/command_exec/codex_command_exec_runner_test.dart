import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/command_exec/codex_command_exec_runner.dart';
import 'package:sadcoder_mobile/src/command_exec/command_exec_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('streams PTY output and controls the running process', () async {
    final requests = <JsonRpcRequest>[];
    final execResponse = Completer<Map<String, Object?>>();
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      if (request.method == 'command/exec') {
        return execResponse.future;
      }
      return <String, Object?>{};
    });
    final runner = CodexCommandExecRunner(
      CodexAppServerClient(transport),
      processIdFactory: () => 'proc_1',
    );

    final session = await runner.start(
      const CommandExecRequest(
        command: ['bash', '-lc', 'printf hello'],
        cwd: '/repo',
        env: {'TERM': 'xterm-256color'},
        size: CommandExecTerminalSize(rows: 24, cols: 80),
        disableTimeout: true,
        outputBytesCap: 4096,
        sandboxPolicy: {'type': 'workspaceWrite'},
      ),
    );
    final outputFuture = session.output.take(2).toList();

    transport.emitNotification({
      'method': 'command/exec/outputDelta',
      'params': {
        'processId': 'other_process',
        'stream': 'stdout',
        'deltaBase64': base64Encode(utf8.encode('ignored')),
        'capReached': false,
      },
    });
    transport.emitNotification({
      'method': 'command/exec/outputDelta',
      'params': {
        'processId': 'proc_1',
        'stream': 'stdout',
        'deltaBase64': base64Encode(utf8.encode('hello')),
        'capReached': false,
      },
    });
    transport.emitNotification({
      'method': 'command/exec/outputDelta',
      'params': {
        'processId': 'proc_1',
        'stream': 'stderr',
        'deltaBase64': base64Encode([0xff, 0x00]),
        'capReached': true,
      },
    });

    await session.write(utf8.encode('input\n'));
    await session.closeStdin();
    await session.resize(const CommandExecTerminalSize(rows: 40, cols: 120));
    await session.terminate();

    execResponse.complete({'exitCode': 7, 'stdout': '', 'stderr': ''});
    final result = await session.done;
    final output = await outputFuture;

    expect(session.processId, 'proc_1');
    expect(session.isCompleted, true);
    expect(result.exitCode, 7);
    expect(output, hasLength(2));
    expect(output.first.stream, CommandExecOutputStream.stdout);
    expect(utf8.decode(output.first.bytes), 'hello');
    expect(output.first.capReached, false);
    expect(output.last.stream, CommandExecOutputStream.stderr);
    expect(output.last.bytes, [0xff, 0x00]);
    expect(output.last.capReached, true);
    expect(requests.map((request) => request.method), [
      'command/exec',
      'command/exec/write',
      'command/exec/write',
      'command/exec/resize',
      'command/exec/terminate',
    ]);
    expect(requests.first.params, {
      'command': ['bash', '-lc', 'printf hello'],
      'processId': 'proc_1',
      'tty': true,
      'streamStdin': true,
      'streamStdoutStderr': true,
      'cwd': '/repo',
      'env': {'TERM': 'xterm-256color'},
      'disableTimeout': true,
      'outputBytesCap': 4096,
      'size': {'rows': 24, 'cols': 80},
      'sandboxPolicy': {'type': 'workspaceWrite'},
    });
    expect(requests[1].params, {
      'processId': 'proc_1',
      'deltaBase64': base64Encode(utf8.encode('input\n')),
    });
    expect(requests[2].params, {'processId': 'proc_1', 'closeStdin': true});
    expect(requests[3].params, {
      'processId': 'proc_1',
      'size': {'rows': 40, 'cols': 120},
    });
    expect(requests[4].params, {'processId': 'proc_1'});
    await expectLater(session.write(utf8.encode('late')), throwsStateError);
  });

  test('validates command exec request invariants', () async {
    final runner = CodexCommandExecRunner(
      CodexAppServerClient(
        MemoryJsonRpcTransport((request) => <String, Object?>{}),
      ),
      processIdFactory: () => 'proc_1',
    );

    await expectLater(
      runner.start(const CommandExecRequest(command: [])),
      throwsArgumentError,
    );
    await expectLater(
      runner.start(
        const CommandExecRequest(
          command: ['echo'],
          timeoutMs: 1000,
          disableTimeout: true,
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      runner.start(
        const CommandExecRequest(
          command: ['echo'],
          outputBytesCap: 1024,
          disableOutputCap: true,
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      runner.start(
        const CommandExecRequest(
          command: ['echo'],
          tty: false,
          size: CommandExecTerminalSize(rows: 24, cols: 80),
        ),
      ),
      throwsArgumentError,
    );
  });
}
