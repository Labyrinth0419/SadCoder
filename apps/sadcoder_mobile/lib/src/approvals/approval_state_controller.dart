import 'dart:async';

import 'package:flutter/foundation.dart';

import 'approval_action_dispatcher.dart';
import 'approval_coordinator.dart';
import 'pending_approval.dart';
import 'pending_approval_store.dart';

class ApprovalStateController extends ChangeNotifier {
  ApprovalStateController({
    Iterable<PendingApproval> initialApprovals = const [],
    ApprovalCoordinator? coordinator,
    PendingApprovalStore? store,
  }) : _store = store ?? coordinator?.store ?? PendingApprovalStore() {
    for (final approval in initialApprovals) {
      _store.upsert(approval);
    }
    if (coordinator != null) {
      attachCoordinator(coordinator, notify: false);
    }
  }

  final PendingApprovalStore _store;
  ApprovalActionDispatcher? _dispatcher;
  StreamSubscription<List<PendingApproval>>? _coordinatorSubscription;

  PendingApprovalStore get store => _store;

  List<PendingApproval> get approvals => _store.approvals;

  bool get canRespond => _dispatcher != null;

  void attachCoordinator(
    ApprovalCoordinator coordinator, {
    bool notify = true,
  }) {
    unawaited(detachCoordinator(notify: false));
    _dispatcher = ApprovalActionDispatcher(coordinator);
    _coordinatorSubscription = coordinator.changes.listen((_) {
      notifyListeners();
    });
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> detachCoordinator({bool notify = true}) {
    final subscription = _coordinatorSubscription;
    _coordinatorSubscription = null;
    _dispatcher = null;
    if (notify) {
      notifyListeners();
    }
    return subscription?.cancel() ?? Future<void>.value();
  }

  void replaceAll(Iterable<PendingApproval> approvals) {
    _store.clear();
    for (final approval in approvals) {
      _store.upsert(approval);
    }
    notifyListeners();
  }

  void upsert(PendingApproval approval) {
    _store.upsert(approval);
    notifyListeners();
  }

  void resolve(Object requestId) {
    if (_store.resolveRequest(requestId) != null) {
      notifyListeners();
    }
  }

  Future<void> sendCommandOrFileDecision(
    PendingApproval approval,
    CodexApprovalDecision decision,
  ) {
    final dispatcher = _requireDispatcher();
    return dispatcher.sendCommandOrFileDecision(approval, decision);
  }

  Future<void> sendPermissionsResponse(
    PendingApproval approval,
    Map<String, Object?> permissions,
    PermissionApprovalScope scope,
  ) {
    final dispatcher = _requireDispatcher();
    return dispatcher.sendPermissionsResponse(approval, permissions, scope);
  }

  Future<void> sendMcpElicitationResponse(
    PendingApproval approval,
    McpElicitationAction action,
  ) {
    final dispatcher = _requireDispatcher();
    return dispatcher.sendMcpElicitationResponse(approval, action);
  }

  ApprovalActionDispatcher _requireDispatcher() {
    final dispatcher = _dispatcher;
    if (dispatcher == null) {
      throw StateError('Approval responses require an attached coordinator');
    }
    return dispatcher;
  }

  @override
  void dispose() {
    unawaited(detachCoordinator(notify: false));
    super.dispose();
  }
}
