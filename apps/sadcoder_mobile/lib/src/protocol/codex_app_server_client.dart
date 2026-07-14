import '../config/codex_config_overrides.dart';
import '../events/guardian_assessment_event.dart';
import '../realtime/realtime_runner.dart';
import '../turns/turn_text_element.dart';
import 'codex_client_info.dart';
import 'json_rpc.dart';

class CodexAppServerClient {
  CodexAppServerClient(this._transport);

  final JsonRpcTransport _transport;
  int _nextId = 1;

  Stream<Map<String, Object?>> get notifications => _transport.notifications;

  Future<Map<String, Object?>> requestRaw({
    required String method,
    Map<String, Object?>? params,
  }) {
    final normalizedMethod = method.trim();
    if (normalizedMethod.isEmpty) {
      throw ArgumentError.value(method, 'method', 'method must not be blank');
    }
    return _request(normalizedMethod, params);
  }

  Future<Map<String, Object?>> initialize({
    String clientName = sadcoderMobileClientName,
    String clientVersion = sadcoderMobileClientVersion,
    bool experimentalApi = true,
  }) async {
    final result = await _request('initialize', {
      'clientInfo': {'name': clientName, 'version': clientVersion},
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

  Future<Map<String, Object?>> addEnvironment({
    required String environmentId,
    required String execServerUrl,
    int? connectTimeoutMs,
  }) {
    final normalizedId = environmentId.trim();
    final normalizedUrl = execServerUrl.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        environmentId,
        'environmentId',
        'environmentId must not be blank',
      );
    }
    if (normalizedUrl.isEmpty) {
      throw ArgumentError.value(
        execServerUrl,
        'execServerUrl',
        'execServerUrl must not be blank',
      );
    }
    return _request('environment/add', {
      'environmentId': normalizedId,
      'execServerUrl': normalizedUrl,
      'connectTimeoutMs': ?connectTimeoutMs,
    });
  }

  Future<Map<String, Object?>> readEnvironmentInfo({
    required String environmentId,
  }) {
    final normalizedId = environmentId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        environmentId,
        'environmentId',
        'environmentId must not be blank',
      );
    }
    return _request('environment/info', {'environmentId': normalizedId});
  }

  Future<Map<String, Object?>> readEnvironmentStatus({
    required String environmentId,
  }) {
    final normalizedId = environmentId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(
        environmentId,
        'environmentId',
        'environmentId must not be blank',
      );
    }
    return _request('environment/status', {'environmentId': normalizedId});
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

  Future<Map<String, Object?>> spawnProcess({
    required List<String> command,
    required String processHandle,
    required String cwd,
    bool tty = false,
    bool streamStdin = false,
    bool streamStdoutStderr = false,
    Map<String, String?> env = const {},
    Map<String, Object?>? size,
    int? timeoutMs,
    bool disableTimeout = false,
    int? outputBytesCap,
    bool disableOutputCap = false,
  }) {
    final normalizedHandle = processHandle.trim();
    final normalizedCwd = cwd.trim();
    if (command.isEmpty || command.first.trim().isEmpty) {
      throw ArgumentError.value(
        command,
        'command',
        'must include an executable',
      );
    }
    if (normalizedHandle.isEmpty) {
      throw ArgumentError.value(
        processHandle,
        'processHandle',
        'must not be blank',
      );
    }
    if (normalizedCwd.isEmpty) {
      throw ArgumentError.value(cwd, 'cwd', 'must not be blank');
    }
    final params = <String, Object?>{
      'command': command,
      'processHandle': normalizedHandle,
      'cwd': normalizedCwd,
      if (tty) 'tty': true,
      if (streamStdin) 'streamStdin': true,
      if (streamStdoutStderr) 'streamStdoutStderr': true,
      'env': ?(env.isEmpty ? null : env),
      'size': ?size,
    };
    if (disableOutputCap) {
      params['outputBytesCap'] = null;
    } else if (outputBytesCap != null) {
      params['outputBytesCap'] = outputBytesCap;
    }
    if (disableTimeout) {
      params['timeoutMs'] = null;
    } else if (timeoutMs != null) {
      params['timeoutMs'] = timeoutMs;
    }
    return _request('process/spawn', params);
  }

  Future<Map<String, Object?>> writeProcessStdin({
    required String processHandle,
    String? deltaBase64,
    bool closeStdin = false,
  }) {
    return _request('process/writeStdin', {
      'processHandle': processHandle.trim(),
      'deltaBase64': ?deltaBase64,
      if (closeStdin) 'closeStdin': true,
    });
  }

  Future<Map<String, Object?>> killProcess({required String processHandle}) {
    return _request('process/kill', {'processHandle': processHandle.trim()});
  }

  Future<Map<String, Object?>> resizeProcessPty({
    required String processHandle,
    required int rows,
    required int cols,
  }) {
    return _request('process/resizePty', {
      'processHandle': processHandle.trim(),
      'size': {'rows': rows, 'cols': cols},
    });
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

  Future<Map<String, Object?>> fsWriteFile({
    required String path,
    required String dataBase64,
  }) {
    final normalizedPath = path.trim();
    final normalizedData = dataBase64.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', 'path must not be blank');
    }
    return _request('fs/writeFile', {
      'path': normalizedPath,
      'dataBase64': normalizedData,
    });
  }

  Future<Map<String, Object?>> fsCreateDirectory({
    required String path,
    bool recursive = true,
  }) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', 'path must not be blank');
    }
    return _request('fs/createDirectory', {
      'path': normalizedPath,
      'recursive': recursive,
    });
  }

  Future<Map<String, Object?>> fsRemove({
    required String path,
    bool recursive = false,
    bool force = false,
  }) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', 'path must not be blank');
    }
    return _request('fs/remove', {
      'path': normalizedPath,
      'recursive': recursive,
      'force': force,
    });
  }

  Future<Map<String, Object?>> fsCopy({
    required String sourcePath,
    required String destinationPath,
    bool recursive = false,
  }) {
    final normalizedSource = sourcePath.trim();
    final normalizedDestination = destinationPath.trim();
    if (normalizedSource.isEmpty) {
      throw ArgumentError.value(
        sourcePath,
        'sourcePath',
        'source path must not be blank',
      );
    }
    if (normalizedDestination.isEmpty) {
      throw ArgumentError.value(
        destinationPath,
        'destinationPath',
        'destination path must not be blank',
      );
    }
    return _request('fs/copy', {
      'sourcePath': normalizedSource,
      'destinationPath': normalizedDestination,
      'recursive': recursive,
    });
  }

  Future<Map<String, Object?>> fsWatch({
    required String watchId,
    required String path,
  }) {
    final normalizedWatchId = watchId.trim();
    final normalizedPath = path.trim();
    if (normalizedWatchId.isEmpty) {
      throw ArgumentError.value(
        watchId,
        'watchId',
        'watchId must not be blank',
      );
    }
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', 'path must not be blank');
    }
    return _request('fs/watch', {
      'watchId': normalizedWatchId,
      'path': normalizedPath,
    });
  }

  Future<Map<String, Object?>> fsUnwatch({required String watchId}) {
    final normalizedWatchId = watchId.trim();
    if (normalizedWatchId.isEmpty) {
      throw ArgumentError.value(
        watchId,
        'watchId',
        'watchId must not be blank',
      );
    }
    return _request('fs/unwatch', {'watchId': normalizedWatchId});
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

  Future<Map<String, Object?>> readConfigRequirements() {
    return _request('configRequirements/read');
  }

  Future<Map<String, Object?>> readModelProviderCapabilities() {
    return _request('modelProvider/capabilities/read', const {});
  }

  Future<Map<String, Object?>> listExperimentalFeatures({
    String? cursor,
    int? limit,
    String? threadId,
  }) {
    final normalizedCursor = _nonBlank(cursor);
    final normalizedThreadId = _nonBlank(threadId);
    return _request('experimentalFeature/list', {
      'cursor': ?normalizedCursor,
      'limit': ?limit,
      'threadId': ?normalizedThreadId,
    });
  }

  Future<Map<String, Object?>> listCollaborationModes() {
    return _request('collaborationMode/list', const {});
  }

  Future<Map<String, Object?>> batchWriteConfig({
    required List<Map<String, Object?>> edits,
    String? filePath,
    String? expectedVersion,
    bool reloadUserConfig = false,
  }) {
    return _request('config/batchWrite', {
      'edits': edits,
      if (filePath != null && filePath.trim().isNotEmpty)
        'filePath': filePath.trim(),
      if (expectedVersion != null && expectedVersion.trim().isNotEmpty)
        'expectedVersion': expectedVersion.trim(),
      if (reloadUserConfig) 'reloadUserConfig': true,
    });
  }

  Future<Map<String, Object?>> detectExternalAgentConfig({
    bool includeHome = true,
    List<String> cwds = const [],
  }) {
    final normalizedCwds = [
      for (final cwd in cwds)
        if (cwd.trim().isNotEmpty) cwd.trim(),
    ];
    return _request('externalAgentConfig/detect', {
      if (includeHome) 'includeHome': true,
      if (normalizedCwds.isNotEmpty) 'cwds': normalizedCwds,
    });
  }

  Future<Map<String, Object?>> importExternalAgentConfig({
    required List<Map<String, Object?>> migrationItems,
    String? source,
  }) {
    final normalizedSource = source?.trim();
    return _request('externalAgentConfig/import', {
      'migrationItems': migrationItems,
      if (normalizedSource != null && normalizedSource.isNotEmpty)
        'source': normalizedSource,
    });
  }

  Future<Map<String, Object?>> readExternalAgentConfigImportHistories() {
    return _request('externalAgentConfig/import/readHistories');
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

  Future<Map<String, Object?>> startThreadRealtime({
    required String threadId,
    required String outputModality,
    required Map<String, Object?> transport,
    bool? clientManagedHandoffs,
    bool? flushTranscriptTailOnSessionEnd,
    bool? codexResponsesAsItems,
    String? codexResponseItemPrefix,
    String? codexResponseHandoffPrefix,
    String? model,
    bool? includeStartupContext,
    String? prompt,
    String? realtimeSessionId,
    String? version,
    String? voice,
  }) {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'threadId must not be blank',
      );
    }
    final normalizedModality = outputModality.trim();
    if (normalizedModality.isEmpty) {
      throw ArgumentError.value(
        outputModality,
        'outputModality',
        'outputModality must not be blank',
      );
    }
    return _request('thread/realtime/start', {
      'threadId': normalizedThreadId,
      'clientManagedHandoffs': ?clientManagedHandoffs,
      'flushTranscriptTailOnSessionEnd': ?flushTranscriptTailOnSessionEnd,
      'codexResponsesAsItems': ?codexResponsesAsItems,
      'codexResponseItemPrefix': ?codexResponseItemPrefix,
      'codexResponseHandoffPrefix': ?codexResponseHandoffPrefix,
      'model': ?model,
      'outputModality': normalizedModality,
      'includeStartupContext': ?includeStartupContext,
      'prompt': ?prompt,
      'realtimeSessionId': ?realtimeSessionId,
      'transport': transport,
      'version': ?version,
      'voice': ?voice,
    });
  }

  Future<Map<String, Object?>> appendThreadRealtimeText({
    required String threadId,
    required String text,
    String role = 'user',
  }) {
    final normalizedThreadId = threadId.trim();
    final normalizedText = text.trim();
    if (normalizedThreadId.isEmpty) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'threadId must not be blank',
      );
    }
    if (normalizedText.isEmpty) {
      throw ArgumentError.value(text, 'text', 'text must not be blank');
    }
    final normalizedRole = role.trim();
    if (normalizedRole.isEmpty) {
      throw ArgumentError.value(role, 'role', 'role must not be blank');
    }
    return _request('thread/realtime/appendText', {
      'threadId': normalizedThreadId,
      'text': normalizedText,
      'role': normalizedRole,
    });
  }

  Future<Map<String, Object?>> appendThreadRealtimeAudio({
    required String threadId,
    required RealtimeAudioFrame audio,
  }) {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'threadId must not be blank',
      );
    }
    _validateAudioFrame(audio);
    return _request('thread/realtime/appendAudio', {
      'threadId': normalizedThreadId,
      'audio': audio.toJson(),
    });
  }

  Future<Map<String, Object?>> appendThreadRealtimeSpeech({
    required String threadId,
    required String text,
  }) {
    final normalizedThreadId = threadId.trim();
    final normalizedText = text.trim();
    if (normalizedThreadId.isEmpty) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'threadId must not be blank',
      );
    }
    if (normalizedText.isEmpty) {
      throw ArgumentError.value(text, 'text', 'text must not be blank');
    }
    return _request('thread/realtime/appendSpeech', {
      'threadId': normalizedThreadId,
      'text': normalizedText,
    });
  }

  Future<Map<String, Object?>> stopThreadRealtime({required String threadId}) {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'threadId must not be blank',
      );
    }
    return _request('thread/realtime/stop', {'threadId': normalizedThreadId});
  }

  Future<Map<String, Object?>> listThreadRealtimeVoices() {
    return _request('thread/realtime/listVoices', const {});
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

  Future<Map<String, Object?>> setThreadMemoryMode({
    required String threadId,
    required String mode,
  }) {
    return _request('thread/memoryMode/set', {
      'threadId': threadId,
      'mode': mode,
    });
  }

  Future<Map<String, Object?>> resetMemory() {
    return _request('memory/reset');
  }

  Future<Map<String, Object?>> readWindowsSandboxReadiness() {
    return _request('windowsSandbox/readiness');
  }

  Future<Map<String, Object?>> startWindowsSandboxSetup({
    required String mode,
    String? cwd,
  }) {
    final normalizedCwd = cwd?.trim();
    return _request('windowsSandbox/setupStart', {
      'mode': mode.trim(),
      if (normalizedCwd != null && normalizedCwd.isNotEmpty)
        'cwd': normalizedCwd,
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

  Future<Map<String, Object?>> writeSkillConfig({
    String? path,
    String? name,
    required bool enabled,
  }) {
    final normalizedPath = path?.trim();
    final normalizedName = name?.trim();
    final hasPath = normalizedPath != null && normalizedPath.isNotEmpty;
    final hasName = normalizedName != null && normalizedName.isNotEmpty;
    if (hasPath == hasName) {
      throw ArgumentError(
        'skills/config/write requires exactly one non-blank path or name',
      );
    }
    return _request('skills/config/write', {
      if (hasPath) 'path': normalizedPath,
      if (hasName) 'name': normalizedName,
      'enabled': enabled,
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
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
  }) {
    final params = _pluginSourceParams(
      method: 'plugin/read',
      pluginName: pluginName,
      marketplacePath: marketplacePath,
      remoteMarketplaceName: remoteMarketplaceName,
    );
    return _request('plugin/read', params);
  }

  Future<Map<String, Object?>> installPlugin({
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
  }) {
    final params = _pluginSourceParams(
      method: 'plugin/install',
      pluginName: pluginName,
      marketplacePath: marketplacePath,
      remoteMarketplaceName: remoteMarketplaceName,
    );
    return _request('plugin/install', params);
  }

  Map<String, Object?> _pluginSourceParams({
    required String method,
    required String pluginName,
    String? marketplacePath,
    String? remoteMarketplaceName,
  }) {
    final normalizedPluginName = pluginName.trim();
    if (normalizedPluginName.isEmpty) {
      throw ArgumentError.value(pluginName, 'pluginName', 'must not be blank');
    }
    final normalizedMarketplacePath = marketplacePath?.trim();
    final normalizedRemoteMarketplaceName = remoteMarketplaceName?.trim();
    final hasMarketplacePath =
        normalizedMarketplacePath != null &&
        normalizedMarketplacePath.isNotEmpty;
    final hasRemoteMarketplaceName =
        normalizedRemoteMarketplaceName != null &&
        normalizedRemoteMarketplaceName.isNotEmpty;
    if (hasMarketplacePath == hasRemoteMarketplaceName) {
      throw ArgumentError(
        '$method requires exactly one non-blank marketplacePath or '
        'remoteMarketplaceName',
      );
    }
    return {
      if (hasMarketplacePath) 'marketplacePath': normalizedMarketplacePath,
      if (hasRemoteMarketplaceName)
        'remoteMarketplaceName': normalizedRemoteMarketplaceName,
      'pluginName': normalizedPluginName,
    };
  }

  Future<Map<String, Object?>> uninstallPlugin({required String pluginId}) {
    final normalizedPluginId = pluginId.trim();
    if (normalizedPluginId.isEmpty) {
      throw ArgumentError.value(pluginId, 'pluginId', 'must not be blank');
    }
    return _request('plugin/uninstall', {'pluginId': normalizedPluginId});
  }

  Future<Map<String, Object?>> addMarketplace({
    required String source,
    String? refName,
    List<String> sparsePaths = const [],
  }) {
    final normalizedSource = source.trim();
    if (normalizedSource.isEmpty) {
      throw ArgumentError.value(source, 'source', 'source must not be blank');
    }
    final normalizedRefName = refName?.trim();
    final normalizedSparsePaths = [
      for (final path in sparsePaths)
        if (path.trim().isNotEmpty) path.trim(),
    ];
    return _request('marketplace/add', {
      'source': normalizedSource,
      'refName': normalizedRefName == null || normalizedRefName.isEmpty
          ? null
          : normalizedRefName,
      'sparsePaths': normalizedSparsePaths.isEmpty
          ? null
          : normalizedSparsePaths,
    });
  }

  Future<Map<String, Object?>> removeMarketplace({
    required String marketplaceName,
  }) {
    final normalizedName = marketplaceName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        marketplaceName,
        'marketplaceName',
        'marketplaceName must not be blank',
      );
    }
    return _request('marketplace/remove', {'marketplaceName': normalizedName});
  }

  Future<Map<String, Object?>> upgradeMarketplaces({String? marketplaceName}) {
    final normalizedName = marketplaceName?.trim();
    return _request('marketplace/upgrade', {
      'marketplaceName': normalizedName == null || normalizedName.isEmpty
          ? null
          : normalizedName,
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
      'input': [_textUserInput(text: text, textElements: textElements)],
      ...overrides.toTurnStartParams(),
    });
  }

  Future<Map<String, Object?>> steerTurn({
    required String threadId,
    required String turnId,
    required String text,
    List<TurnTextElement> textElements = const [],
  }) {
    return _request('turn/steer', {
      'threadId': threadId,
      'expectedTurnId': turnId,
      'input': [_textUserInput(text: text, textElements: textElements)],
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

Map<String, Object?> _textUserInput({
  required String text,
  required List<TurnTextElement> textElements,
}) {
  return {
    'type': 'text',
    'text': text,
    'text_elements': [for (final element in textElements) element.toJson()],
  };
}

String? _nonBlank(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

void _validateAudioFrame(RealtimeAudioFrame audio) {
  if (audio.data.trim().isEmpty) {
    throw ArgumentError.value(
      audio.data,
      'audio.data',
      'audio data must not be blank',
    );
  }
  if (audio.sampleRate <= 0) {
    throw ArgumentError.value(
      audio.sampleRate,
      'audio.sampleRate',
      'sample rate must be positive',
    );
  }
  if (audio.numChannels <= 0) {
    throw ArgumentError.value(
      audio.numChannels,
      'audio.numChannels',
      'channel count must be positive',
    );
  }
  if (audio.samplesPerChannel != null && audio.samplesPerChannel! <= 0) {
    throw ArgumentError.value(
      audio.samplesPerChannel,
      'audio.samplesPerChannel',
      'samples per channel must be positive',
    );
  }
}
