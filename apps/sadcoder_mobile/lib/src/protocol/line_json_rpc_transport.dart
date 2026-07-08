import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'json_rpc.dart';

class LineJsonRpcTransport implements JsonRpcTransport {
  LineJsonRpcTransport({
    required Stream<List<int>> input,
    required StreamSink<Uint8List> output,
  }) : _output = output {
    _subscription = utf8.decoder
        .bind(input)
        .transform(const LineSplitter())
        .listen(_handleLine, onError: _handleError, onDone: _handleDone);
  }

  final StreamSink<Uint8List> _output;
  final Map<Object, Completer<Map<String, Object?>>> _pending = {};
  final StreamController<Map<String, Object?>> _notifications =
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
  Stream<Map<String, Object?>> get notifications => _notifications.stream;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _notifications.close();
    await _output.close();
  }

  Future<void> _write(Map<String, Object?> message) {
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

    final id = decoded['id'];
    if (id != null && _pending.containsKey(id)) {
      final completer = _pending.remove(id);
      final error = decoded['error'];
      if (error != null) {
        completer?.completeError(JsonRpcRemoteException(error.toString()));
      } else {
        completer?.complete(decoded);
      }
      return;
    }

    _notifications.add(decoded);
  }

  void _handleError(Object error, [StackTrace? stackTrace]) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
    _pending.clear();
    _notifications.addError(error, stackTrace);
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
