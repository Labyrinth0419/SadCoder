enum PendingApprovalKind {
  commandExecution,
  fileChange,
  permissions,
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

  bool get isKnown => kind != PendingApprovalKind.unknown;
}
