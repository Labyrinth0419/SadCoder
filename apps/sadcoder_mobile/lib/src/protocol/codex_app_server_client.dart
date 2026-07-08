import 'json_rpc.dart';

class CodexAppServerClient {
  CodexAppServerClient(this._transport);

  final JsonRpcTransport _transport;
  int _nextId = 1;

  Future<Map<String, Object?>> initialize({
    String clientName = 'sadcoder-mobile',
    bool experimentalApi = true,
  }) async {
    final result = await _request('initialize', {
      'clientInfo': {'name': clientName},
      'capabilities': {'experimentalApi': experimentalApi},
    });
    await _transport.notify(JsonRpcNotification(method: 'initialized'));
    return result;
  }

  Future<Map<String, Object?>> listModels() {
    return _request('model/list', {});
  }

  Future<Map<String, Object?>> listThreads({int limit = 20}) {
    return _request('thread/list', {'limit': limit});
  }

  Future<Map<String, Object?>> _request(
    String method, [
    Map<String, Object?>? params,
  ]) {
    return _transport.request(
      JsonRpcRequest(id: _nextId++, method: method, params: params),
    );
  }
}
