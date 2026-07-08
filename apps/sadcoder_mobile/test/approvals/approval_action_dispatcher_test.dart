import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_action_dispatcher.dart';
import 'package:sadcoder_mobile/src/approvals/approval_coordinator.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('dispatches command and file decisions through coordinator', () async {
    final transport = MemoryJsonRpcTransport((_) async => {});
    final coordinator = ApprovalCoordinator(transport: transport);
    final dispatcher = ApprovalActionDispatcher(coordinator);
    addTearDown(coordinator.close);
    addTearDown(transport.close);

    await dispatcher.sendCommandOrFileDecision(
      const PendingApproval(
        requestId: 'cmd-1',
        method: commandExecutionApprovalMethod,
        kind: PendingApprovalKind.commandExecution,
        rawParams: {},
      ),
      CodexApprovalDecision.accept,
    );

    expect(transport.responses.single.toJson(), {
      'jsonrpc': '2.0',
      'id': 'cmd-1',
      'result': {'decision': 'accept'},
    });
  });

  test('dispatches permission responses through coordinator', () async {
    final transport = MemoryJsonRpcTransport((_) async => {});
    final coordinator = ApprovalCoordinator(transport: transport);
    final dispatcher = ApprovalActionDispatcher(coordinator);
    addTearDown(coordinator.close);
    addTearDown(transport.close);

    await dispatcher.sendPermissionsResponse(
      const PendingApproval(
        requestId: 61,
        method: permissionsApprovalMethod,
        kind: PendingApprovalKind.permissions,
        rawParams: {},
      ),
      {
        'fileSystem': {
          'write': ['/repo'],
        },
      },
      PermissionApprovalScope.session,
    );

    expect(transport.responses.single.toJson(), {
      'jsonrpc': '2.0',
      'id': 61,
      'result': {
        'scope': 'session',
        'permissions': {
          'fileSystem': {
            'write': ['/repo'],
          },
        },
      },
    });
  });

  test('dispatches MCP decline and cancel through coordinator', () async {
    final transport = MemoryJsonRpcTransport((_) async => {});
    final coordinator = ApprovalCoordinator(transport: transport);
    final dispatcher = ApprovalActionDispatcher(coordinator);
    addTearDown(coordinator.close);
    addTearDown(transport.close);

    const approval = PendingApproval(
      requestId: 'mcp-1',
      method: mcpElicitationMethod,
      kind: PendingApprovalKind.mcpElicitation,
      rawParams: {},
    );

    await dispatcher.sendMcpElicitationResponse(
      approval,
      McpElicitationAction.decline,
    );
    await dispatcher.sendMcpElicitationResponse(
      approval,
      McpElicitationAction.cancel,
    );

    expect(transport.responses.first.toJson(), {
      'jsonrpc': '2.0',
      'id': 'mcp-1',
      'result': {'action': 'decline', 'content': null},
    });
    expect(transport.responses.last.toJson(), {
      'jsonrpc': '2.0',
      'id': 'mcp-1',
      'result': {'action': 'cancel', 'content': null},
    });
  });
}
