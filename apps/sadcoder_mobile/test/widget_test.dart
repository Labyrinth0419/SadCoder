import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/app/sadcoder_app.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  testWidgets('renders the SadCoder shell', (tester) async {
    await tester.pumpWidget(const SadCoderApp());

    expect(find.text('Hosts'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Approvals'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('SSH profile'), findsOneWidget);
  });

  testWidgets('renders Chinese localization', (tester) async {
    await tester.pumpWidget(const SadCoderApp(locale: Locale('zh')));

    expect(find.text('主机'), findsWidgets);
    expect(find.text('SSH 配置'), findsOneWidget);
    expect(find.text('对话'), findsWidgets);
    expect(find.text('审批'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('renders injected pending approvals in the shell', (
    tester,
  ) async {
    final approvalController = ApprovalStateController(
      initialApprovals: const [
        PendingApproval(
          requestId: 'approval-1',
          method: commandExecutionApprovalMethod,
          kind: PendingApprovalKind.commandExecution,
          rawParams: {},
          title: 'cargo test',
          command: 'cargo test',
        ),
      ],
    );
    addTearDown(approvalController.dispose);

    await tester.pumpWidget(
      SadCoderApp(approvalController: approvalController),
    );
    await tester.tap(find.text('Approvals').last);
    await tester.pumpAndSettle();

    expect(find.text('cargo test'), findsWidgets);
    expect(find.text('Command approval'), findsOneWidget);
  });

  testWidgets('uses the injected session approval controller in the shell', (
    tester,
  ) async {
    final approvalController = ApprovalStateController(
      initialApprovals: const [
        PendingApproval(
          requestId: 'approval-1',
          method: commandExecutionApprovalMethod,
          kind: PendingApprovalKind.commandExecution,
          rawParams: {},
          title: 'cargo test',
          command: 'cargo test',
        ),
      ],
    );
    final sessionController = CodexSessionStateController(
      connector: _NeverConnectsSessionStarter(),
      approvalController: approvalController,
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await tester.pumpWidget(SadCoderApp(sessionController: sessionController));
    await tester.tap(find.text('Approvals').last);
    await tester.pumpAndSettle();

    expect(find.text('cargo test'), findsWidgets);
    expect(find.text('Command approval'), findsOneWidget);
  });
}

class _NeverConnectsSessionStarter implements CodexSessionConnectionStarter {
  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) {
    throw StateError('not used by this widget test');
  }
}
