import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/command_exec/command_exec_runner.dart';
import 'package:sadcoder_mobile/src/features/terminal/terminal_session_controller.dart';
import 'package:sadcoder_mobile/src/workspace/workspace_command_runner.dart';

void main() {
  test('parses quoted command lines', () {
    expect(parseCommandExecArgv('bash -lc "echo hi"'), [
      'bash',
      '-lc',
      'echo hi',
    ]);
    expect(parseCommandExecArgv(r'''printf '' "a b" c\ d'''), [
      'printf',
      '',
      'a b',
      'c d',
    ]);
    expect(parseCommandExecArgv(r'''echo \"quoted\"'''), ['echo', '"quoted"']);
  });

  test('starts command, appends output, and records exit code', () async {
    final runner = _FakeCommandExecRunner();
    final controller = TerminalSessionController(runnerProvider: () => runner);
    addTearDown(controller.dispose);

    final startFuture = controller.start(
      commandLine: 'bash -lc "echo hi"',
      cwd: '/repo',
    );
    await pumpEventQueue();

    expect(controller.status, TerminalSessionStatus.running);
    expect(runner.requests.single.command, ['bash', '-lc', 'echo hi']);
    expect(runner.requests.single.cwd, '/repo');
    expect(runner.requests.single.tty, true);
    expect(runner.requests.single.size?.rows, 24);
    expect(runner.requests.single.size?.cols, 80);

    runner.session.addOutput('hello\n');
    await pumpEventQueue();
    expect(controller.output, 'hello\n');

    runner.session.complete(exitCode: 7);
    await startFuture;

    expect(controller.status, TerminalSessionStatus.completed);
    expect(controller.exitCode, 7);
  });

  test('delegates stdin, close, and terminate controls', () async {
    final runner = _FakeCommandExecRunner();
    final controller = TerminalSessionController(runnerProvider: () => runner);
    addTearDown(controller.dispose);

    final startFuture = controller.start(commandLine: 'cat', cwd: '/repo');
    await pumpEventQueue();

    await controller.sendInput('input\n');
    await controller.closeStdin();
    await controller.terminate();

    expect(runner.session.writes.single, utf8.encode('input\n'));
    expect(runner.session.closeStdinCount, 1);
    expect(runner.session.terminateCount, 1);

    runner.session.complete();
    await startFuture;
  });

  test('reports missing runner as a failed state', () async {
    final controller = TerminalSessionController(runnerProvider: () => null);
    addTearDown(controller.dispose);

    await controller.start(commandLine: 'pwd', cwd: '/repo');

    expect(controller.status, TerminalSessionStatus.failed);
    final error = controller.error;
    expect(error, isA<TerminalSessionException>());
    expect(
      (error! as TerminalSessionException).code,
      TerminalSessionFailure.noActiveCommandExecSession,
    );
  });
}

class _FakeCommandExecRunner implements CommandExecRunner {
  final requests = <CommandExecRequest>[];
  final session = _FakeCommandExecSession();

  @override
  Future<CommandExecSession> start(CommandExecRequest request) async {
    requests.add(request);
    return session;
  }
}

class _FakeCommandExecSession implements CommandExecSession {
  final _outputController = StreamController<CommandExecOutputChunk>();
  final _done = Completer<WorkspaceCommandResult>();
  final writes = <List<int>>[];
  var closeStdinCount = 0;
  var terminateCount = 0;

  @override
  String get processId => 'proc_test';

  @override
  Stream<CommandExecOutputChunk> get output => _outputController.stream;

  @override
  Future<WorkspaceCommandResult> get done => _done.future;

  @override
  bool get isCompleted => _done.isCompleted;

  void addOutput(String text, {bool capReached = false}) {
    _outputController.add(
      CommandExecOutputChunk(
        processId: processId,
        stream: CommandExecOutputStream.stdout,
        bytes: Uint8List.fromList(utf8.encode(text)),
        capReached: capReached,
      ),
    );
  }

  void complete({int exitCode = 0}) {
    if (!_done.isCompleted) {
      _done.complete(
        WorkspaceCommandResult(exitCode: exitCode, stdout: '', stderr: ''),
      );
    }
    unawaited(_outputController.close());
  }

  @override
  Future<void> write(List<int> bytes, {bool closeStdin = false}) async {
    writes.add(List<int>.from(bytes));
    if (closeStdin) {
      closeStdinCount++;
    }
  }

  @override
  Future<void> closeStdin() async {
    closeStdinCount++;
  }

  @override
  Future<void> resize(CommandExecTerminalSize size) async {}

  @override
  Future<void> terminate() async {
    terminateCount++;
  }
}
