enum PendingApprovalKind {
  commandExecution,
  fileChange,
  permissions,
  toolUserInput,
  mcpElicitation,
  unknown,
}

enum CodexApprovalDecision { accept, acceptForSession, decline, cancel }

extension CodexApprovalDecisionWireName on CodexApprovalDecision {
  String get wireName => switch (this) {
    CodexApprovalDecision.accept => 'accept',
    CodexApprovalDecision.acceptForSession => 'acceptForSession',
    CodexApprovalDecision.decline => 'decline',
    CodexApprovalDecision.cancel => 'cancel',
  };
}

enum McpElicitationAction { accept, decline, cancel }

extension McpElicitationActionWireName on McpElicitationAction {
  String get wireName => switch (this) {
    McpElicitationAction.accept => 'accept',
    McpElicitationAction.decline => 'decline',
    McpElicitationAction.cancel => 'cancel',
  };
}

enum PermissionApprovalScope { turn, session }

extension PermissionApprovalScopeWireName on PermissionApprovalScope {
  String get wireName => switch (this) {
    PermissionApprovalScope.turn => 'turn',
    PermissionApprovalScope.session => 'session',
  };
}

class ToolUserInputOption {
  const ToolUserInputOption({required this.label, required this.description});

  final String label;
  final String description;

  @override
  bool operator ==(Object other) {
    return other is ToolUserInputOption &&
        other.label == label &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(label, description);
}

class ToolUserInputQuestion {
  const ToolUserInputQuestion({
    required this.id,
    required this.header,
    required this.question,
    required this.isOther,
    required this.isSecret,
    required this.options,
  });

  final String id;
  final String header;
  final String question;
  final bool isOther;
  final bool isSecret;
  final List<ToolUserInputOption>? options;

  bool get hasOptions => options?.isNotEmpty ?? false;

  @override
  bool operator ==(Object other) {
    return other is ToolUserInputQuestion &&
        other.id == id &&
        other.header == header &&
        other.question == question &&
        other.isOther == isOther &&
        other.isSecret == isSecret &&
        _listEquals(other.options, options);
  }

  @override
  int get hashCode => Object.hash(
    id,
    header,
    question,
    isOther,
    isSecret,
    options == null ? null : Object.hashAll(options!),
  );
}

class PendingApproval {
  const PendingApproval({
    required this.requestId,
    required this.method,
    required this.kind,
    required this.rawParams,
    this.title,
    this.threadId,
    this.turnId,
    this.itemId,
    this.startedAtMs,
    this.approvalId,
    this.environmentId,
    this.reason,
    this.command,
    this.cwd,
    this.grantRoot,
    this.permissions,
    this.additionalPermissions,
    this.availableDecisions,
    this.serverName,
    this.mcpMode,
    this.mcpMessage,
    this.mcpUrl,
    this.mcpRequest,
    this.toolUserInputQuestions = const [],
    this.toolUserInputAutoResolutionMs,
  });

  final Object requestId;
  final String method;
  final PendingApprovalKind kind;
  final Map<String, Object?> rawParams;
  final String? title;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final int? startedAtMs;
  final String? approvalId;
  final String? environmentId;
  final String? reason;
  final String? command;
  final String? cwd;
  final String? grantRoot;
  final Object? permissions;
  final Object? additionalPermissions;
  final Object? availableDecisions;
  final String? serverName;
  final String? mcpMode;
  final String? mcpMessage;
  final String? mcpUrl;
  final Map<String, Object?>? mcpRequest;
  final List<ToolUserInputQuestion> toolUserInputQuestions;
  final int? toolUserInputAutoResolutionMs;

  bool get isKnown => kind != PendingApprovalKind.unknown;
}

bool _listEquals<T>(List<T>? left, List<T>? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left == null || right == null || left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
