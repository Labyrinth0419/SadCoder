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

abstract interface class JsonRpcTransport {
  Future<Map<String, Object?>> request(JsonRpcRequest request);

  Future<void> notify(JsonRpcNotification notification);

  Stream<Map<String, Object?>> get notifications;

  Future<void> close();
}

class MemoryJsonRpcTransport implements JsonRpcTransport {
  MemoryJsonRpcTransport(this._handler);

  final FutureOr<Map<String, Object?>> Function(JsonRpcRequest request)
  _handler;
  final StreamController<Map<String, Object?>> _notifications =
      StreamController.broadcast();

  @override
  Future<Map<String, Object?>> request(JsonRpcRequest request) async {
    return _handler(request);
  }

  @override
  Future<void> notify(JsonRpcNotification notification) async {
    _notifications.add(notification.toJson());
  }

  @override
  Stream<Map<String, Object?>> get notifications => _notifications.stream;

  @override
  Future<void> close() {
    return _notifications.close();
  }
}
