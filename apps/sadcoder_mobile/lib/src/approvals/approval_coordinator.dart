import 'dart:async';

import '../protocol/json_rpc.dart';
import 'approval_request_mapper.dart';
import 'pending_approval.dart';
import 'pending_approval_store.dart';

class ApprovalCoordinator {
  ApprovalCoordinator({
    required JsonRpcTransport transport,
    PendingApprovalStore? store,
  }) : _transport = transport,
       store = store ?? PendingApprovalStore() {
    _serverRequests = _transport.serverRequests.listen(
      _handleServerRequest,
      onError: _changes.addError,
    );
    _notifications = _transport.notifications.listen(
      _handleNotification,
      onError: _changes.addError,
    );
  }

  final JsonRpcTransport _transport;
  final PendingApprovalStore store;
  final StreamController<List<PendingApproval>> _changes =
      StreamController.broadcast();
  late final StreamSubscription<JsonRpcServerRequest> _serverRequests;
  late final StreamSubscription<Map<String, Object?>> _notifications;

  List<PendingApproval> get approvals => store.approvals;

  Stream<List<PendingApproval>> get changes => _changes.stream;

  Future<void> sendCommandOrFileDecision({
    required Object requestId,
    required CodexApprovalDecision decision,
  }) {
    return _transport.respond(
      commandOrFileApprovalDecisionResponse(requestId, decision),
    );
  }

  Future<void> sendPermissionsResponse({
    required Object requestId,
    required Map<String, Object?> permissions,
    PermissionApprovalScope scope = PermissionApprovalScope.turn,
  }) {
    return _transport.respond(
      permissionsApprovalResponse(
        requestId: requestId,
        permissions: permissions,
        scope: scope,
      ),
    );
  }

  Future<void> sendMcpElicitationResponse({
    required Object requestId,
    required McpElicitationAction action,
    Object? content,
    Object? meta,
  }) {
    return _transport.respond(
      mcpElicitationResponse(
        requestId: requestId,
        action: action,
        content: content,
        meta: meta,
      ),
    );
  }

  Future<void> sendToolUserInputResponse({
    required Object requestId,
    required Map<String, List<String>> answers,
  }) {
    return _transport.respond(
      toolUserInputResponse(requestId: requestId, answers: answers),
    );
  }

  Future<void> close() async {
    await _serverRequests.cancel();
    await _notifications.cancel();
    await _changes.close();
  }

  void _handleServerRequest(JsonRpcServerRequest request) {
    store.ingestServerRequest(request);
    _emitChanges();
  }

  void _handleNotification(Map<String, Object?> notification) {
    final removed = store.applyNotification(notification);
    if (removed != null) {
      _emitChanges();
    }
  }

  void _emitChanges() {
    if (!_changes.isClosed) {
      _changes.add(approvals);
    }
  }
}
