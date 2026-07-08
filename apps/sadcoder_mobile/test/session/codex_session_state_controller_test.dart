import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_session.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/reconnect_policy.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_proxy_connector.dart';

void main() {
  test('connect opens a session and records state transitions', () async {
    final approvalController = ApprovalStateController();
    final connector = _FakeSessionStarter();
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);
    final statuses = <CodexSessionStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.connect(_profile);

    expect(statuses, [
      CodexSessionStatus.connecting,
      CodexSessionStatus.connected,
    ]);
    expect(controller.isConnected, true);
    expect(controller.profile, _profile);
    expect(connector.connectedProfiles, [_profile]);
    expect(approvalController.canRespond, true);
  });

  test(
    'disconnect closes connection without clearing pending approvals',
    () async {
      final approvalController = ApprovalStateController(
        initialApprovals: const [
          PendingApproval(
            requestId: 'approval-1',
            method: commandExecutionApprovalMethod,
            kind: PendingApprovalKind.commandExecution,
            rawParams: {},
          ),
        ],
      );
      final connector = _FakeSessionStarter();
      final controller = CodexSessionStateController(
        connector: connector,
        approvalController: approvalController,
      );
      addTearDown(controller.dispose);
      addTearDown(approvalController.dispose);
      final statuses = <CodexSessionStatus>[];
      controller.addListener(() => statuses.add(controller.status));

      await controller.connect(_profile);
      await controller.disconnect();

      expect(statuses, [
        CodexSessionStatus.connecting,
        CodexSessionStatus.connected,
        CodexSessionStatus.disconnecting,
        CodexSessionStatus.idle,
      ]);
      expect(connector.closeCount, 1);
      expect(approvalController.approvals.single.requestId, 'approval-1');
      expect(approvalController.canRespond, false);
    },
  );

  test('failed connect records failure and keeps approvals', () async {
    final approvalController = ApprovalStateController(
      initialApprovals: const [
        PendingApproval(
          requestId: 'approval-1',
          method: commandExecutionApprovalMethod,
          kind: PendingApprovalKind.commandExecution,
          rawParams: {},
        ),
      ],
    );
    final connector = _FakeSessionStarter(failConnect: true);
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);
    final statuses = <CodexSessionStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await expectLater(controller.connect(_profile), throwsA(isA<StateError>()));

    expect(statuses, [
      CodexSessionStatus.connecting,
      CodexSessionStatus.failed,
    ]);
    expect(controller.error, isA<StateError>());
    expect(approvalController.approvals.single.requestId, 'approval-1');
    expect(approvalController.canRespond, false);
  });

  test(
    'connection loss reconnects with backoff without clearing approvals',
    () async {
      final approvalController = ApprovalStateController(
        initialApprovals: const [
          PendingApproval(
            requestId: 'approval-1',
            method: commandExecutionApprovalMethod,
            kind: PendingApprovalKind.commandExecution,
            rawParams: {},
          ),
        ],
      );
      final connector = _FakeSessionStarter();
      final scheduler = _FakeReconnectDelayScheduler();
      final controller = CodexSessionStateController(
        connector: connector,
        approvalController: approvalController,
        reconnectPolicy: const ReconnectPolicy.fixed(
          delays: [Duration(milliseconds: 1)],
        ),
        reconnectDelayScheduler: scheduler,
      );
      addTearDown(controller.dispose);
      addTearDown(approvalController.dispose);
      final statuses = <CodexSessionStatus>[];
      controller.addListener(() => statuses.add(controller.status));

      await controller.connect(_profile);
      connector.connections.single.completeDone();
      await _flushMicrotasks();

      expect(controller.status, CodexSessionStatus.reconnecting);
      expect(controller.reconnectAttempt, 1);
      expect(controller.nextReconnectDelay, const Duration(milliseconds: 1));
      expect(scheduler.delays, [const Duration(milliseconds: 1)]);
      expect(approvalController.approvals.single.requestId, 'approval-1');
      expect(approvalController.canRespond, false);

      scheduler.completeNext();
      await _flushMicrotasks();

      expect(controller.status, CodexSessionStatus.connected);
      expect(connector.connectedProfiles, [_profile, _profile]);
      expect(connector.closeCount, 1);
      expect(approvalController.approvals.single.requestId, 'approval-1');
      expect(approvalController.canRespond, true);
      expect(statuses, contains(CodexSessionStatus.reconnecting));
      expect(statuses, isNot(contains(CodexSessionStatus.disconnecting)));
    },
  );

  test('failed reconnect attempts keep retrying with capped backoff', () async {
    final approvalController = ApprovalStateController();
    final connector = _FakeSessionStarter(
      connectOutcomes: [null, StateError('reconnect failed'), null],
    );
    final scheduler = _FakeReconnectDelayScheduler();
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
      reconnectPolicy: const ReconnectPolicy.fixed(
        delays: [Duration(milliseconds: 1), Duration(milliseconds: 2)],
      ),
      reconnectDelayScheduler: scheduler,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    await controller.connect(_profile);
    connector.connections.single.completeDone();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.reconnecting);
    expect(scheduler.delays, [const Duration(milliseconds: 1)]);

    scheduler.completeNext();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.reconnecting);
    expect(controller.error, isA<StateError>());
    expect(controller.reconnectAttempt, 2);
    expect(scheduler.delays, [
      const Duration(milliseconds: 1),
      const Duration(milliseconds: 2),
    ]);

    scheduler.completeNext();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.connected);
    expect(connector.connectedProfiles, [_profile, _profile]);
    expect(connector.connectCount, 3);
  });

  test('manual disconnect cancels a queued reconnect', () async {
    final approvalController = ApprovalStateController(
      initialApprovals: const [
        PendingApproval(
          requestId: 'approval-1',
          method: commandExecutionApprovalMethod,
          kind: PendingApprovalKind.commandExecution,
          rawParams: {},
        ),
      ],
    );
    final connector = _FakeSessionStarter();
    final scheduler = _FakeReconnectDelayScheduler();
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
      reconnectPolicy: const ReconnectPolicy.fixed(
        delays: [Duration(milliseconds: 1)],
      ),
      reconnectDelayScheduler: scheduler,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    await controller.connect(_profile);
    connector.connections.single.completeDone();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.reconnecting);

    await controller.disconnect();
    scheduler.completeNext();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.idle);
    expect(connector.connectCount, 1);
    expect(connector.closeCount, 1);
    expect(approvalController.approvals.single.requestId, 'approval-1');
    expect(approvalController.canRespond, false);
  });
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

