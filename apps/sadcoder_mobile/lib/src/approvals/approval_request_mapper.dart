import '../protocol/json_rpc.dart';
import 'pending_approval.dart';

const commandExecutionApprovalMethod = 'item/commandExecution/requestApproval';
const fileChangeApprovalMethod = 'item/fileChange/requestApproval';
const permissionsApprovalMethod = 'item/permissions/requestApproval';
const toolRequestUserInputMethod = 'item/tool/requestUserInput';
const mcpElicitationMethod = 'mcpServer/elicitation/request';

PendingApproval pendingApprovalFromServerRequest(JsonRpcServerRequest request) {
  final params = _stringKeyedMap(request.params);
  return switch (request.method) {
    commandExecutionApprovalMethod => _commandExecutionApproval(
      request,
      params,
    ),
    fileChangeApprovalMethod => _fileChangeApproval(request, params),
    permissionsApprovalMethod => _permissionsApproval(request, params),
    toolRequestUserInputMethod => _toolUserInput(request, params),
    mcpElicitationMethod => _mcpElicitation(request, params),
    _ => _unknownApproval(request, params),
  };
}

JsonRpcResponseMessage commandOrFileApprovalDecisionResponse(
  Object requestId,
  CodexApprovalDecision decision,
) {
  return JsonRpcResponseMessage(
    id: requestId,
    result: {'decision': decision.wireName},
  );
}

JsonRpcResponseMessage permissionsApprovalResponse({
  required Object requestId,
  required Map<String, Object?> permissions,
  PermissionApprovalScope scope = PermissionApprovalScope.turn,
}) {
  return JsonRpcResponseMessage(
    id: requestId,
    result: {
      if (scope == PermissionApprovalScope.session) 'scope': scope.wireName,
      'permissions': permissions,
    },
  );
}

JsonRpcResponseMessage mcpElicitationResponse({
  required Object requestId,
  required McpElicitationAction action,
  Object? content,
  Object? meta,
}) {
  final result = <String, Object?>{
    'action': action.wireName,
    'content': content,
  };
  if (meta != null) {
    result['_meta'] = meta;
  }
  return JsonRpcResponseMessage(id: requestId, result: result);
}

JsonRpcResponseMessage toolUserInputResponse({
  required Object requestId,
  required Map<String, List<String>> answers,
}) {
  return JsonRpcResponseMessage(
    id: requestId,
    result: {
      'answers': answers.map(
        (questionId, values) => MapEntry(questionId, <String, Object?>{
          'answers': List<String>.of(values),
        }),
      ),
    },
  );
}

PendingApproval _commandExecutionApproval(
  JsonRpcServerRequest request,
  Map<String, Object?> params,
) {
  final command = _stringValue(params, 'command');
  final reason = _stringValue(params, 'reason');
  return PendingApproval(
    requestId: request.id,
    method: request.method,
    kind: PendingApprovalKind.commandExecution,
    rawParams: params,
    title: command ?? reason ?? 'Command approval',
    threadId: _stringValue(params, 'threadId'),
    turnId: _stringValue(params, 'turnId'),
    itemId: _stringValue(params, 'itemId'),
    startedAtMs: _intValue(params, 'startedAtMs'),
    approvalId: _stringValue(params, 'approvalId'),
    environmentId: _stringValue(params, 'environmentId'),
    reason: reason,
    command: command,
    cwd: _stringValue(params, 'cwd'),
    additionalPermissions: params['additionalPermissions'],
    availableDecisions: params['availableDecisions'],
  );
}

PendingApproval _fileChangeApproval(
  JsonRpcServerRequest request,
  Map<String, Object?> params,
) {
  final grantRoot = _stringValue(params, 'grantRoot');
  return PendingApproval(
    requestId: request.id,
    method: request.method,
    kind: PendingApprovalKind.fileChange,
    rawParams: params,
    title: grantRoot == null
        ? 'File change approval'
        : 'File change approval: $grantRoot',
    threadId: _stringValue(params, 'threadId'),
    turnId: _stringValue(params, 'turnId'),
    itemId: _stringValue(params, 'itemId'),
    startedAtMs: _intValue(params, 'startedAtMs'),
    reason: _stringValue(params, 'reason'),
    grantRoot: grantRoot,
  );
}

PendingApproval _permissionsApproval(
  JsonRpcServerRequest request,
  Map<String, Object?> params,
) {
  final reason = _stringValue(params, 'reason');
  return PendingApproval(
    requestId: request.id,
    method: request.method,
    kind: PendingApprovalKind.permissions,
    rawParams: params,
    title: reason ?? 'Permission approval',
    threadId: _stringValue(params, 'threadId'),
    turnId: _stringValue(params, 'turnId'),
    itemId: _stringValue(params, 'itemId'),
    startedAtMs: _intValue(params, 'startedAtMs'),
    environmentId: _stringValue(params, 'environmentId'),
    reason: reason,
    cwd: _stringValue(params, 'cwd'),
    permissions: params['permissions'],
  );
}

