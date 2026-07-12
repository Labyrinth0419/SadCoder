import '../config/codex_config_overrides.dart';
import '../events/guardian_assessment_event.dart';
import '../turns/turn_text_element.dart';
import 'json_rpc.dart';

class CodexAppServerClient {
  CodexAppServerClient(this._transport);

  final JsonRpcTransport _transport;
  int _nextId = 1;

  Stream<Map<String, Object?>> get notifications => _transport.notifications;

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

  Future<Map<String, Object?>> listModels({
    String? cursor,
    int? limit,
    bool includeHidden = false,
  }) {
    final params = <String, Object?>{};
    if (cursor != null && cursor.trim().isNotEmpty) {
      params['cursor'] = cursor.trim();
    }
    if (limit != null) {
      params['limit'] = limit;
    }
    if (includeHidden) {
      params['includeHidden'] = true;
    }
    return _request('model/list', params);
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

  Future<Map<String, Object?>> reloadMcpServers() {
    return _request('config/mcpServer/reload');
  }

  Future<Map<String, Object?>> startMcpServerOAuthLogin({
    required String serverName,
  }) {
    return _request('mcpServer/oauth/login', {'serverName': serverName.trim()});
  }

  Future<Map<String, Object?>> readAccount({bool refreshToken = false}) {
    return _request('account/read', {'refreshToken': refreshToken});
  }

  Future<Map<String, Object?>> logoutAccount() {
    return _request('account/logout');
  }

  Future<Map<String, Object?>> uploadFeedback({
    required String classification,
    String? reason,
    String? threadId,
    String? turnId,
    bool includeLogs = false,
  }) {
    final trimmedReason = reason?.trim();
    final trimmedThreadId = threadId?.trim();
    final trimmedTurnId = turnId?.trim();
    return _request('feedback/upload', {
      'classification': classification,
      if (trimmedReason != null && trimmedReason.isNotEmpty)
        'reason': trimmedReason,
      if (trimmedThreadId != null && trimmedThreadId.isNotEmpty)
        'threadId': trimmedThreadId,
      if (includeLogs) 'includeLogs': true,
      if (trimmedTurnId != null && trimmedTurnId.isNotEmpty)
        'tags': {'turn_id': trimmedTurnId},
    });
  }

  Future<Map<String, Object?>> runThreadShellCommand({
    required String threadId,
    required String command,
  }) {
    return _request('thread/shellCommand', {
      'threadId': threadId,
      'command': command,
    });
  }

  Future<Map<String, Object?>> execCommand({
    required List<String> command,
    String? processId,
    String? cwd,
    Map<String, String?> env = const {},
    bool tty = false,
    bool streamStdin = false,
    bool streamStdoutStderr = false,
    Map<String, Object?>? size,
    int? timeoutMs,
    bool disableTimeout = false,
    int? outputBytesCap,
    bool disableOutputCap = false,
    Map<String, Object?>? sandboxPolicy,
  }) {
    final trimmedProcessId = processId?.trim();
    final trimmedCwd = cwd?.trim();
    final normalizedEnv = <String, Object?>{
      for (final entry in env.entries)
        if (entry.key.trim().isNotEmpty) entry.key.trim(): entry.value,
    };
    final params = <String, Object?>{'command': command};
    if (trimmedProcessId != null && trimmedProcessId.isNotEmpty) {
      params['processId'] = trimmedProcessId;
    }
    if (tty) {
      params['tty'] = true;
    }
    if (streamStdin) {
      params['streamStdin'] = true;
    }
    if (streamStdoutStderr) {
      params['streamStdoutStderr'] = true;
    }
    if (trimmedCwd != null && trimmedCwd.isNotEmpty) {
      params['cwd'] = trimmedCwd;
    }
    if (normalizedEnv.isNotEmpty) {
      params['env'] = normalizedEnv;
    }
    if (disableTimeout) {
      params['disableTimeout'] = true;
    } else if (timeoutMs != null) {
      params['timeoutMs'] = timeoutMs;
    }
    if (disableOutputCap) {
      params['disableOutputCap'] = true;
    } else if (outputBytesCap != null) {
      params['outputBytesCap'] = outputBytesCap;
    }
    if (size != null) {
      params['size'] = size;
    }
    if (sandboxPolicy?.isNotEmpty == true) {
      params['sandboxPolicy'] = sandboxPolicy;
    }
    return _request('command/exec', params);
  }

  Future<Map<String, Object?>> writeExecCommand({
    required String processId,
    String? deltaBase64,
    bool closeStdin = false,
  }) {
    return _request('command/exec/write', {
      'processId': processId,
      'deltaBase64': ?deltaBase64,
      if (closeStdin) 'closeStdin': true,
    });
  }

  Future<Map<String, Object?>> resizeExecCommand({
    required String processId,
    required int rows,
    required int cols,
  }) {
    return _request('command/exec/resize', {
      'processId': processId,
      'size': {'rows': rows, 'cols': cols},
    });
  }

  Future<Map<String, Object?>> terminateExecCommand({
    required String processId,
  }) {
    return _request('command/exec/terminate', {'processId': processId});
  }

  Future<Map<String, Object?>> searchFiles({
    required String query,
    List<String> roots = const [],
    String? cancellationToken,
  }) {
    final normalizedRoots = [
      for (final root in roots)
        if (root.trim().isNotEmpty) root.trim(),
    ];
    final trimmedCancellationToken = cancellationToken?.trim();
    return _request('fuzzyFileSearch', {
      'query': query,
      'roots': normalizedRoots,
      if (trimmedCancellationToken != null &&
          trimmedCancellationToken.isNotEmpty)
        'cancellation_token': trimmedCancellationToken,
    });
  }

  Future<Map<String, Object?>> fsReadFile({
    required String path,
    int? offset,
    int? limitBytes,
    String? encoding,
  }) {
    final params = <String, Object?>{'path': path.trim()};
    if (offset != null) {
      params['offset'] = offset;
    }
    if (limitBytes != null) {
      params['limitBytes'] = limitBytes;
    }
    if (encoding != null && encoding.trim().isNotEmpty) {
      params['encoding'] = encoding.trim();
    }
    return _request('fs/readFile', params);
  }

  Future<Map<String, Object?>> fsGetMetadata({required String path}) {
    return _request('fs/getMetadata', {'path': path.trim()});
  }

  Future<Map<String, Object?>> fsReadDirectory({required String path}) {
    return _request('fs/readDirectory', {'path': path.trim()});
  }

  Future<Map<String, Object?>> workspaceDirectoryList({
    required String root,
    String path = '',
    int? limit,
    String? cursor,
    bool includeHidden = false,
  }) {
    final trimmedCursor = cursor?.trim();
    final params = <String, Object?>{
      'root': root.trim(),
      'path': path.trim(),
      'includeHidden': includeHidden,
    };
    if (limit != null) {
      params['limit'] = limit;
    }
    if (trimmedCursor != null && trimmedCursor.isNotEmpty) {
      params['cursor'] = trimmedCursor;
    }
    return _request('workspace/directoryList', params);
  }

  Future<Map<String, Object?>> workspaceFileStat({
    required String root,
    required String path,
  }) {
    return _request('workspace/fileStat', {
      'root': root.trim(),
      'path': path.trim(),
    });
  }

  Future<Map<String, Object?>> workspaceFileRead({
    required String root,
    required String path,
    int? offset,
    int? limitBytes,
    String? encoding,
  }) {
    final params = <String, Object?>{'root': root.trim(), 'path': path.trim()};
    if (offset != null) {
      params['offset'] = offset;
    }
    if (limitBytes != null) {
      params['limitBytes'] = limitBytes;
    }
    if (encoding != null && encoding.trim().isNotEmpty) {
      params['encoding'] = encoding.trim();
    }
    return _request('workspace/fileRead', params);
  }

  Future<Map<String, Object?>> agentHello() {
    return _request('agent/hello');
  }

  Future<Map<String, Object?>> agentHealth() {
    return _request('agent/health');
  }

  Future<Map<String, Object?>> agentLogs({int? tailBytes}) {
    final params = <String, Object?>{};
    if (tailBytes != null && tailBytes > 0) {
      params['tailBytes'] = tailBytes;
    }
    return _request('agent/logs', params.isEmpty ? null : params);
  }

  Future<Map<String, Object?>> agentSchema({
    bool refresh = false,
    bool experimental = false,
  }) {
    final params = <String, Object?>{};
    if (refresh) {
      params['refresh'] = true;
    }
    if (experimental) {
      params['experimental'] = true;
    }
    return _request('agent/schema', params.isEmpty ? null : params);
  }

  Future<Map<String, Object?>> agentSnapshot({String? sinceCursor}) {
    final params = <String, Object?>{};
    final trimmedCursor = sinceCursor?.trim();
    if (trimmedCursor != null && trimmedCursor.isNotEmpty) {
      params['sinceCursor'] = trimmedCursor;
    }
    return _request('agent/snapshot', params.isEmpty ? null : params);
  }

  Future<Map<String, Object?>> agentSlashCommandsList() {
    return _request('agent/slashCommands/list');
  }

  Future<Map<String, Object?>> agentRestartBackend() {
    return _request('agent/restartBackend');
  }

  Future<Map<String, Object?>> agentStopBackend() {
    return _request('agent/stopBackend');
  }

  Future<Map<String, Object?>> agentPing() {
    return _request('agent/ping');
  }

  Future<Map<String, Object?>> readAccountRateLimits() {
    return _request('account/rateLimits/read');
  }

  Future<Map<String, Object?>> readAccountUsage() {
    return _request('account/usage/read');
  }

  Future<Map<String, Object?>> listThreads({
    int limit = 20,
    bool archived = false,
  }) {
    return _request('thread/list', {
      'limit': limit,
      if (archived) 'archived': true,
    });
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

  Future<Map<String, Object?>> listThreadTurns({
    required String threadId,
    String? cursor,
    int? limit,
    String? sortDirection,
    String? itemsView,
  }) {
    final params = <String, Object?>{'threadId': threadId};
    if (cursor != null && cursor.trim().isNotEmpty) {
      params['cursor'] = cursor.trim();
    }
    if (limit != null) {
      params['limit'] = limit;
    }
    if (sortDirection != null && sortDirection.trim().isNotEmpty) {
      params['sortDirection'] = sortDirection.trim();
    }
    if (itemsView != null && itemsView.trim().isNotEmpty) {
      params['itemsView'] = itemsView.trim();
    }
    return _request('thread/turns/list', params);
  }

  Future<Map<String, Object?>> listThreadItems({
    required String threadId,
    String? turnId,
    String? cursor,
    int? limit,
    String? sortDirection,
  }) {
    final params = <String, Object?>{'threadId': threadId};
    if (turnId != null && turnId.trim().isNotEmpty) {
      params['turnId'] = turnId.trim();
    }
    if (cursor != null && cursor.trim().isNotEmpty) {
      params['cursor'] = cursor.trim();
    }
    if (limit != null) {
      params['limit'] = limit;
    }
    if (sortDirection != null && sortDirection.trim().isNotEmpty) {
      params['sortDirection'] = sortDirection.trim();
    }
    return _request('thread/items/list', params);
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
    String? developerInstructions,
  }) {
    final params = <String, Object?>{'threadId': threadId};
    if (lastTurnId != null && lastTurnId.trim().isNotEmpty) {
      params['lastTurnId'] = lastTurnId.trim();
    }
    if (developerInstructions != null &&
        developerInstructions.trim().isNotEmpty) {
      params['developerInstructions'] = developerInstructions.trim();
    }
    if (ephemeral) {
      params['ephemeral'] = true;
    }
    return _request('thread/fork', params);
  }

  Future<Map<String, Object?>> injectThreadItems({
    required String threadId,
    required List<Map<String, Object?>> items,
  }) {
    return _request('thread/inject_items', {
      'threadId': threadId,
      'items': items,
    });
  }

  Future<Map<String, Object?>> compactThread({required String threadId}) {
    return _request('thread/compact/start', {'threadId': threadId});
  }

  Future<Map<String, Object?>> updateThreadSettings({
    required String threadId,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
  }) {
    return _request('thread/settings/update', {
      'threadId': threadId,
      ...overrides.toThreadSettingsUpdateParams(includeClears: true),
    });
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

  Future<Map<String, Object?>> approveGuardianDeniedAction({
    required String threadId,
    required GuardianAssessmentEvent event,
  }) {
    return _request('thread/approveGuardianDeniedAction', {
      'threadId': threadId,
      'event': event.toJson(),
    });
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

  Future<Map<String, Object?>> readPlugin({
    required String pluginId,
    List<String> cwds = const [],
  }) {
    final normalizedCwds = [
      for (final cwd in cwds)
        if (cwd.trim().isNotEmpty) cwd.trim(),
    ];
    return _request('plugin/read', {
      'pluginId': pluginId.trim(),
      if (normalizedCwds.isNotEmpty) 'cwds': normalizedCwds,
    });
  }

  Future<Map<String, Object?>> installPlugin({
    required String pluginId,
    List<String> cwds = const [],
  }) {
    final normalizedCwds = [
      for (final cwd in cwds)
        if (cwd.trim().isNotEmpty) cwd.trim(),
    ];
    return _request('plugin/install', {
      'pluginId': pluginId.trim(),
      if (normalizedCwds.isNotEmpty) 'cwds': normalizedCwds,
    });
  }

  Future<Map<String, Object?>> uninstallPlugin({
    required String pluginId,
    List<String> cwds = const [],
  }) {
    final normalizedCwds = [
      for (final cwd in cwds)
        if (cwd.trim().isNotEmpty) cwd.trim(),
    ];
    return _request('plugin/uninstall', {
      'pluginId': pluginId.trim(),
      if (normalizedCwds.isNotEmpty) 'cwds': normalizedCwds,
    });
  }

  Future<Map<String, Object?>> listHooks({List<String> cwds = const []}) {
    final normalizedCwds = [
      for (final cwd in cwds)
        if (cwd.trim().isNotEmpty) cwd.trim(),
    ];
    return _request('hooks/list', {
      if (normalizedCwds.isNotEmpty) 'cwds': normalizedCwds,
    });
  }

  Future<Map<String, Object?>> listApps({
    String? cursor,
    int? limit,
    String? threadId,
    bool forceRefetch = false,
  }) {
    final params = <String, Object?>{};
    if (cursor != null && cursor.trim().isNotEmpty) {
      params['cursor'] = cursor.trim();
    }
    if (limit != null) {
      params['limit'] = limit;
    }
    if (threadId != null && threadId.trim().isNotEmpty) {
      params['threadId'] = threadId.trim();
    }
    if (forceRefetch) {
      params['forceRefetch'] = true;
    }
    return _request('app/list', params);
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

  Future<Map<String, Object?>> unarchiveThread({required String threadId}) {
    return _request('thread/unarchive', {'threadId': threadId});
  }

  Future<Map<String, Object?>> deleteThread({required String threadId}) {
    return _request('thread/delete', {'threadId': threadId});
  }

  Future<Map<String, Object?>> startTurn({
    required String threadId,
    required String text,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
    List<TurnTextElement> textElements = const [],
  }) {
    return _request('turn/start', {
      'threadId': threadId,
      'input': [
        {
          'type': 'text',
          'text': text,
          'text_elements': [
            for (final element in textElements) element.toJson(),
          ],
        },
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
