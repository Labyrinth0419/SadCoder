import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'json_rpc_diagnostic_log.dart';
import 'json_rpc.dart';

class LineJsonRpcTransport implements JsonRpcTransport {
  LineJsonRpcTransport({
    required Stream<List<int>> input,
    required StreamSink<Uint8List> output,
    JsonRpcDiagnosticLogSink? diagnosticLogSink,
  }) : _output = output,
       _diagnosticLogSink = diagnosticLogSink {
    _subscription = utf8.decoder
        .bind(input)
        .transform(const LineSplitter())
        .listen(_handleLine, onError: _handleError, onDone: _handleDone);
  }

  final StreamSink<Uint8List> _output;
  final JsonRpcDiagnosticLogSink? _diagnosticLogSink;
  final Map<Object, Completer<Map<String, Object?>>> _pending = {};
  final StreamController<Map<String, Object?>> _notifications =
      StreamController.broadcast();
  final StreamController<JsonRpcServerRequest> _serverRequests =
      StreamController.broadcast();
  late final StreamSubscription<String> _subscription;

  @override
  Future<Map<String, Object?>> request(JsonRpcRequest request) {
    final completer = Completer<Map<String, Object?>>();
    _pending[request.id] = completer;
    _write(request.toJson());
    return completer.future;
  }

  @override
  Future<void> notify(JsonRpcNotification notification) {
    return _write(notification.toJson());
  }

  @override
  Future<void> respond(JsonRpcResponseMessage response) {
    return _write(response.toJson());
  }

  @override
  Stream<Map<String, Object?>> get notifications => _notifications.stream;

  @override
  Stream<JsonRpcServerRequest> get serverRequests => _serverRequests.stream;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _notifications.close();
    await _serverRequests.close();
    await _output.close();
  }

  Future<void> _write(Map<String, Object?> message) {
    _recordDiagnosticLog(JsonRpcDiagnosticLogDirection.outgoing, message);
    final line = '${jsonEncode(message)}\n';
    _output.add(Uint8List.fromList(utf8.encode(line)));
    return Future.value();
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) {
      return;
    }

    final decoded = jsonDecode(line);
    if (decoded is! Map<String, Object?>) {
      _handleError(FormatException('JSON-RPC line is not an object', line));
      return;
    }
    _recordDiagnosticLog(JsonRpcDiagnosticLogDirection.incoming, decoded);

    final id = decoded['id'];
    final method = decoded['method'];
    if (id != null && _pending.containsKey(id)) {
      final completer = _pending.remove(id);
      final error = decoded['error'];
      if (error != null) {
        completer?.completeError(JsonRpcRemoteException(error.toString()));
      } else {
        final result = decoded['result'];
        if (result is Map<String, Object?>) {
          completer?.complete(result);
        } else if (result is Map) {
          completer?.complete(Map<String, Object?>.from(result));
        } else {
          completer?.completeError(
            FormatException('JSON-RPC result is not an object', line),
          );
        }
      }
      return;
    }

    if (id != null && method is String) {
      _serverRequests.add(
        JsonRpcServerRequest(id: id, method: method, params: decoded['params']),
      );
      return;
    }

    _notifications.add(decoded);
  }

  void _recordDiagnosticLog(
    JsonRpcDiagnosticLogDirection direction,
    Map<String, Object?> message,
  ) {
    try {
      _diagnosticLogSink?.record(direction: direction, message: message);
    } catch (_) {
      // Diagnostic capture must not affect JSON-RPC delivery.
    }
  }

  void _handleError(Object error, [StackTrace? stackTrace]) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
    _pending.clear();
    _notifications.addError(error, stackTrace);
    _serverRequests.addError(error, stackTrace);
  }

  void _handleDone() {
    _handleError(const JsonRpcRemoteException('JSON-RPC stream closed'));
  }
}

class JsonRpcRemoteException implements Exception {
  const JsonRpcRemoteException(this.message);

  final String message;

  @override
  String toString() => message;
}
