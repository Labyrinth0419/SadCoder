import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_session.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/protocol/server_request_auto_responder.dart';

void main() {
  test('initializes app-server and exposes client methods', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) async {
      requests.add(request);
      return switch (request.method) {
        'initialize' => {'serverInfo': 'test'},
        'model/list' => {'models': <Object?>[]},
        'permissionProfile/list' => {'data': <Object?>[]},
        'account/read' => {'account': null, 'requiresOpenaiAuth': false},
        _ => {},
      };
    });
    final session = CodexAppSession(transport);
    addTearDown(session.close);

    final initialize = await session.initialize();
    final models = await session.client.listModels();
    final permissionProfiles = await session.client.listPermissionProfiles();
    final account = await session.client.readAccount();

    expect(initialize['serverInfo'], 'test');
    expect(models['models'], <Object?>[]);
    expect(permissionProfiles['data'], <Object?>[]);
    expect(account['requiresOpenaiAuth'], false);
    expect(requests.first.params?['clientInfo'], {
      'name': 'sadcoder-mobile',
      'version': '1.0.0',
    });
    expect(requests.map((request) => request.method), [
      'initialize',
      'model/list',
      'permissionProfile/list',
      'account/read',
    ]);
  });

  test('routes server requests into approval state', () async {
    final transport = MemoryJsonRpcTransport((_) async => {});
    final session = CodexAppSession(transport);
    addTearDown(session.close);
    var notifications = 0;
    session.approvalController.addListener(() => notifications++);

    transport.emitServerRequest(
      const JsonRpcServerRequest(
        id: 'approval-1',
        method: commandExecutionApprovalMethod,
        params: {'command': 'cargo test'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      session.approvalController.approvals.single.kind,
      PendingApprovalKind.commandExecution,
    );
    expect(session.approvalController.approvals.single.command, 'cargo test');
    expect(notifications, 1);
  });

  test('routes unknown server requests into generic approval state', () async {
    final transport = MemoryJsonRpcTransport((_) async => {});
    final session = CodexAppSession(transport);
    addTearDown(session.close);

    transport.emitServerRequest(
      const JsonRpcServerRequest(
        id: 'future-1',
        method: 'future/request',
        params: {
          'threadId': 'thr_future',
          'payload': {'enabled': true},
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final approval = session.approvalController.approvals.single;
    expect(approval.kind, PendingApprovalKind.unknown);
    expect(approval.method, 'future/request');
    expect(approval.threadId, 'thr_future');
    expect(approval.rawParams['payload'], {'enabled': true});
  });

  test(
    'responds to current-time server requests without approval state',
    () async {
      final transport = MemoryJsonRpcTransport((_) async => {});
      final session = CodexAppSession(transport);
      addTearDown(session.close);

      final before = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      transport.emitServerRequest(
        const JsonRpcServerRequest(
          id: 'time-1',
          method: currentTimeReadMethod,
          params: {'threadId': 'thr_1'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final after = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      expect(session.approvalController.approvals, isEmpty);
      expect(transport.responses, hasLength(1));
      expect(transport.responses.single.id, 'time-1');
      final result = transport.responses.single.result as Map<String, Object?>;
      expect(result['currentTimeAt'], isA<int>());
      expect(result['currentTimeAt'] as int, inInclusiveRange(before, after));
    },
  );

  test(
    'rejects known unsupported server requests without approval state',
    () async {
      final transport = MemoryJsonRpcTransport((_) async => {});
      final session = CodexAppSession(transport);
      addTearDown(session.close);

      transport.emitServerRequest(
        const JsonRpcServerRequest(
          id: 'auth-refresh-1',
          method: chatgptAuthTokensRefreshMethod,
          params: {'reason': 'unauthorized', 'previousAccountId': 'acct_1'},
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(session.approvalController.approvals, isEmpty);
      expect(transport.responses, hasLength(1));
      expect(transport.responses.single.toJson(), {
        'jsonrpc': '2.0',
        'id': 'auth-refresh-1',
        'error': {
          'code': unsupportedServerRequestErrorCode,
          'message': unsupportedServerRequestMessage(
            chatgptAuthTokensRefreshMethod,
          ),
          'data': {'method': chatgptAuthTokensRefreshMethod},
        },
      });
    },
  );

  test('maps app-server notifications into session events', () async {
    final transport = MemoryJsonRpcTransport((_) async => {});
    final session = CodexAppSession(transport);
    addTearDown(session.close);
    final event = session.events.first;

    transport.emitNotification({
      'method': 'turn/started',
      'params': {
        'threadId': 'thr_1',
        'turn': {
          'id': 'turn_1',
          'status': 'inProgress',
          'items': <Object?>[],
          'itemsView': 'notLoaded',
        },
      },
    });

    final mapped = await event;
    expect(mapped.kind, CodexEventKind.turnStarted);
    expect(mapped.threadId, 'thr_1');
    expect(mapped.turnId, 'turn_1');
  });

  test(
    'approval controller dispatches responses through session transport',
    () async {
      final transport = MemoryJsonRpcTransport((_) async => {});
      final session = CodexAppSession(transport);
      addTearDown(session.close);

      await session.approvalController.sendCommandOrFileDecision(
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
    },
  );
}
