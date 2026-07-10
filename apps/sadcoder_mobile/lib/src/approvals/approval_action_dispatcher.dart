import 'approval_coordinator.dart';
import 'pending_approval.dart';

class ApprovalActionDispatcher {
  const ApprovalActionDispatcher(this._coordinator);

  final ApprovalCoordinator _coordinator;

  Future<void> sendCommandOrFileDecision(
    PendingApproval approval,
    CodexApprovalDecision decision,
  ) {
    return _coordinator.sendCommandOrFileDecision(
      requestId: approval.requestId,
      decision: decision,
    );
  }

  Future<void> sendPermissionsResponse(
    PendingApproval approval,
    Map<String, Object?> permissions,
    PermissionApprovalScope scope,
  ) {
    return _coordinator.sendPermissionsResponse(
      requestId: approval.requestId,
      permissions: permissions,
      scope: scope,
    );
  }

  Future<void> sendMcpElicitationResponse(
    PendingApproval approval,
    McpElicitationAction action,
  ) {
    return _coordinator.sendMcpElicitationResponse(
      requestId: approval.requestId,
      action: action,
      content: null,
    );
  }

  Future<void> sendToolUserInputResponse(
    PendingApproval approval,
    Map<String, List<String>> answers,
  ) {
    return _coordinator.sendToolUserInputResponse(
      requestId: approval.requestId,
      answers: answers,
    );
  }
}
