import '../approvals/approval_coordinator.dart';
import '../approvals/approval_state_controller.dart';
import 'codex_app_server_client.dart';
import 'json_rpc.dart';

class CodexAppSession {
  CodexAppSession(JsonRpcTransport transport)
    : this._(
        transport,
        CodexAppServerClient(transport),
        ApprovalCoordinator(transport: transport),
      );

  CodexAppSession._(this._transport, this.client, this.approvalCoordinator)
    : approvalController = ApprovalStateController(
        coordinator: approvalCoordinator,
      );

  final JsonRpcTransport _transport;
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

  Future<void> close() async {
    approvalController.dispose();
    await approvalCoordinator.close();
    await _transport.close();
  }
}
