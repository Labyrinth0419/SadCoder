import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_session.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
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
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

class _FakeSessionStarter implements CodexSessionConnectionStarter {
  _FakeSessionStarter({this.failConnect = false});

  final bool failConnect;
  final connectedProfiles = <SshProfile>[];
  int closeCount = 0;

  @override
  Future<CodexSessionConnection> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    if (failConnect) {
      throw StateError('connect failed');
    }
    connectedProfiles.add(profile);
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
        close: () async {
          closeCount++;
        },
      ),
    );
  }
}
