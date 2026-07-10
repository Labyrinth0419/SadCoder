import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../protocol/codex_app_server_client.dart';
import '../workspace/workspace_command_runner.dart';
import 'command_exec_runner.dart';

typedef CommandExecProcessIdFactory = String Function();

class CodexCommandExecRunner implements CommandExecRunner {
  CodexCommandExecRunner(
    this._client, {
    CommandExecProcessIdFactory? processIdFactory,
  }) : _processIdFactory = processIdFactory;

  final CodexAppServerClient _client;
  final CommandExecProcessIdFactory? _processIdFactory;
  int _nextProcessId = 1;

  @override
  Future<CommandExecSession> start(CommandExecRequest request) async {
    _validateRequest(request);
    final processId =
        _processIdFactory?.call() ??
        'sadcoder-${DateTime.now().microsecondsSinceEpoch}-${_nextProcessId++}';
    final normalizedProcessId = processId.trim();
    if (normalizedProcessId.isEmpty) {
      throw StateError('Command exec process id must not be empty');
    }

    final session = _CodexCommandExecSession(
      client: _client,
      processId: normalizedProcessId,
      tty: request.tty,
    );
    session.start(request);
    return session;
  }

  void _validateRequest(CommandExecRequest request) {
    if (request.command.isEmpty || request.command.first.trim().isEmpty) {
      throw ArgumentError.value(
        request.command,
        'command',
        'must include an executable',
      );
    }
    if (request.timeoutMs != null && request.disableTimeout) {
      throw ArgumentError(
        'timeoutMs and disableTimeout cannot both be configured',
      );
    }
    if (request.outputBytesCap != null && request.disableOutputCap) {
      throw ArgumentError(
        'outputBytesCap and disableOutputCap cannot both be configured',
      );
    }
    final size = request.size;
    if (size != null) {
      if (!request.tty) {
        throw ArgumentError('Terminal size requires tty mode');
      }
      _validateSize(size);
    }
  }
}

class _CodexCommandExecSession implements CommandExecSession {
  _CodexCommandExecSession({
    required CodexAppServerClient client,
    required this.processId,
    required bool tty,
  }) : _client = client,
       _tty = tty {
    _notificationSubscription = _client.notifications.listen(
      _handleNotification,
      onError: _outputController.addError,
    );
  }

  final CodexAppServerClient _client;
  final bool _tty;
  final StreamController<CommandExecOutputChunk> _outputController =
      StreamController.broadcast();
  final Completer<WorkspaceCommandResult> _doneCompleter = Completer();
  late final StreamSubscription<Map<String, Object?>> _notificationSubscription;
  bool _started = false;
  bool _completed = false;

  @override
  final String processId;

  @override
  Stream<CommandExecOutputChunk> get output => _outputController.stream;

  @override
  Future<WorkspaceCommandResult> get done => _doneCompleter.future;

  @override
  bool get isCompleted => _completed;

  void start(CommandExecRequest request) {
    if (_started) {
      throw StateError('Command exec session already started');
    }
    _started = true;
    unawaited(_run(request));
  }

  Future<void> _run(CommandExecRequest request) async {
    try {
      final response = await _client.execCommand(
        command: request.command,
        processId: processId,
        cwd: request.cwd,
        env: request.env,
        tty: request.tty,
        streamStdin: true,
        streamStdoutStderr: true,
        size: request.size?.toJson(),
        timeoutMs: request.timeoutMs,
        disableTimeout: request.disableTimeout,
        outputBytesCap: request.outputBytesCap,
        disableOutputCap: request.disableOutputCap,
        sandboxPolicy: request.sandboxPolicy,
      );
      _doneCompleter.complete(WorkspaceCommandResult.fromJson(response));
    } on Object catch (error, stackTrace) {
      _doneCompleter.completeError(error, stackTrace);
    } finally {
      _completed = true;
      await _notificationSubscription.cancel();
      await _outputController.close();
    }
  }

  void _handleNotification(Map<String, Object?> notification) {
    if (notification['method'] != 'command/exec/outputDelta') {
      return;
    }
    final params = notification['params'];
    if (params is! Map) {
      return;
    }
    final normalizedParams = params.cast<String, Object?>();
    if (normalizedParams['processId'] != processId) {
      return;
    }
    try {
      _outputController.add(_parseOutputChunk(normalizedParams));
    } on Object catch (error, stackTrace) {
      _outputController.addError(error, stackTrace);
    }
  }

  @override
  Future<void> write(List<int> bytes, {bool closeStdin = false}) async {
    _ensureActive();
    if (bytes.isEmpty && !closeStdin) {
      return;
    }
    await _client.writeExecCommand(
      processId: processId,
      deltaBase64: bytes.isEmpty ? null : base64Encode(bytes),
      closeStdin: closeStdin,
    );
  }

  @override
  Future<void> closeStdin() {
    return write(const [], closeStdin: true);
  }

  @override
  Future<void> resize(CommandExecTerminalSize size) async {
    _ensureActive();
    if (!_tty) {
      throw StateError('Cannot resize a non-PTY command');
    }
    _validateSize(size);
    await _client.resizeExecCommand(
      processId: processId,
      rows: size.rows,
      cols: size.cols,
    );
  }

  @override
  Future<void> terminate() async {
    if (_completed) {
      return;
    }
    await _client.terminateExecCommand(processId: processId);
  }

  void _ensureActive() {
    if (_completed) {
      throw StateError('Command exec session has completed');
    }
  }
}

CommandExecOutputChunk _parseOutputChunk(Map<String, Object?> params) {
  final processId = params['processId'];
  final stream = params['stream'];
  final deltaBase64 = params['deltaBase64'];
  if (processId is! String || processId.trim().isEmpty) {
    throw const FormatException('Command exec output is missing processId');
  }
  if (deltaBase64 is! String) {
    throw const FormatException('Command exec output is missing deltaBase64');
  }
  final outputStream = switch (stream) {
    'stdout' => CommandExecOutputStream.stdout,
    'stderr' => CommandExecOutputStream.stderr,
    _ => throw FormatException('Unknown command exec output stream: $stream'),
  };
  return CommandExecOutputChunk(
    processId: processId,
    stream: outputStream,
    bytes: Uint8List.fromList(base64Decode(deltaBase64)),
    capReached: params['capReached'] == true,
  );
}

void _validateSize(CommandExecTerminalSize size) {
  if (size.rows <= 0 || size.cols <= 0) {
    throw ArgumentError.value(size, 'size', 'rows and cols must be positive');
  }
}
