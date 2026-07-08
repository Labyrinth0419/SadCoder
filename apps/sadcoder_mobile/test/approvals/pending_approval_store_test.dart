import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval_store.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('ingests server requests as pending approvals in arrival order', () {
    final store = PendingApprovalStore();

    final command = store.ingestServerRequest(
      const JsonRpcServerRequest(
        id: 'command-1',
        method: commandExecutionApprovalMethod,
        params: {'command': 'cargo test', 'threadId': 'thr_1'},
      ),
    );
    final file = store.ingestServerRequest(
      const JsonRpcServerRequest(
        id: 'file-1',
        method: fileChangeApprovalMethod,
        params: {'itemId': 'item_2'},
      ),
    );

    expect(store.length, 2);
    expect(store.approvals, [command, file]);
    expect(
      store.byRequestId('command-1')?.kind,
      PendingApprovalKind.commandExecution,
    );
    expect(store.byRequestId('file-1')?.kind, PendingApprovalKind.fileChange);
  });

  test(
    'upserts duplicate request ids without changing unrelated approvals',
    () {
      final store = PendingApprovalStore();
      store.ingestServerRequest(
        const JsonRpcServerRequest(
          id: 'approval-1',
          method: commandExecutionApprovalMethod,
          params: {'command': 'first'},
        ),
      );
      store.ingestServerRequest(
        const JsonRpcServerRequest(
          id: 'approval-2',
          method: fileChangeApprovalMethod,
          params: {'reason': 'edit'},
        ),
      );

      final replacement = store.ingestServerRequest(
        const JsonRpcServerRequest(
          id: 'approval-1',
          method: commandExecutionApprovalMethod,
          params: {'command': 'second'},
        ),
      );

      expect(store.length, 2);
      expect(store.byRequestId('approval-1'), replacement);
      expect(store.byRequestId('approval-1')?.command, 'second');
      expect(
        store.byRequestId('approval-2')?.kind,
        PendingApprovalKind.fileChange,
      );
      expect(store.approvals.map((approval) => approval.requestId), [
        'approval-1',
        'approval-2',
      ]);
    },
  );

  test('removes approvals from serverRequest resolved notifications', () {
    final store = PendingApprovalStore();
    final approval = store.ingestServerRequest(
      const JsonRpcServerRequest(
        id: 7,
        method: commandExecutionApprovalMethod,
        params: {'threadId': 'thr_1'},
      ),
    );

    final removed = store.applyNotification({
      'jsonrpc': '2.0',
      'method': serverRequestResolvedMethod,
      'params': {'threadId': 'thr_1', 'requestId': 7},
    });

    expect(removed, approval);
    expect(store.isEmpty, isTrue);
  });

  test('ignores unrelated or malformed notifications', () {
    final store = PendingApprovalStore();
    store.ingestServerRequest(
      const JsonRpcServerRequest(
        id: 'approval-1',
        method: commandExecutionApprovalMethod,
      ),
    );

    expect(store.applyNotification({'method': 'turn/completed'}), isNull);
    expect(
      store.applyNotification({'method': serverRequestResolvedMethod}),
      isNull,
    );
    expect(store.length, 1);
  });

  test('preserves unknown request types until explicit resolution', () {
    final store = PendingApprovalStore();
    final approval = store.ingestServerRequest(
      const JsonRpcServerRequest(
        id: 'future-1',
        method: 'future/request',
        params: {'payload': true},
      ),
    );

    expect(approval.kind, PendingApprovalKind.unknown);
    expect(store.byRequestId('future-1'), approval);

    expect(store.resolveRequest('future-1'), approval);
    expect(store.isEmpty, isTrue);
  });
}
