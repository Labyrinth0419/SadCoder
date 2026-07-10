import 'dart:async';

class JsonRpcRequest {
  JsonRpcRequest({required this.id, required this.method, this.params});

  final Object id;
  final String method;
  final Map<String, Object?>? params;

  Map<String, Object?> toJson() => {
    'jsonrpc': '2.0',
    'id': id,
    'method': method,
    if (params != null) 'params': params,
  };
}

class JsonRpcNotification {
  JsonRpcNotification({required this.method, this.params});

  final String method;
  final Map<String, Object?>? params;

  Map<String, Object?> toJson() => {
    'jsonrpc': '2.0',
    'method': method,
    if (params != null) 'params': params,
  };
}

class JsonRpcServerRequest {
  const JsonRpcServerRequest({
    required this.id,
    required this.method,
    this.params,
  });

  final Object id;
  final String method;
  final Object? params;
}

class JsonRpcResponseMessage {
  const JsonRpcResponseMessage({required this.id, this.result, this.error});

  final Object id;
  final Object? result;
  final Object? error;

  Map<String, Object?> toJson() => {
    'jsonrpc': '2.0',
    'id': id,
    if (error != null) 'error': error,
    if (error == null) 'result': result,
  };
}

abstract interface class JsonRpcTransport {
  Future<Map<String, Object?>> request(JsonRpcRequest request);

  Future<void> notify(JsonRpcNotification notification);

  Future<void> respond(JsonRpcResponseMessage response);

  Stream<Map<String, Object?>> get notifications;

  Stream<JsonRpcServerRequest> get serverRequests;

  Future<void> close();
}

class JsonRpcRemoteException implements Exception {
  const JsonRpcRemoteException(this.message, {this.code, this.data});

  final String message;
  final int? code;
  final Object? data;

  @override
  String toString() {
    final code = this.code;
    if (code == null) {
      return message;
    }
    return 'JSON-RPC error $code: $message';
  }
}

class MemoryJsonRpcTransport implements JsonRpcTransport {
  MemoryJsonRpcTransport(this._handler);

  final FutureOr<Map<String, Object?>> Function(JsonRpcRequest request)
  _handler;
  final StreamController<Map<String, Object?>> _notifications =
      StreamController.broadcast();
  final StreamController<JsonRpcServerRequest> _serverRequests =
      StreamController.broadcast();
  final List<JsonRpcResponseMessage> responses = [];

  @override
  Future<Map<String, Object?>> request(JsonRpcRequest request) async {
    return _handler(request);
  }

  @override
  Future<void> notify(JsonRpcNotification notification) async {
    _notifications.add(notification.toJson());
  }

  @override
  Future<void> respond(JsonRpcResponseMessage response) async {
    responses.add(response);
  }

  void emitServerRequest(JsonRpcServerRequest request) {
    _serverRequests.add(request);
  }

  void emitNotification(Map<String, Object?> notification) {
    _notifications.add(notification);
  }

  @override
  Stream<Map<String, Object?>> get notifications => _notifications.stream;

  @override
  Stream<JsonRpcServerRequest> get serverRequests => _serverRequests.stream;

  @override
  Future<void> close() async {
    await _notifications.close();
    await _serverRequests.close();
  }
}
