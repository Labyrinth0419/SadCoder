import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_coordinator.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval_store.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/protocol/server_request_auto_responder.dart';

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

  test('snapshot ingestion ignores auto-handled server requests', () {
    final controller = ApprovalStateController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.ingestServerRequests(const [
      JsonRpcServerRequest(
        id: 'time-1',
        method: currentTimeReadMethod,
        params: {'threadId': 'thr_1'},
      ),
      JsonRpcServerRequest(
        id: 'tool-1',
        method: dynamicToolCallMethod,
        params: {'threadId': 'thr_1'},
      ),
    ]);
    expect(controller.approvals, isEmpty);
    expect(notifications, 0);

    controller.reconcileServerRequestSnapshot(
      const [
        JsonRpcServerRequest(
          id: 'time-1',
          method: currentTimeReadMethod,
          params: {'threadId': 'thr_1'},
        ),
        JsonRpcServerRequest(
          id: 'tool-1',
          method: dynamicToolCallMethod,
          params: {'threadId': 'thr_1'},
        ),
      ],
      pruneRequestIds: const {'time-1', 'tool-1'},
    );
    expect(controller.approvals, isEmpty);
    expect(notifications, 0);
  });

  test('sends tool user input answers through attached coordinator', () async {
    final transport = MemoryJsonRpcTransport((_) async => {});
    final coordinator = ApprovalCoordinator(transport: transport);
    final controller = ApprovalStateController(coordinator: coordinator);
    addTearDown(controller.dispose);
    addTearDown(coordinator.close);
    addTearDown(transport.close);

    await controller.sendToolUserInputResponse(
      const PendingApproval(
        requestId: 'input-1',
        method: toolRequestUserInputMethod,
        kind: PendingApprovalKind.toolUserInput,
        rawParams: {},
      ),
      const {
        'confirm_path': ['Yes (Recommended)'],
      },
    );

    expect(transport.responses.single.toJson(), {
      'jsonrpc': '2.0',
      'id': 'input-1',
      'result': {
        'answers': {
          'confirm_path': {
            'answers': ['Yes (Recommended)'],
          },
        },
      },
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
