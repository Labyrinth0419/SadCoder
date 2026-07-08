import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('maps command execution approval requests', () {
    final approval = pendingApprovalFromServerRequest(
      const JsonRpcServerRequest(
        id: 'approval-1',
        method: commandExecutionApprovalMethod,
        params: {
          'threadId': 'thr_1',
          'turnId': 'turn_1',
          'itemId': 'item_1',
          'startedAtMs': 1234,
          'approvalId': 'callback_1',
          'environmentId': 'local',
          'reason': 'Run test suite',
          'command': 'cargo test --workspace',
          'cwd': '/repo',
          'availableDecisions': ['accept', 'decline'],
          'additionalPermissions': {
            'network': {'enabled': true},
          },
        },
      ),
    );

    expect(approval.kind, PendingApprovalKind.commandExecution);
    expect(approval.isKnown, isTrue);
    expect(approval.requestId, 'approval-1');
    expect(approval.threadId, 'thr_1');
    expect(approval.turnId, 'turn_1');
    expect(approval.itemId, 'item_1');
    expect(approval.startedAtMs, 1234);
    expect(approval.approvalId, 'callback_1');
    expect(approval.environmentId, 'local');
    expect(approval.reason, 'Run test suite');
    expect(approval.title, 'cargo test --workspace');
    expect(approval.command, 'cargo test --workspace');
    expect(approval.cwd, '/repo');
    expect(approval.availableDecisions, ['accept', 'decline']);
    expect(approval.additionalPermissions, {
      'network': {'enabled': true},
    });
    expect(approval.rawParams['command'], 'cargo test --workspace');
  });

  test('maps file change approval requests', () {
    final approval = pendingApprovalFromServerRequest(
      const JsonRpcServerRequest(
        id: 42,
        method: fileChangeApprovalMethod,
        params: {
          'threadId': 'thr_1',
          'turnId': 'turn_1',
          'itemId': 'item_2',
          'startedAtMs': 2000,
          'reason': 'Allow edits under workspace',
          'grantRoot': '/repo',
        },
      ),
    );

    expect(approval.kind, PendingApprovalKind.fileChange);
    expect(approval.requestId, 42);
    expect(approval.itemId, 'item_2');
    expect(approval.reason, 'Allow edits under workspace');
    expect(approval.grantRoot, '/repo');
    expect(approval.title, 'File change approval: /repo');
  });

  test('maps permission approval requests', () {
    final approval = pendingApprovalFromServerRequest(
      const JsonRpcServerRequest(
        id: 61,
        method: permissionsApprovalMethod,
        params: {
          'threadId': 'thr_123',
          'turnId': 'turn_123',
          'itemId': 'call_123',
          'environmentId': 'local',
          'cwd': '/repo',
          'reason': 'Select a workspace root',
          'permissions': {
            'fileSystem': {
              'write': ['/repo', '/tmp/shared'],
            },
          },
        },
      ),
    );

    expect(approval.kind, PendingApprovalKind.permissions);
    expect(approval.title, 'Select a workspace root');
    expect(approval.environmentId, 'local');
    expect(approval.cwd, '/repo');
    expect(approval.permissions, {
      'fileSystem': {
        'write': ['/repo', '/tmp/shared'],
      },
    });
  });

  test('maps flattened MCP elicitation requests', () {
    final approval = pendingApprovalFromServerRequest(
      const JsonRpcServerRequest(
        id: 'mcp-1',
        method: mcpElicitationMethod,
        params: {
          'threadId': 'thr_1',
          'turnId': 'turn_1',
          'serverName': 'github',
          'mode': 'form',
          'message': 'Choose repository',
          'requestedSchema': {
            'type': 'object',
            'properties': {
              'repo': {'type': 'string'},
            },
          },
        },
      ),
    );

    expect(approval.kind, PendingApprovalKind.mcpElicitation);
    expect(approval.serverName, 'github');
    expect(approval.mcpMode, 'form');
    expect(approval.mcpMessage, 'Choose repository');
    expect(approval.title, 'Choose repository');
    expect(
      approval.mcpRequest?['requestedSchema'],
      isA<Map<String, Object?>>(),
    );
  });

  test('maps nested MCP elicitation requests', () {
    final approval = pendingApprovalFromServerRequest(
      const JsonRpcServerRequest(
        id: 'mcp-url-1',
        method: mcpElicitationMethod,
        params: {
          'threadId': 'thr_1',
          'serverName': 'auth-server',
          'request': {
            'mode': 'url',
            'message': 'Authorize account',
            'url': 'https://example.test/auth',
            'elicitationId': 'elicit_1',
          },
        },
      ),
    );

    expect(approval.kind, PendingApprovalKind.mcpElicitation);
    expect(approval.serverName, 'auth-server');
    expect(approval.mcpMode, 'url');
    expect(approval.mcpMessage, 'Authorize account');
    expect(approval.mcpUrl, 'https://example.test/auth');
  });

  test('maps unknown server requests and preserves raw params', () {
    final approval = pendingApprovalFromServerRequest(
      const JsonRpcServerRequest(
        id: 'future-1',
        method: 'future/request',
        params: {
          'threadId': 'thr_future',
          'reason': 'New Codex capability',
          'payload': {'enabled': true},
        },
      ),
    );

    expect(approval.kind, PendingApprovalKind.unknown);
    expect(approval.isKnown, isFalse);
    expect(approval.title, 'future/request');
    expect(approval.threadId, 'thr_future');
    expect(approval.rawParams['payload'], {'enabled': true});
  });

  test('builds command and file approval decision responses', () {
    final response = commandOrFileApprovalDecisionResponse(
      'approval-1',
      CodexApprovalDecision.acceptForSession,
    );

    expect(response.toJson(), {
      'jsonrpc': '2.0',
      'id': 'approval-1',
      'result': {'decision': 'acceptForSession'},
    });
  });

  test('builds permission approval responses', () {
    final response = permissionsApprovalResponse(
      requestId: 61,
      scope: PermissionApprovalScope.session,
      permissions: {
        'fileSystem': {
          'write': ['/repo'],
        },
      },
    );

    expect(response.toJson(), {
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

  test('builds MCP elicitation responses', () {
    final response = mcpElicitationResponse(
      requestId: 'mcp-1',
      action: McpElicitationAction.accept,
      content: {'repo': 'openai/codex'},
    );

    expect(response.toJson(), {
      'jsonrpc': '2.0',
      'id': 'mcp-1',
      'result': {
        'action': 'accept',
        'content': {'repo': 'openai/codex'},
      },
    });
  });
}
