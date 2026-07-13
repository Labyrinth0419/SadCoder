import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../command_exec/command_exec_runner.dart';

typedef TerminalCommandExecRunnerProvider = CommandExecRunner? Function();

enum TerminalSessionStatus { idle, starting, running, completed, failed }

enum TerminalSessionFailure { noActiveCommandExecSession }

class TerminalSessionException implements Exception {
  const TerminalSessionException(this.code, this.message);

  final TerminalSessionFailure code;
  final String message;

  @override
  String toString() => message;
}

class TerminalSessionController extends ChangeNotifier {
  TerminalSessionController({
    required TerminalCommandExecRunnerProvider runnerProvider,
  }) : _runnerProvider = runnerProvider;

  final TerminalCommandExecRunnerProvider _runnerProvider;
  final StringBuffer _output = StringBuffer();
  StreamSubscription<CommandExecOutputChunk>? _outputSubscription;
  CommandExecSession? _session;
  TerminalSessionStatus _status = TerminalSessionStatus.idle;
  Object? _error;
  int? _exitCode;
  bool _outputCapReached = false;

  TerminalSessionStatus get status => _status;
  Object? get error => _error;
  int? get exitCode => _exitCode;
  String get output => _output.toString();
  bool get outputCapReached => _outputCapReached;
  bool get isRunning =>
      _status == TerminalSessionStatus.starting ||
      _status == TerminalSessionStatus.running;

  Future<void> start({required String commandLine, required String cwd}) async {
    final argv = parseCommandExecArgv(commandLine);
    if (argv.isEmpty) {
      return;
    }
    final runner = _runnerProvider();
    if (runner == null) {
      _setState(
        status: TerminalSessionStatus.failed,
        error: const TerminalSessionException(
          TerminalSessionFailure.noActiveCommandExecSession,
          'No active command exec session',
        ),
      );
      return;
    }

    await _outputSubscription?.cancel();
    _output.clear();
    _outputCapReached = false;
    _exitCode = null;
    _session = null;
    _setState(status: TerminalSessionStatus.starting, error: null);

    try {
      final session = await runner.start(
        CommandExecRequest(
          command: argv,
          cwd: cwd,
          size: const CommandExecTerminalSize(rows: 24, cols: 80),
          outputBytesCap: 256 * 1024,
        ),
      );
      _session = session;
      _outputSubscription = session.output.listen(
        _handleOutput,
        onError: (Object error) {
          _setState(status: TerminalSessionStatus.failed, error: error);
        },
      );
      _setState(status: TerminalSessionStatus.running, error: null);
      final result = await session.done;
      _exitCode = result.exitCode;
      _setState(status: TerminalSessionStatus.completed, error: null);
    } on Object catch (error) {
      _setState(status: TerminalSessionStatus.failed, error: error);
    }
  }

  Future<void> sendInput(String text) async {
    final session = _session;
    if (session == null || text.isEmpty) {
      return;
    }
    await session.write(utf8.encode(text));
  }

  Future<void> closeStdin() async {
    await _session?.closeStdin();
  }

  Future<void> terminate() async {
    await _session?.terminate();
  }

  @override
  void dispose() {
    final session = _session;
    if (session != null && !session.isCompleted) {
      unawaited(session.terminate());
    }
    unawaited(_outputSubscription?.cancel());
    super.dispose();
  }

  void _handleOutput(CommandExecOutputChunk chunk) {
    _output.write(utf8.decode(chunk.bytes, allowMalformed: true));
    _outputCapReached = _outputCapReached || chunk.capReached;
    notifyListeners();
  }

  void _setState({required TerminalSessionStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}

List<String> parseCommandExecArgv(String input) {
  final argv = <String>[];
  final current = StringBuffer();
  var quote = '';
  var escaping = false;
  var hasToken = false;

  void flush() {
    if (!hasToken) {
      return;
    }
    argv.add(current.toString());
    current.clear();
    hasToken = false;
  }

  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    if (escaping) {
      current.write(char);
      escaping = false;
      hasToken = true;
      continue;
    }
    if (char == '\\') {
      escaping = true;
      hasToken = true;
      continue;
    }
    if (quote.isNotEmpty) {
      if (char == quote) {
        quote = '';
      } else {
        current.write(char);
      }
      hasToken = true;
      continue;
    }
    if (char == '"' || char == "'") {
      quote = char;
      hasToken = true;
      continue;
    }
    if (char.trim().isEmpty) {
      flush();
      continue;
    }
    current.write(char);
    hasToken = true;
  }
  if (escaping) {
    current.write('\\');
  }
  flush();
  return argv;
}
