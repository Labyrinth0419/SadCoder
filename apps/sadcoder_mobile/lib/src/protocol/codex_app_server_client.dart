import '../config/codex_config_overrides.dart';
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

  Future<Map<String, Object?>> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) {
    return _request('config/read', {
      if (includeLayers) 'includeLayers': true,
      if (cwd != null && cwd.trim().isNotEmpty) 'cwd': cwd.trim(),
    });
  }

  Future<Map<String, Object?>> readThread({
    required String threadId,
    bool includeTurns = true,
  }) {
    return _request('thread/read', {
      'threadId': threadId,
      'includeTurns': includeTurns,
    });
  }

  Future<Map<String, Object?>> startThread() {
    return _request('thread/start', {});
  }

  Future<Map<String, Object?>> resumeThread({required String threadId}) {
    return _request('thread/resume', {'threadId': threadId});
  }

  Future<Map<String, Object?>> setThreadName({
    required String threadId,
    required String name,
  }) {
    return _request('thread/name/set', {'threadId': threadId, 'name': name});
  }

  Future<Map<String, Object?>> startTurn({
    required String threadId,
    required String text,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
  }) {
    return _request('turn/start', {
      'threadId': threadId,
      'input': [
        {'type': 'text', 'text': text, 'text_elements': <Object?>[]},
      ],
      ...overrides.toTurnStartParams(),
    });
  }

  Future<Map<String, Object?>> interruptTurn({
    required String threadId,
    required String turnId,
  }) {
    return _request('turn/interrupt', {'threadId': threadId, 'turnId': turnId});
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
