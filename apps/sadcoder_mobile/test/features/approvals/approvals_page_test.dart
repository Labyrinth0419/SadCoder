import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/features/approvals/approvals_page.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  testWidgets('shows empty approval state', (tester) async {
    await _pumpApprovalsPage(tester, const []);

    expect(find.text('No pending approvals'), findsOneWidget);
    expect(find.text('Approvals'), findsOneWidget);
  });

  testWidgets('shows active host for pending approvals', (tester) async {
    await _pumpApprovalsPage(
      tester,
      const [],
      activeProfile: const SshProfile(
        id: 'alice@srv.dev:22',
        name: 'Dev',
        host: 'srv.dev',
        username: 'alice',
      ),
    );

    expect(find.byKey(const ValueKey('approvals-active-host')), findsOneWidget);
    expect(find.text('Active connection: alice@srv.dev:22'), findsOneWidget);
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
    expect(find.text('Approve once'), findsOneWidget);
    expect(find.text('Approve session'), findsOneWidget);
    expect(find.text('Cancel'), findsWidgets);
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
    expect(find.text('批准一次'), findsOneWidget);
  });

  testWidgets('calls command decision callback from action buttons', (
    tester,
  ) async {
    final decisions = <({Object requestId, CodexApprovalDecision decision})>[];
    await _pumpApprovalsPage(
      tester,
      const [
        PendingApproval(
          requestId: 'cmd-1',
          method: 'item/commandExecution/requestApproval',
          kind: PendingApprovalKind.commandExecution,
          rawParams: {},
          title: 'cargo test',
        ),
      ],
      onCommandOrFileDecision: (approval, decision) {
        decisions.add((requestId: approval.requestId, decision: decision));
      },
    );

    await tester.tap(find.text('Approve session'));

    expect(decisions, [
      (requestId: 'cmd-1', decision: CodexApprovalDecision.acceptForSession),
    ]);
  });

  testWidgets('confirms high-risk command approvals before callback', (
    tester,
  ) async {
    final decisions = <({Object requestId, CodexApprovalDecision decision})>[];
    await _pumpApprovalsPage(
      tester,
      const [
        PendingApproval(
          requestId: 'cmd-1',
          method: 'item/commandExecution/requestApproval',
          kind: PendingApprovalKind.commandExecution,
          rawParams: {'command': 'rm -rf build'},
          title: 'rm -rf build',
          command: 'rm -rf build',
        ),
      ],
      onCommandOrFileDecision: (approval, decision) {
        decisions.add((requestId: approval.requestId, decision: decision));
      },
    );

    await tester.tap(find.text('Approve once'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm approval'), findsOneWidget);
    expect(decisions, isEmpty);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(decisions, isEmpty);

    await tester.tap(find.text('Approve once'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve anyway'));
    await tester.pumpAndSettle();

    expect(decisions, [
      (requestId: 'cmd-1', decision: CodexApprovalDecision.accept),
    ]);
  });

  testWidgets('does not confirm high-risk command denials', (tester) async {
    final decisions = <({Object requestId, CodexApprovalDecision decision})>[];
    await _pumpApprovalsPage(
      tester,
      const [
        PendingApproval(
          requestId: 'cmd-1',
          method: 'item/commandExecution/requestApproval',
          kind: PendingApprovalKind.commandExecution,
          rawParams: {'command': 'git reset --hard'},
          title: 'git reset --hard',
          command: 'git reset --hard',
        ),
      ],
      onCommandOrFileDecision: (approval, decision) {
        decisions.add((requestId: approval.requestId, decision: decision));
      },
    );

    await tester.tap(find.text('Deny'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm approval'), findsNothing);
    expect(decisions, [
      (requestId: 'cmd-1', decision: CodexApprovalDecision.decline),
    ]);
  });

  testWidgets('calls permission response callback with requested grant', (
    tester,
  ) async {
    final responses =
        <
          ({
            Object requestId,
            Map<String, Object?> permissions,
            PermissionApprovalScope scope,
          })
        >[];
    await _pumpApprovalsPage(
      tester,
      const [
        PendingApproval(
          requestId: 61,
          method: 'item/permissions/requestApproval',
          kind: PendingApprovalKind.permissions,
          rawParams: {},
          title: 'Permission approval',
          permissions: {
            'fileSystem': {
              'write': ['/repo'],
            },
          },
        ),
      ],
      onPermissionsResponse: (approval, permissions, scope) {
        responses.add((
          requestId: approval.requestId,
          permissions: permissions,
          scope: scope,
        ));
      },
    );

    await tester.tap(find.text('Allow turn'));

    expect(responses.single.requestId, 61);
    expect(responses.single.scope, PermissionApprovalScope.turn);
    expect(responses.single.permissions, {
      'fileSystem': {
        'write': ['/repo'],
      },
    });
  });

  testWidgets('calls MCP callback for decline and cancel actions', (
    tester,
  ) async {
    final actions = <({Object requestId, McpElicitationAction action})>[];
    await _pumpApprovalsPage(
      tester,
      const [
        PendingApproval(
          requestId: 'mcp-1',
          method: 'mcpServer/elicitation/request',
          kind: PendingApprovalKind.mcpElicitation,
          rawParams: {},
          title: 'Choose repository',
          mcpMessage: 'Choose repository',
        ),
      ],
      onMcpElicitationResponse: (approval, action) {
        actions.add((requestId: approval.requestId, action: action));
      },
    );

    await tester.tap(find.text('Deny'));
    await tester.tap(find.text('Cancel'));

    expect(actions, [
      (requestId: 'mcp-1', action: McpElicitationAction.decline),
      (requestId: 'mcp-1', action: McpElicitationAction.cancel),
    ]);
  });

  testWidgets(
    'collects option, other, and secret answers for tool user input',
    (tester) async {
      final responses =
          <({Object requestId, Map<String, List<String>> answers})>[];
      await _pumpApprovalsPage(
        tester,
        const [
          PendingApproval(
            requestId: 'input-1',
            method: 'item/tool/requestUserInput',
            kind: PendingApprovalKind.toolUserInput,
            rawParams: {},
            threadId: 'thr_1',
            turnId: 'turn_1',
            toolUserInputAutoResolutionMs: 60000,
            toolUserInputQuestions: [
              ToolUserInputQuestion(
                id: 'target',
                header: 'Target',
                question: 'Which target?',
                isOther: true,
                isSecret: false,
                options: [
                  ToolUserInputOption(
                    label: 'Core (Recommended)',
                    description: 'Inspect core.',
                  ),
                  ToolUserInputOption(
                    label: 'TUI',
                    description: 'Inspect the terminal UI.',
                  ),
                ],
              ),
              ToolUserInputQuestion(
                id: 'details',
                header: 'Details',
                question: 'Anything else?',
                isOther: true,
                isSecret: false,
                options: [
                  ToolUserInputOption(
                    label: 'No changes',
                    description: 'Keep the current scope.',
                  ),
                ],
              ),
              ToolUserInputQuestion(
                id: 'token',
                header: 'Token',
                question: 'Enter a temporary token.',
                isOther: false,
                isSecret: true,
                options: null,
              ),
            ],
          ),
        ],
        onToolUserInputResponse: (approval, answers) {
          responses.add((requestId: approval.requestId, answers: answers));
        },
      );

      expect(find.text('Question from Codex'), findsWidgets);
      expect(
        find.text('Codex may continue automatically after 60 seconds.'),
        findsOneWidget,
      );
      expect(find.text('Inspect the terminal UI.'), findsOneWidget);

      final targetOption = find.byKey(
        const ValueKey('tool-user-input-target-option-1'),
      );
      await tester.ensureVisible(targetOption);
      await tester.tap(targetOption);
      await tester.pump();

      final detailsOther = find.byKey(
        const ValueKey('tool-user-input-details-other'),
      );
      await tester.ensureVisible(detailsOther);
      await tester.tap(detailsOther);
      await tester.pump();
      final detailsField = find.byKey(
        const ValueKey('tool-user-input-details-text'),
      );
      await tester.ensureVisible(detailsField);
      await tester.enterText(detailsField, 'include snapshots');

      final tokenField = find.byKey(
        const ValueKey('tool-user-input-token-text'),
      );
      await tester.ensureVisible(tokenField);
      final tokenEditable = find.descendant(
        of: tokenField,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(tokenEditable).obscureText, isTrue);
      await tester.enterText(tokenField, 'temporary-secret');
      await tester.tap(find.byTooltip('Show secret'));
      await tester.pump();
      expect(tester.widget<EditableText>(tokenEditable).obscureText, isFalse);

      final submit = find.byKey(const ValueKey('tool-user-input-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(responses, hasLength(1));
      expect(responses.single.requestId, 'input-1');
      expect(responses.single.answers, {
        'target': ['TUI'],
        'details': ['user_note: include snapshots'],
        'token': ['user_note: temporary-secret'],
      });
    },
  );

  testWidgets('validates required tool user input answers', (tester) async {
    await _pumpApprovalsPage(tester, const [
      PendingApproval(
        requestId: 'input-1',
        method: 'item/tool/requestUserInput',
        kind: PendingApprovalKind.toolUserInput,
        rawParams: {},
        toolUserInputQuestions: [
          ToolUserInputQuestion(
            id: 'target',
            header: 'Target',
            question: 'Which target?',
            isOther: true,
            isSecret: false,
            options: [
              ToolUserInputOption(label: 'Core', description: 'Inspect core.'),
            ],
          ),
        ],
      ),
    ], onToolUserInputResponse: (_, _) {});

    await tester.tap(find.byKey(const ValueKey('tool-user-input-submit')));
    await tester.pump();

    expect(find.text('Select an option.'), findsOneWidget);
  });
}

Future<void> _pumpApprovalsPage(
  WidgetTester tester,
  List<PendingApproval> approvals, {
  Locale? locale,
  CommandOrFileApprovalCallback? onCommandOrFileDecision,
  PermissionsApprovalCallback? onPermissionsResponse,
  McpElicitationApprovalCallback? onMcpElicitationResponse,
  ToolUserInputApprovalCallback? onToolUserInputResponse,
  SshProfile? activeProfile,
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
      home: Scaffold(
        body: ApprovalsPage(
          approvals: approvals,
          activeProfile: activeProfile,
          onCommandOrFileDecision: onCommandOrFileDecision,
          onPermissionsResponse: onPermissionsResponse,
          onMcpElicitationResponse: onMcpElicitationResponse,
          onToolUserInputResponse: onToolUserInputResponse,
        ),
      ),
    ),
  );
}
