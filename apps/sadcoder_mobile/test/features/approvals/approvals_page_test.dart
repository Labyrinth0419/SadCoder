import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/features/approvals/approvals_page.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  testWidgets('shows empty approval state', (tester) async {
    await _pumpApprovalsPage(tester, const []);

    expect(find.text('No pending approvals'), findsOneWidget);
    expect(find.text('Approvals'), findsOneWidget);
  });

  testWidgets('renders command and MCP pending approvals', (tester) async {
    await _pumpApprovalsPage(tester, const [
      PendingApproval(
        requestId: 'cmd-1',
        method: 'item/commandExecution/requestApproval',
        kind: PendingApprovalKind.commandExecution,
        rawParams: {},
        title: 'cargo test --workspace',
        threadId: 'thr_1',
        turnId: 'turn_1',
        command: 'cargo test --workspace',
        cwd: '/repo',
        reason: 'Run tests',
      ),
      PendingApproval(
        requestId: 'mcp-1',
        method: 'mcpServer/elicitation/request',
        kind: PendingApprovalKind.mcpElicitation,
        rawParams: {},
        title: 'Choose repository',
        threadId: 'thr_2',
        serverName: 'github',
        mcpMessage: 'Choose repository',
      ),
    ]);

    expect(find.text('No pending approvals'), findsNothing);
    expect(find.text('cargo test --workspace'), findsWidgets);
    expect(find.text('Command approval'), findsOneWidget);
    expect(find.text('Request: cmd-1'), findsOneWidget);
    expect(find.text('Thread: thr_1'), findsOneWidget);
    expect(find.text('Turn: turn_1'), findsOneWidget);
    expect(find.text('Working directory: /repo'), findsOneWidget);
    expect(find.text('Reason: Run tests'), findsOneWidget);
    expect(find.text('Choose repository'), findsWidgets);
    expect(find.text('MCP elicitation'), findsOneWidget);
    expect(find.text('Server: github'), findsOneWidget);
  });

  testWidgets('renders Chinese approval labels', (tester) async {
    await _pumpApprovalsPage(tester, const [
      PendingApproval(
        requestId: 'file-1',
        method: 'item/fileChange/requestApproval',
        kind: PendingApprovalKind.fileChange,
        rawParams: {},
        title: 'File change approval: /repo',
        grantRoot: '/repo',
      ),
    ], locale: const Locale('zh'));

    expect(find.text('审批'), findsOneWidget);
    expect(find.text('文件变更审批'), findsOneWidget);
    expect(find.text('授权根目录: /repo'), findsOneWidget);
  });
}

Future<void> _pumpApprovalsPage(
  WidgetTester tester,
  List<PendingApproval> approvals, {
  Locale? locale,
}) {
  return tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ApprovalsPage(approvals: approvals)),
    ),
  );
}
