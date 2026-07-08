import '../approvals/approval_coordinator.dart';
import '../approvals/approval_state_controller.dart';
import 'codex_app_server_client.dart';
import 'json_rpc.dart';

class CodexAppSession {
  factory CodexAppSession(
    JsonRpcTransport transport, {
    ApprovalStateController? approvalController,
  }) {
    final controller = approvalController ?? ApprovalStateController();
    final coordinator = ApprovalCoordinator(
      transport: transport,
      store: controller.store,
    );
    controller.attachCoordinator(coordinator);
    return CodexAppSession._(
      transport,
      CodexAppServerClient(transport),
      coordinator,
      controller,
      ownsApprovalController: approvalController == null,
    );
  }

  CodexAppSession._(
    this._transport,
    this.client,
    this.approvalCoordinator,
    this.approvalController, {
    required bool ownsApprovalController,
  }) : _ownsApprovalController = ownsApprovalController;

  final JsonRpcTransport _transport;
  final bool _ownsApprovalController;
  final CodexAppServerClient client;
  final ApprovalCoordinator approvalCoordinator;
  final ApprovalStateController approvalController;

  Future<Map<String, Object?>> initialize({
    String clientName = 'sadcoder-mobile',
    bool experimentalApi = true,
  }) {
    return client.initialize(
      clientName: clientName,
      experimentalApi: experimentalApi,
    );
  }

  Future<void> close({bool notifyApprovalController = true}) async {
    approvalController.detachCoordinator(notify: notifyApprovalController);
    await approvalCoordinator.close();
    if (_ownsApprovalController) {
      approvalController.dispose();
    }
    await _transport.close();
  }
}
