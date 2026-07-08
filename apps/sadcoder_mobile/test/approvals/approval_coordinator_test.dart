import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_coordinator.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval_store.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('ingests server requests and publishes approval snapshots', () async {
    final transport = _FakeJsonRpcTransport();
    final coordinator = ApprovalCoordinator(transport: transport);
    addTearDown(coordinator.close);
    addTearDown(transport.close);

    final snapshots = <List<PendingApproval>>[];
    final subscription = coordinator.changes.listen(snapshots.add);
    addTearDown(subscription.cancel);

    transport.emitServerRequest(
      const JsonRpcServerRequest(
        id: 'approval-1',
        method: commandExecutionApprovalMethod,
        params: {'command': 'cargo test'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(snapshots, hasLength(1));
    expect(snapshots.single.single.requestId, 'approval-1');
    expect(snapshots.single.single.command, 'cargo test');
    expect(
      coordinator.approvals.single.kind,
      PendingApprovalKind.commandExecution,
    );
  });

  test(
    'removes pending approvals when app-server resolves server request',
    () async {
      final transport = _FakeJsonRpcTransport();
      final coordinator = ApprovalCoordinator(transport: transport);
      addTearDown(coordinator.close);
      addTearDown(transport.close);
      final snapshots = <List<PendingApproval>>[];
      final subscription = coordinator.changes.listen(snapshots.add);
      addTearDown(subscription.cancel);

      transport.emitServerRequest(
        const JsonRpcServerRequest(
          id: 9,
          method: fileChangeApprovalMethod,
          params: {'threadId': 'thr_1'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      transport.emitNotification({
        'method': serverRequestResolvedMethod,
        'params': {'threadId': 'thr_1', 'requestId': 9},
      });
      await Future<void>.delayed(Duration.zero);

      expect(snapshots, hasLength(2));
      expect(snapshots.first.single.requestId, 9);
      expect(snapshots.last, isEmpty);
      expect(coordinator.approvals, isEmpty);
    },
  );

  test(
    'sends command and file decisions without clearing pending state',
    () async {
      final transport = _FakeJsonRpcTransport();
      final store = PendingApprovalStore(
        initialApprovals: const [
          PendingApproval(
            requestId: 'approval-1',
            method: commandExecutionApprovalMethod,
            kind: PendingApprovalKind.commandExecution,
            rawParams: {},
          ),
        ],
      );
      final coordinator = ApprovalCoordinator(
        transport: transport,
        store: store,
      );
      addTearDown(coordinator.close);
      addTearDown(transport.close);

      await coordinator.sendCommandOrFileDecision(
        requestId: 'approval-1',
        decision: CodexApprovalDecision.decline,
      );

      expect(transport.responses.single.toJson(), {
        'jsonrpc': '2.0',
        'id': 'approval-1',
        'result': {'decision': 'decline'},
      });
      expect(coordinator.approvals.single.requestId, 'approval-1');
    },
  );

  test(
    'sends permission and MCP responses with their distinct wire shapes',
    () async {
      final transport = _FakeJsonRpcTransport();
      final coordinator = ApprovalCoordinator(transport: transport);
      addTearDown(coordinator.close);
      addTearDown(transport.close);

      await coordinator.sendPermissionsResponse(
        requestId: 61,
        scope: PermissionApprovalScope.session,
        permissions: {
          'fileSystem': {
            'write': ['/repo'],
          },
        },
      );
      await coordinator.sendMcpElicitationResponse(
        requestId: 'mcp-1',
        action: McpElicitationAction.accept,
        content: {'repo': 'openai/codex'},
      );

      expect(transport.responses.first.toJson(), {
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
      expect(transport.responses.last.toJson(), {
        'jsonrpc': '2.0',
        'id': 'mcp-1',
        'result': {
          'action': 'accept',
          'content': {'repo': 'openai/codex'},
        },
      });
    },
  );
}

class _FakeJsonRpcTransport implements JsonRpcTransport {
  final StreamController<Map<String, Object?>> _notifications =
      StreamController.broadcast();
  final StreamController<JsonRpcServerRequest> _serverRequests =
      StreamController.broadcast();
  final List<JsonRpcResponseMessage> responses = [];

  void emitNotification(Map<String, Object?> notification) {
    _notifications.add(notification);
  }

  void emitServerRequest(JsonRpcServerRequest request) {
    _serverRequests.add(request);
  }

  @override
  Stream<Map<String, Object?>> get notifications => _notifications.stream;

  @override
  Stream<JsonRpcServerRequest> get serverRequests => _serverRequests.stream;

  @override
  Future<Map<String, Object?>> request(JsonRpcRequest request) {
    throw UnimplementedError(
      'request is not used by approval coordinator tests',
    );
  }

  @override
  Future<void> notify(JsonRpcNotification notification) {
    throw UnimplementedError(
      'notify is not used by approval coordinator tests',
    );
  }

  @override
  Future<void> respond(JsonRpcResponseMessage response) async {
    responses.add(response);
  }

  @override
  Future<void> close() async {
    await _notifications.close();
    await _serverRequests.close();
  }
}