class _FakeSessionStarter implements CodexSessionConnectionStarter {
  _FakeSessionStarter({
    this.failConnect = false,
    List<Object?>? connectOutcomes,
  }) : connectOutcomes = connectOutcomes ?? const [];

  final bool failConnect;
  final List<Object?> connectOutcomes;
  final connectedProfiles = <SshProfile>[];
  final connections = <_FakeConnectionRecord>[];
  int connectCount = 0;
  int closeCount = 0;

  @override
  Future<CodexSessionConnection> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    final outcome = connectCount < connectOutcomes.length
        ? connectOutcomes[connectCount]
        : null;
    connectCount++;
    if (failConnect) {
      throw StateError('connect failed');
    }
    if (outcome != null) {
      throw outcome;
    }
    connectedProfiles.add(profile);
    final record = _FakeConnectionRecord();
    connections.add(record);
    final session = CodexAppSession(
      MemoryJsonRpcTransport((_) async => {}),
      approvalController: approvalController,
    );
    return CodexSessionConnection(
      profile: profile,
      session: session,
      proxyConnection: AgentProxyConnection(
        input: const Stream<Uint8List>.empty(),
        output: StreamController<Uint8List>().sink,
        done: record.done,
        close: () async {
          record.closed = true;
          closeCount++;
        },
      ),
    );
  }
}

class _FakeConnectionRecord {
  final _doneCompleter = Completer<void>();
  bool closed = false;

  Future<void> get done => _doneCompleter.future;

  void completeDone() {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }
}

class _FakeReconnectDelayScheduler implements ReconnectDelayScheduler {
  final delays = <Duration>[];
  final _waits = <Completer<void>>[];

  @override
  Future<void> wait(Duration delay) {
    delays.add(delay);
    final completer = Completer<void>();
    _waits.add(completer);
    return completer.future;
  }

  void completeNext() {
    if (_waits.isEmpty) {
      throw StateError('No reconnect wait is pending');
    }
    final completer = _waits.removeAt(0);
    if (!completer.isCompleted) {
      completer.complete();
    }
  }
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
