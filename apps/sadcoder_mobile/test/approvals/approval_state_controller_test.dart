import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_coordinator.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval_store.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('stores and replaces pending approvals', () {
    final controller = ApprovalStateController(
      initialApprovals: const [
        PendingApproval(
          requestId: 'approval-1',
          method: commandExecutionApprovalMethod,
          kind: PendingApprovalKind.commandExecution,
          rawParams: {},
        ),
      ],
    );
    addTearDown(controller.dispose);

    expect(controller.approvals.single.requestId, 'approval-1');

    controller.replaceAll(const [
      PendingApproval(
        requestId: 'approval-2',
        method: fileChangeApprovalMethod,
        kind: PendingApprovalKind.fileChange,
        rawParams: {},
      ),
    ]);

    expect(controller.approvals.single.requestId, 'approval-2');
  });

  test('notifies when coordinator receives and resolves requests', () async {
    final transport = MemoryJsonRpcTransport((_) async => {});
    final coordinator = ApprovalCoordinator(transport: transport);
    final controller = ApprovalStateController(coordinator: coordinator);
    addTearDown(controller.dispose);
    addTearDown(coordinator.close);
    addTearDown(transport.close);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await _emitServerRequest(
      transport,
      const JsonRpcServerRequest(
        id: 'approval-1',
        method: commandExecutionApprovalMethod,
        params: {'command': 'cargo test'},
      ),
    );

    expect(controller.approvals.single.requestId, 'approval-1');
    expect(notifications, 1);

    await _emitNotification(transport, {
      'method': serverRequestResolvedMethod,
      'params': {'requestId': 'approval-1'},
    });

    expect(controller.approvals, isEmpty);
    expect(notifications, 2);
  });

  test('sends approval decisions through attached coordinator', () async {
    final transport = MemoryJsonRpcTransport((_) async => {});
    final coordinator = ApprovalCoordinator(transport: transport);
    final controller = ApprovalStateController(coordinator: coordinator);
    addTearDown(controller.dispose);
    addTearDown(coordinator.close);
    addTearDown(transport.close);

    await controller.sendCommandOrFileDecision(
      const PendingApproval(
        requestId: 'approval-1',
        method: commandExecutionApprovalMethod,
        kind: PendingApprovalKind.commandExecution,
        rawParams: {},
      ),
      CodexApprovalDecision.accept,
    );

    expect(transport.responses.single.toJson(), {
      'jsonrpc': '2.0',
      'id': 'approval-1',
      'result': {'decision': 'accept'},
    });
  });
}

Future<void> _emitServerRequest(
  MemoryJsonRpcTransport transport,
  JsonRpcServerRequest request,
) async {
  transport.emitServerRequest(request);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _emitNotification(
  MemoryJsonRpcTransport transport,
  Map<String, Object?> notification,
) async {
  transport.emitNotification(notification);
  await Future<void>.delayed(Duration.zero);
}