PendingApproval _toolUserInput(
  JsonRpcServerRequest request,
  Map<String, Object?> params,
) {
  final questions = _toolUserInputQuestions(params['questions']);
  final firstQuestion = questions.isEmpty ? null : questions.first;
  final title = switch (firstQuestion) {
    null => null,
    ToolUserInputQuestion(header: final header) when header.isNotEmpty =>
      header,
    ToolUserInputQuestion(question: final question) when question.isNotEmpty =>
      question,
    _ => null,
  };
  return PendingApproval(
    requestId: request.id,
    method: request.method,
    kind: PendingApprovalKind.toolUserInput,
    rawParams: params,
    title: title,
    threadId: _stringValue(params, 'threadId'),
    turnId: _stringValue(params, 'turnId'),
    itemId: _stringValue(params, 'itemId'),
    startedAtMs: _intValue(params, 'startedAtMs'),
    toolUserInputQuestions: questions,
    toolUserInputAutoResolutionMs: _intValue(params, 'autoResolutionMs'),
  );
}

PendingApproval _mcpElicitation(
  JsonRpcServerRequest request,
  Map<String, Object?> params,
) {
  final mcpRequest = _mcpRequestParams(params);
  final message = _stringValue(mcpRequest, 'message');
  final serverName = _stringValue(params, 'serverName');
  return PendingApproval(
    requestId: request.id,
    method: request.method,
    kind: PendingApprovalKind.mcpElicitation,
    rawParams: params,
    title: message ?? serverName ?? 'MCP elicitation',
    threadId: _stringValue(params, 'threadId'),
    turnId: _stringValue(params, 'turnId'),
    serverName: serverName,
    mcpMode: _stringValue(mcpRequest, 'mode'),
    mcpMessage: message,
    mcpUrl: _stringValue(mcpRequest, 'url'),
    mcpRequest: mcpRequest.isEmpty ? null : mcpRequest,
  );
}

PendingApproval _unknownApproval(
  JsonRpcServerRequest request,
  Map<String, Object?> params,
) {
  return PendingApproval(
    requestId: request.id,
    method: request.method,
    kind: PendingApprovalKind.unknown,
    rawParams: params,
    title: request.method,
    threadId: _stringValue(params, 'threadId'),
    turnId: _stringValue(params, 'turnId'),
    itemId: _stringValue(params, 'itemId'),
    startedAtMs: _intValue(params, 'startedAtMs'),
    reason: _stringValue(params, 'reason'),
  );
}

Map<String, Object?> _mcpRequestParams(Map<String, Object?> params) {
  final nested = params['request'];
  if (nested is Map) {
    return _stringKeyedMap(nested);
  }

  final mode = params['mode'];
  if (mode is! String) {
    return const {};
  }

  final requestFields = Map<String, Object?>.fromEntries(
    params.entries.where((entry) => !_mcpEnvelopeKeys.contains(entry.key)),
  );
  return Map.unmodifiable(requestFields);
}

const _mcpEnvelopeKeys = {'threadId', 'turnId', 'serverName'};

List<ToolUserInputQuestion> _toolUserInputQuestions(Object? value) {
  if (value is! List) {
    return const [];
  }

  return List.unmodifiable(
    value.whereType<Map>().map((question) {
      final params = _stringKeyedMap(question);
      return ToolUserInputQuestion(
        id: _stringValue(params, 'id') ?? '',
        header: _stringValue(params, 'header') ?? '',
        question: _stringValue(params, 'question') ?? '',
        isOther: _boolValue(params, 'isOther') ?? false,
        isSecret: _boolValue(params, 'isSecret') ?? false,
        options: _toolUserInputOptions(params['options']),
      );
    }),
  );
}

List<ToolUserInputOption>? _toolUserInputOptions(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! List) {
    return const [];
  }

  return List.unmodifiable(
    value.whereType<Map>().map((option) {
      final params = _stringKeyedMap(option);
      return ToolUserInputOption(
        label: _stringValue(params, 'label') ?? '',
        description: _stringValue(params, 'description') ?? '',
      );
    }),
  );
}

Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is Map<String, Object?>) {
    return Map.unmodifiable(value);
  }
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value as Object?)),
    );
  }
  return const {};
}

String? _stringValue(Map<String, Object?> params, String key) {
  final value = params[key];
  return value is String ? value : null;
}

int? _intValue(Map<String, Object?> params, String key) {
  final value = params[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

bool? _boolValue(Map<String, Object?> params, String key) {
  final value = params[key];
  return value is bool ? value : null;
}
