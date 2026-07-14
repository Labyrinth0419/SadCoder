import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../command_exec/command_exec_runner.dart';
import '../protocol/codex_app_server_client.dart';
import '../workspace/workspace_command_runner.dart';
import 'process_runner.dart';

typedef ProcessHandleFactory = String Function();

class CodexProcessRunner implements ProcessRunner {
  CodexProcessRunner(this._client, {ProcessHandleFactory? processHandleFactory})
    : _processHandleFactory = processHandleFactory;

  final CodexAppServerClient _client;
  final ProcessHandleFactory? _processHandleFactory;
  int _nextProcessHandle = 1;

  @override
  Future<CommandExecSession> start(CommandExecRequest request) async {
    _validateRequest(request);
    final processHandle =
        _processHandleFactory?.call() ??
        'sadcoder-host-${DateTime.now().microsecondsSinceEpoch}-'
            '${_nextProcessHandle++}';
    final normalizedHandle = processHandle.trim();
    if (normalizedHandle.isEmpty) {
      throw StateError('Process handle must not be empty');
    }

    final session = _CodexProcessSession(
      client: _client,
      processHandle: normalizedHandle,
      tty: request.tty,
    );
    await session.start(request);
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
    if (request.cwd == null || request.cwd!.trim().isEmpty) {
      throw ArgumentError.value(request.cwd, 'cwd', 'must be an absolute path');
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
    if (request.sandboxPolicy != null) {
      throw ArgumentError(
        'process/spawn runs without a Codex sandbox and does not accept '
        'sandboxPolicy',
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

class _CodexProcessSession implements CommandExecSession {
  _CodexProcessSession({
    required CodexAppServerClient client,
    required String processHandle,
    required bool tty,
  }) : _client = client,
       processId = processHandle,
       _tty = tty {
    _notificationSubscription = _client.notifications.listen(
      _handleNotification,
      onError: _handleStreamError,
    );
  }

  final CodexAppServerClient _client;
  final bool _tty;
  final StreamController<CommandExecOutputChunk> _outputController =
      StreamController.broadcast();
  final Completer<WorkspaceCommandResult> _doneCompleter = Completer();
  final Completer<void> _startedCompleter = Completer();
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

  Future<void> start(CommandExecRequest request) {
    if (_started) {
      throw StateError('Process session already started');
    }
    _started = true;
    unawaited(_spawn(request));
    return _startedCompleter.future;
  }

  Future<void> _spawn(CommandExecRequest request) async {
    try {
      await _client.spawnProcess(
        command: request.command,
        processHandle: processId,
        cwd: request.cwd!,
        tty: request.tty,
        streamStdin: true,
        streamStdoutStderr: true,
        env: request.env,
        size: request.size?.toJson(),
        timeoutMs: request.timeoutMs,
        disableTimeout: request.disableTimeout,
        outputBytesCap: request.outputBytesCap,
        disableOutputCap: request.disableOutputCap,
      );
      if (!_startedCompleter.isCompleted) {
        _startedCompleter.complete();
      }
    } on Object catch (error, stackTrace) {
      _startedCompleter.completeError(error, stackTrace);
      _completed = true;
      unawaited(_close());
    }
  }

  void _handleNotification(Map<String, Object?> notification) {
    final method = notification['method'];
    final params = _objectMap(notification['params']);
    final handle = params['processHandle'] ?? params['process_handle'];
    if (handle != processId) {
      return;
    }
    if (method == 'process/outputDelta') {
      try {
        _outputController.add(_parseOutputChunk(params));
      } on Object catch (error, stackTrace) {
        _outputController.addError(error, stackTrace);
      }
      return;
    }
    if (method == 'process/exited') {
      try {
        final result = WorkspaceCommandResult.fromJson(params);
        _addBufferedOutput(params, result);
        _complete(result);
      } on Object catch (error, stackTrace) {
        _completeError(error, stackTrace);
      }
    }
  }

  void _addBufferedOutput(
    Map<String, Object?> params,
    WorkspaceCommandResult result,
  ) {
    if (result.stdout.isNotEmpty) {
      _outputController.add(
        CommandExecOutputChunk(
          processId: processId,
          stream: CommandExecOutputStream.stdout,
          bytes: Uint8List.fromList(utf8.encode(result.stdout)),
          capReached:
              params['stdoutCapReached'] == true ||
              params['stdout_cap_reached'] == true,
        ),
      );
    }
    if (result.stderr.isNotEmpty) {
      _outputController.add(
        CommandExecOutputChunk(
          processId: processId,
          stream: CommandExecOutputStream.stderr,
          bytes: Uint8List.fromList(utf8.encode(result.stderr)),
          capReached:
              params['stderrCapReached'] == true ||
              params['stderr_cap_reached'] == true,
        ),
      );
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (!_completed) {
      _outputController.addError(error, stackTrace);
    }
  }

  @override
  Future<void> write(List<int> bytes, {bool closeStdin = false}) async {
    _ensureActive();
    if (bytes.isEmpty && !closeStdin) {
      return;
    }
    await _client.writeProcessStdin(
      processHandle: processId,
      deltaBase64: bytes.isEmpty ? null : base64Encode(bytes),
      closeStdin: closeStdin,
    );
  }

  @override
  Future<void> closeStdin() => write(const [], closeStdin: true);

  @override
  Future<void> resize(CommandExecTerminalSize size) async {
    _ensureActive();
    if (!_tty) {
      throw StateError('Cannot resize a non-PTY process');
    }
    _validateSize(size);
    await _client.resizeProcessPty(
      processHandle: processId,
      rows: size.rows,
      cols: size.cols,
    );
  }

  @override
  Future<void> terminate() async {
    if (_completed) {
      return;
    }
    await _client.killProcess(processHandle: processId);
  }

  void _ensureActive() {
    if (_completed) {
      throw StateError('Process session has completed');
    }
  }

  void _complete(WorkspaceCommandResult result) {
    if (_completed) {
      return;
    }
    _completed = true;
    _doneCompleter.complete(result);
    unawaited(_close());
  }

  void _completeError(Object error, StackTrace stackTrace) {
    if (_completed) {
      return;
    }
    _completed = true;
    _doneCompleter.completeError(error, stackTrace);
    unawaited(_close());
  }

  Future<void> _close() async {
    await _notificationSubscription.cancel();
    await _outputController.close();
  }
}

CommandExecOutputChunk _parseOutputChunk(Map<String, Object?> params) {
  final processHandle = params['processHandle'] ?? params['process_handle'];
  final stream = params['stream'];
  final deltaBase64 = params['deltaBase64'] ?? params['delta_base64'];
  if (processHandle is! String || processHandle.trim().isEmpty) {
    throw const FormatException('Process output is missing processHandle');
  }
  if (deltaBase64 is! String) {
    throw const FormatException('Process output is missing deltaBase64');
  }
  final outputStream = switch (stream) {
    'stdout' => CommandExecOutputStream.stdout,
    'stderr' => CommandExecOutputStream.stderr,
    _ => throw FormatException('Unknown process output stream: $stream'),
  };
  return CommandExecOutputChunk(
    processId: processHandle,
    stream: outputStream,
    bytes: Uint8List.fromList(base64Decode(deltaBase64)),
    capReached: params['capReached'] == true || params['cap_reached'] == true,
  );
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

void _validateSize(CommandExecTerminalSize size) {
  if (size.rows <= 0 || size.cols <= 0) {
    throw ArgumentError.value(size, 'size', 'rows and cols must be positive');
  }
}
