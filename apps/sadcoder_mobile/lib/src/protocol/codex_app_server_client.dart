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

  Future<Map<String, Object?>> listPermissionProfiles({
    String? cwd,
    String? cursor,
    int? limit,
  }) {
    final params = <String, Object?>{};
    if (cursor != null && cursor.trim().isNotEmpty) {
      params['cursor'] = cursor.trim();
    }
    if (limit != null) {
      params['limit'] = limit;
    }
    if (cwd != null && cwd.trim().isNotEmpty) {
      params['cwd'] = cwd.trim();
    }
    return _request('permissionProfile/list', params);
  }

  Future<Map<String, Object?>> listMcpServerStatus({
    String? threadId,
    String? cursor,
    int? limit,
    String? detail,
  }) {
    final params = <String, Object?>{};
    if (threadId != null && threadId.trim().isNotEmpty) {
      params['threadId'] = threadId.trim();
    }
    if (cursor != null && cursor.trim().isNotEmpty) {
      params['cursor'] = cursor.trim();
    }
    if (limit != null) {
      params['limit'] = limit;
    }
    if (detail != null && detail.trim().isNotEmpty) {
      params['detail'] = detail.trim();
    }
    return _request('mcpServerStatus/list', params);
  }

  Future<Map<String, Object?>> readAccount({bool refreshToken = false}) {
    return _request('account/read', {'refreshToken': refreshToken});
  }

  Future<Map<String, Object?>> readAccountRateLimits() {
    return _request('account/rateLimits/read');
  }

  Future<Map<String, Object?>> readAccountUsage() {
    return _request('account/usage/read');
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

  Future<Map<String, Object?>> forkThread({
    required String threadId,
    String? lastTurnId,
    bool ephemeral = false,
  }) {
    final params = <String, Object?>{'threadId': threadId};
    if (lastTurnId != null && lastTurnId.trim().isNotEmpty) {
      params['lastTurnId'] = lastTurnId.trim();
    }
    if (ephemeral) {
      params['ephemeral'] = true;
    }
    return _request('thread/fork', params);
  }

  Future<Map<String, Object?>> compactThread({required String threadId}) {
    return _request('thread/compact/start', {'threadId': threadId});
  }

  Future<Map<String, Object?>> listThreadBackgroundTerminals({
    required String threadId,
    String? cursor,
    int? limit,
  }) {
    final params = <String, Object?>{'threadId': threadId};
    if (cursor != null && cursor.trim().isNotEmpty) {
      params['cursor'] = cursor.trim();
    }
    if (limit != null) {
      params['limit'] = limit;
    }
    return _request('thread/backgroundTerminals/list', params);
  }

  Future<Map<String, Object?>> cleanThreadBackgroundTerminals({
    required String threadId,
  }) {
    return _request('thread/backgroundTerminals/clean', {'threadId': threadId});
  }

  Future<Map<String, Object?>> listSkills({
    List<String> cwds = const [],
    bool forceReload = false,
  }) {
    final normalizedCwds = [
      for (final cwd in cwds)
        if (cwd.trim().isNotEmpty) cwd.trim(),
    ];
    return _request('skills/list', {
      if (normalizedCwds.isNotEmpty) 'cwds': normalizedCwds,
      if (forceReload) 'forceReload': true,
    });
  }

  Future<Map<String, Object?>> listPlugins({
    List<String> cwds = const [],
    List<String> marketplaceKinds = const [],
  }) {
    final normalizedCwds = [
      for (final cwd in cwds)
        if (cwd.trim().isNotEmpty) cwd.trim(),
    ];
    final normalizedKinds = [
      for (final kind in marketplaceKinds)
        if (kind.trim().isNotEmpty) kind.trim(),
    ];
    return _request('plugin/list', {
      if (normalizedCwds.isNotEmpty) 'cwds': normalizedCwds,
      if (normalizedKinds.isNotEmpty) 'marketplaceKinds': normalizedKinds,
    });
  }

  Future<Map<String, Object?>> getThreadGoal({required String threadId}) {
    return _request('thread/goal/get', {'threadId': threadId});
  }

  Future<Map<String, Object?>> setThreadGoal({
    required String threadId,
    String? objective,
    String? status,
    int? tokenBudget,
  }) {
    final params = <String, Object?>{'threadId': threadId};
    if (objective != null && objective.trim().isNotEmpty) {
      params['objective'] = objective.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    if (tokenBudget != null) {
      params['tokenBudget'] = tokenBudget;
    }
    return _request('thread/goal/set', params);
  }

  Future<Map<String, Object?>> clearThreadGoal({required String threadId}) {
    return _request('thread/goal/clear', {'threadId': threadId});
  }

  Future<Map<String, Object?>> startReview({
    required String threadId,
    required Map<String, Object?> target,
    String? delivery,
  }) {
    final params = <String, Object?>{'threadId': threadId, 'target': target};
    if (delivery != null && delivery.trim().isNotEmpty) {
      params['delivery'] = delivery.trim();
    }
    return _request('review/start', params);
  }

  Future<Map<String, Object?>> setThreadName({
    required String threadId,
    required String name,
  }) {
    return _request('thread/name/set', {'threadId': threadId, 'name': name});
  }

  Future<Map<String, Object?>> archiveThread({required String threadId}) {
    return _request('thread/archive', {'threadId': threadId});
  }

  Future<Map<String, Object?>> deleteThread({required String threadId}) {
    return _request('thread/delete', {'threadId': threadId});
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
