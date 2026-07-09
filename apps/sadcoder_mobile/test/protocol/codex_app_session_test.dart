import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_session.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('initializes app-server and exposes client methods', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) async {
      requests.add(request);
      return switch (request.method) {
        'initialize' => {'serverInfo': 'test'},
        'model/list' => {'models': <Object?>[]},
        _ => {},
      };
    });
    final session = CodexAppSession(transport);
    addTearDown(session.close);

    final initialize = await session.initialize();
    final models = await session.client.listModels();

    expect(initialize['serverInfo'], 'test');
    expect(models['models'], <Object?>[]);
    expect(requests.map((request) => request.method), [
      'initialize',
      'model/list',
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
