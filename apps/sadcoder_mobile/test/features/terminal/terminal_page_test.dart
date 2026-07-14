import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/command_exec/command_exec_runner.dart';
import 'package:sadcoder_mobile/src/features/terminal/terminal_page.dart';
import 'package:sadcoder_mobile/src/features/terminal/terminal_session_controller.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/processes/process_runner.dart';
import 'package:sadcoder_mobile/src/workspace/workspace_command_runner.dart';

void main() {
  testWidgets('shows unavailable states when runner or cwd is missing', (
    tester,
  ) async {
    await _pumpTerminalPage(tester, runner: null, root: '/repo');

    expect(
      find.text('Connect to a host to run terminal commands.'),
      findsOneWidget,
    );

    await _pumpTerminalPage(
      tester,
      runner: _FakeCommandExecRunner(),
      root: null,
    );

    expect(
      find.text('Select a workspace before running terminal commands.'),
      findsOneWidget,
    );
  });

  testWidgets('runs a command and renders terminal output', (tester) async {
    final runner = _FakeCommandExecRunner();
    await _pumpTerminalPage(tester, runner: runner, root: '/repo');

    await tester.enterText(
      find.byKey(const ValueKey('terminal-command-field')),
      'bash -lc "echo hi"',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('terminal-run-button')));
    await tester.pump();
    await tester.pump();

    expect(runner.requests.single.command, ['bash', '-lc', 'echo hi']);
    expect(find.textContaining('Running'), findsOneWidget);
    expect(find.text('Working directory: /repo'), findsOneWidget);

    runner.session.addOutput('hello\n');
    await tester.pump();

    expect(find.textContaining('hello'), findsOneWidget);

    runner.session.complete(exitCode: 0);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Exited with code 0'), findsOneWidget);
  });

  testWidgets('sends stdin and terminate controls to the session', (
    tester,
  ) async {
    final runner = _FakeCommandExecRunner();
    await _pumpTerminalPage(tester, runner: runner, root: '/repo');

    await tester.enterText(
      find.byKey(const ValueKey('terminal-command-field')),
      'cat',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('terminal-run-button')));
    await tester.pump();
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('terminal-stdin-field')),
      'input',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('terminal-stdin-send')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('terminal-close-stdin')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('terminal-terminate')));
    await tester.pump();

    expect(runner.session.writes.single, utf8.encode('input\n'));
    expect(runner.session.closeStdinCount, 1);
    expect(runner.session.terminateCount, 1);

    runner.session.complete();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('localizes missing terminal runner failures', (tester) async {
    final controller = TerminalSessionController(runnerProvider: () => null);
    addTearDown(controller.dispose);

    await _pumpTerminalPage(
      tester,
      runner: _FakeCommandExecRunner(),
      root: '/repo',
      controller: controller,
      locale: const Locale('zh', 'CN'),
    );

    await tester.enterText(
      find.byKey(const ValueKey('terminal-command-field')),
      'pwd',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('terminal-run-button')));
    await tester.pump();

    expect(find.text('失败：没有可用的终端命令执行会话。'), findsOneWidget);
    expect(find.textContaining('No active command exec session'), findsNothing);
    expect(find.textContaining('Bad state'), findsNothing);
  });

  testWidgets('host process mode requires confirmation before starting', (
    tester,
  ) async {
    final sandboxedRunner = _FakeCommandExecRunner();
    final hostRunner = _FakeProcessRunner();
    await _pumpTerminalPage(
      tester,
      runner: sandboxedRunner,
      hostProcessRunner: hostRunner,
      root: '/repo',
    );

    await tester.tap(find.text('Host process'));
    await tester.pumpAndSettle();
    expect(find.textContaining('without the Codex sandbox'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('terminal-command-field')),
      'bash -lc "echo hi"',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('terminal-run-button')));
    await tester.pumpAndSettle();

    expect(hostRunner.requests, isEmpty);
    expect(find.text('Run unsandboxed host process?'), findsOneWidget);
    expect(find.textContaining('Command: bash -lc "echo hi"'), findsOneWidget);
    expect(find.textContaining('Working directory: /repo'), findsWidgets);
    await tester.tap(
      find.byKey(const ValueKey('terminal-host-process-confirm')),
    );
    await tester.pump();
    await tester.pump();

    expect(sandboxedRunner.requests, isEmpty);
    expect(hostRunner.requests, hasLength(1));
    expect(hostRunner.requests.single.command, ['bash', '-lc', 'echo hi']);
    expect(hostRunner.requests.single.cwd, '/repo');

    hostRunner.session.complete();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('canceling host process confirmation sends no RPC', (
    tester,
  ) async {
    final hostRunner = _FakeProcessRunner();
    await _pumpTerminalPage(
      tester,
      runner: _FakeCommandExecRunner(),
      hostProcessRunner: hostRunner,
      root: '/repo',
    );

    await tester.tap(find.text('Host process'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('terminal-command-field')),
      'pwd',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('terminal-run-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(hostRunner.requests, isEmpty);
    expect(find.text('Idle'), findsOneWidget);
  });
}

Future<void> _pumpTerminalPage(
  WidgetTester tester, {
  CommandExecRunner? runner,
  ProcessRunner? hostProcessRunner,
  String? root,
  TerminalSessionController? controller,
  Locale? locale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: ThemeData(),
      darkTheme: ThemeData.dark(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TerminalPage(
          runner: runner,
          hostProcessRunner: hostProcessRunner,
          root: root,
          controller: controller,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

class _FakeProcessRunner extends _FakeCommandExecRunner
    implements ProcessRunner {}

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
