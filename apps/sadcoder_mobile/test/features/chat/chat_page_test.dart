import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/account_logout_runner.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/apps/app_list_reader.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal_runner.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/diffs/git_diff_reader.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/feedback/feedback_upload_runner.dart';
import 'package:sadcoder_mobile/src/files/file_search_reader.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_page.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_timeline_controller.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal_runner.dart';
import 'package:sadcoder_mobile/src/hooks/hook_list_reader.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_controller.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_reader.dart';
import 'package:sadcoder_mobile/src/models/model_list_controller.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_controller.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_list_reader.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review_runner.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/skills/skill_list_reader.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_mutation_runner.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/turns/turn_controller.dart';
import 'package:sadcoder_mobile/src/turns/turn_runner.dart';
import 'package:sadcoder_mobile/src/turns/turn_text_element.dart';
import 'package:sadcoder_mobile/src/usage/account_usage_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/usage/account_usage_snapshot_reader.dart';

void main() {
  testWidgets('shows command preview for known slash command aliases', (
    tester,
  ) async {
    await _pumpChatPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/clean now',
    );
    await tester.pump();

    expect(find.text('/stop'), findsOneWidget);
    expect(find.text('stop all background terminals'), findsOneWidget);
  });

  testWidgets('unknown slash commands are not treated as prompts', (
    tester,
  ) async {
    await _pumpChatPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/does-not-exist now',
    );
    await tester.pump();

    expect(find.text('Unknown command: /does-not-exist'), findsOneWidget);
    expect(find.text('Not sent as a prompt'), findsOneWidget);
  });

  testWidgets('bare slash opens command entry state', (tester) async {
    await _pumpChatPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/',
    );
    await tester.pump();

    expect(find.text('Slash commands'), findsOneWidget);
    expect(find.text('Type a command name'), findsOneWidget);
  });

  testWidgets('slash command button opens a searchable command palette', (
    tester,
  ) async {
    await _pumpChatPage(tester);

    await tester.tap(find.byKey(const ValueKey('chat-slash-command-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('slash-command-search-field')),
      'stop',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('slash-command-stop')), findsOneWidget);
    expect(find.text('/stop'), findsOneWidget);
    expect(find.textContaining('aliases: /clean'), findsOneWidget);
  });

  testWidgets('selecting a slash command fills the composer only', (
    tester,
  ) async {
    await _pumpChatPage(tester);

    await tester.tap(find.byKey(const ValueKey('chat-slash-command-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('slash-command-search-field')),
      'rename',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('slash-command-rename')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-composer-field')))
          .controller
          ?.text,
      '/rename ',
    );
    expect(find.text('/rename'), findsOneWidget);
  });

  testWidgets('shows disconnected thread list state without a controller', (
    tester,
  ) async {
    await _pumpChatPage(tester);

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Connect to a host to load sessions.'), findsOneWidget);
  });

  testWidgets('renders loaded thread summaries', (tester) async {
    final controller = ThreadListController(
      readerProvider: () => _FakeThreadListReader(
        page: ThreadListPage(
          threads: [
            ThreadSummary.fromJson({
              'id': 'thr_1',
              'sessionId': 'sess_1',
              'preview': 'Fix login bug',
              'ephemeral': false,
              'status': 'running',
              'cwd': '/repo',
              'updatedAt': 1,
              'forkedFromId': 'thr_0',
            }),
          ],
        ),
      ),
    );
    addTearDown(controller.dispose);
    await controller.refresh();

    await _pumpChatPage(tester, threadListController: controller);

    expect(find.text('Fix login bug'), findsOneWidget);
    expect(find.text('/repo\nrunning / fork'), findsOneWidget);
  });

  testWidgets('loads thread detail when tapping a thread summary', (
    tester,
  ) async {
    final listController = ThreadListController(
      readerProvider: () => _FakeThreadListReader(
        page: ThreadListPage(
          threads: [
            ThreadSummary.fromJson({
              'id': 'thr_1',
              'sessionId': 'sess_1',
              'preview': 'Fix login bug',
              'ephemeral': false,
              'status': 'idle',
              'cwd': '/repo',
              'updatedAt': 1,
            }),
          ],
        ),
      ),
    );
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_1',
          'sessionId': 'sess_1',
          'preview': 'Fix login bug',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': [
            {
              'id': 'turn_1',
              'status': 'completed',
              'items': [
                {'type': 'message'},
              ],
              'itemsView': 'full',
            },
          ],
        }),
      ),
    );
    final detailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    addTearDown(listController.dispose);
    addTearDown(detailController.dispose);
    await listController.refresh();

    await _pumpChatPage(
      tester,
      threadListController: listController,
      threadDetailController: detailController,
    );
    await tester.ensureVisible(find.text('Fix login bug'));
    await tester.tap(find.text('Fix login bug'));
    await tester.pumpAndSettle();

    expect(detailReader.threadIds, ['thr_1']);
    expect(find.text('Thread detail'), findsOneWidget);
    expect(find.text('Thread: thr_1'), findsOneWidget);
    expect(find.text('Working directory: /repo'), findsOneWidget);
    expect(find.text('Turns: 1'), findsOneWidget);
    expect(find.text('Turn: turn_1'), findsOneWidget);
    expect(find.text('completed / 1 items / full'), findsOneWidget);
  });

  testWidgets('sends normal prompt text through the turn controller', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      ' Fix login bug ',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(turnRunner.startedThreads, 1);
    expect(turnRunner.startedTurns, [
      (threadId: 'thr_new', text: 'Fix login bug'),
    ]);
    expect(find.text('Turn submitted: turn_1'), findsOneWidget);
    expect(find.text(' Fix login bug '), findsNothing);
  });

  testWidgets('applies next-turn overrides once and clears them after send', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        appDefault: CodexConfigOverrides(model: 'gpt-5'),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
    );

    expect(find.textContaining('Model: gpt-5 / app default'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('chat-turn-overrides-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chat-turn-model-override')),
      'gpt-5-codex',
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-turn-effort-override')),
      'high',
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-turn-cwd-override')),
      '/repo',
    );
    await tester.tap(find.byKey(const ValueKey('chat-turn-overrides-apply')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Model: gpt-5-codex / turn override'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      'Use turn overrides',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(turnRunner.startedTurnOverrides.single.toTurnStartParams(), {
      'model': 'gpt-5-codex',
      'effort': 'high',
      'cwd': '/repo',
    });
    expect(overrideController.layers.turn.toTurnStartParams(), isEmpty);
    expect(find.textContaining('Model: gpt-5 / app default'), findsWidgets);
  });

  testWidgets('applies session overrides until explicitly cleared', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        appDefault: CodexConfigOverrides(model: 'gpt-5', effort: 'medium'),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
    );

    expect(find.textContaining('Model: gpt-5 / app default'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('chat-session-overrides-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chat-session-model-override')),
      'gpt-5-codex',
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-session-cwd-override')),
      '/repo',
    );
    await tester.tap(
      find.byKey(const ValueKey('chat-session-overrides-apply')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Model: gpt-5-codex / session override'),
      findsWidgets,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      'Use session overrides',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(turnRunner.startedTurnOverrides.single.toTurnStartParams(), {
      'model': 'gpt-5-codex',
      'effort': 'medium',
      'cwd': '/repo',
    });
    expect(overrideController.layers.session.toTurnStartParams(), {
      'model': 'gpt-5-codex',
      'cwd': '/repo',
    });

    await tester.tap(
      find.byKey(const ValueKey('chat-session-overrides-clear')),
    );
    await tester.pumpAndSettle();

    expect(overrideController.layers.session.toTurnStartParams(), isEmpty);
    expect(find.textContaining('Model: gpt-5 / app default'), findsWidgets);
  });

  testWidgets('does not send slash commands as prompt text', (tester) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/does-not-exist now',
    );
    await tester.pump();

    final sendButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.send),
    );
    expect(sendButton.onPressed, isNull);
    expect(turnRunner.startedTurns, isEmpty);
  });

  testWidgets('unsupported slash commands report explicit unsupported state', (
    tester,
  ) async {
    final harness = await _pumpConnectedChatPage(tester);

    await _submitComposerText(tester, '/approve');

    expect(harness.turnRunner.startedTurns, isEmpty);
    expect(
      find.text(
        '/approve is registered but not available: mobile app-server handler is not wired yet. '
        'Planned path: auto-review retry approval. '
        'Risk: medium.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('platform-only slash commands explain visibility state', (
    tester,
  ) async {
    final harness = await _pumpConnectedChatPage(tester);

    await _submitComposerText(tester, '/app');

    expect(harness.turnRunner.startedTurns, isEmpty);
    expect(
      find.text(
        '/app is registered but not available: desktop-only command. '
        'Planned path: Codex Desktop handoff unavailable on mobile.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('debug-only slash commands explain diagnostic state', (
    tester,
  ) async {
    final harness = await _pumpConnectedChatPage(tester);

    await _submitComposerText(tester, '/rollout');

    expect(harness.turnRunner.startedTurns, isEmpty);
    expect(
      find.text(
        '/rollout is registered but not available: debug-only command. '
        'Planned path: diagnostic rollout path display.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('high-risk fallback slash commands include risk state', (
    tester,
  ) async {
    final harness = await _pumpConnectedChatPage(tester);

    await _submitComposerText(tester, r'/sandbox-add-read-dir C:\repo');

    expect(harness.turnRunner.startedTurns, isEmpty);
    expect(
      find.text(
        '/sandbox-add-read-dir is registered but not available: Windows-only command. '
        'Planned path: windows sandbox read directory configuration. '
        'Risk: high.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('/permissions applies next-turn permission overrides', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final overrideController = CodexConfigOverrideController();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/permissions',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Permission override'), findsOneWidget);
    await _selectDropdownOption(
      tester,
      const ValueKey('chat-permissions-command-approval-policy'),
      'on-request',
    );
    await _selectDropdownOption(
      tester,
      const ValueKey('chat-permissions-command-sandbox-mode'),
      'readOnly',
    );
    await tester.tap(
      find.byKey(const ValueKey('chat-permissions-command-apply')),
    );
    await tester.pumpAndSettle();

    expect(overrideController.layers.turn.toTurnStartParams(), {
      'approvalPolicy': 'on-request',
      'sandboxPolicy': {'type': 'readOnly', 'networkAccess': false},
    });
    expect(overrideController.layers.session.toTurnStartParams(), isEmpty);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(find.text('Permission override updated.'), findsOneWidget);
  });

  testWidgets('/permissions can apply a session permission override', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(
          approvalPolicy: 'on-failure',
          sandboxPolicy: {'type': 'workspaceWrite', 'networkAccess': true},
        ),
        turn: CodexConfigOverrides(approvalPolicy: 'on-request'),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/permissions',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session'));
    await tester.pumpAndSettle();

    expect(find.text('on-failure'), findsOneWidget);
    expect(find.text('workspaceWrite'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(
              const ValueKey('chat-permissions-command-network-access'),
            ),
          )
          .value,
      true,
    );

    await _selectDropdownOption(
      tester,
      const ValueKey('chat-permissions-command-approval-policy'),
      'never',
    );
    await _selectDropdownOption(
      tester,
      const ValueKey('chat-permissions-command-sandbox-mode'),
      'dangerFullAccess',
    );

    expect(
      find.text(
        'High risk: these permissions can let Codex run with less review or broader filesystem access.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('chat-permissions-command-apply')),
    );
    await tester.pumpAndSettle();

    expect(overrideController.layers.session.toTurnStartParams(), {
      'approvalPolicy': 'never',
      'sandboxPolicy': {'type': 'dangerFullAccess', 'networkAccess': true},
    });
    expect(overrideController.layers.turn.toTurnStartParams(), {
      'approvalPolicy': 'on-request',
    });
    expect(turnRunner.startedTurns, isEmpty);
    expect(find.text('Permission override updated.'), findsOneWidget);
  });

  testWidgets('/permissions can select permission profiles from server list', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(cwd: '/repo'),
      ),
    );
    final permissionProfileReader = _RecordingPermissionProfileListReader(
      page: const PermissionProfileListPage(
        profiles: [
          PermissionProfileSummary(
            id: ':workspace',
            description: 'Workspace write',
          ),
          PermissionProfileSummary(
            id: ':danger-full-access',
            description: 'Full access',
            allowed: false,
          ),
        ],
      ),
    );
    final permissionProfileListController = PermissionProfileListController(
      readerProvider: () => permissionProfileReader,
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);
    addTearDown(permissionProfileListController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
      permissionProfileListController: permissionProfileListController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/permissions',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(permissionProfileReader.cwdValues, ['/repo']);
    expect(find.text('Permission profile'), findsOneWidget);
    await _selectDropdownOption(
      tester,
      const ValueKey('chat-permissions-command-approval-policy'),
      'on-request',
    );
    await _selectDropdownOption(
      tester,
      const ValueKey('chat-permissions-command-permission-profile'),
      ':workspace / Workspace write',
    );
    await tester.tap(
      find.byKey(const ValueKey('chat-permissions-command-apply')),
    );
    await tester.pumpAndSettle();

    expect(overrideController.layers.turn.toTurnStartParams(), {
      'approvalPolicy': 'on-request',
      'permissions': ':workspace',
    });
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(find.text('Permission override updated.'), findsOneWidget);
  });

  testWidgets('/model applies a next-turn model override', (tester) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final overrideController = CodexConfigOverrideController();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/model',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Model override'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('chat-model-command-model')),
      'gpt-5-codex',
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-model-command-effort')),
      'high',
    );
    await tester.tap(find.byKey(const ValueKey('chat-model-command-apply')));
    await tester.pumpAndSettle();

    expect(overrideController.layers.turn.toTurnStartParams(), {
      'model': 'gpt-5-codex',
      'effort': 'high',
    });
    expect(overrideController.layers.session.toTurnStartParams(), isEmpty);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(find.text('Model override updated.'), findsOneWidget);
  });

  testWidgets('/model can select models from model/list', (tester) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final overrideController = CodexConfigOverrideController();
    final modelReader = _RecordingModelListReader(
      page: const ModelListPage(
        models: [
          CodexModelSummary(
            id: 'gpt-5-codex',
            name: 'GPT-5 Codex',
            provider: 'openai',
          ),
        ],
      ),
    );
    final modelListController = ModelListController(
      readerProvider: () => modelReader,
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(modelListController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
      modelListController: modelListController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/model',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(modelReader.calls, 1);
    expect(
      find.byKey(const ValueKey('chat-model-command-model-list')),
      findsOneWidget,
    );

    await _selectDropdownOption(
      tester,
      const ValueKey('chat-model-command-model-list'),
      'GPT-5 Codex (openai)',
    );

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('chat-model-command-model')),
          )
          .controller
          ?.text,
      'gpt-5-codex',
    );

    await tester.tap(find.byKey(const ValueKey('chat-model-command-apply')));
    await tester.pumpAndSettle();

    expect(overrideController.layers.turn.toTurnStartParams(), {
      'model': 'gpt-5-codex',
    });
    expect(overrideController.layers.session.toTurnStartParams(), isEmpty);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
  });

  testWidgets('/model can apply a session model override', (tester) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(model: 'gpt-5-codex', effort: 'medium'),
        turn: CodexConfigOverrides(model: 'turn-model', effort: 'low'),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/model',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('chat-model-command-model')),
          )
          .controller
          ?.text,
      'gpt-5-codex',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('chat-model-command-effort')),
          )
          .controller
          ?.text,
      'medium',
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-model-command-model')),
      'gpt-5',
    );
    await tester.tap(find.byKey(const ValueKey('chat-model-command-apply')));
    await tester.pumpAndSettle();

    expect(overrideController.layers.session.toTurnStartParams(), {
      'model': 'gpt-5',
      'effort': 'medium',
    });
    expect(overrideController.layers.turn.toTurnStartParams(), {
      'model': 'turn-model',
      'effort': 'low',
    });
    expect(turnRunner.startedTurns, isEmpty);
    expect(find.text('Model override updated.'), findsOneWidget);
  });

  testWidgets('/personality applies a next-turn personality override', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final overrideController = CodexConfigOverrideController();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/personality',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Personality override'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('chat-personality-command-personality')),
      'concise',
    );
    await tester.tap(
      find.byKey(const ValueKey('chat-personality-command-apply')),
    );
    await tester.pumpAndSettle();

    expect(overrideController.layers.turn.toTurnStartParams(), {
      'personality': 'concise',
    });
    expect(overrideController.layers.session.toTurnStartParams(), isEmpty);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(find.text('Personality override updated.'), findsOneWidget);
  });

  testWidgets('/personality can apply a session personality override', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(personality: 'pragmatic'),
        turn: CodexConfigOverrides(personality: 'brief'),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/personality',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('chat-personality-command-personality')),
          )
          .controller
          ?.text,
      'pragmatic',
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-personality-command-personality')),
      'collaborative',
    );
    await tester.tap(
      find.byKey(const ValueKey('chat-personality-command-apply')),
    );
    await tester.pumpAndSettle();

    expect(overrideController.layers.session.toTurnStartParams(), {
      'personality': 'collaborative',
    });
    expect(overrideController.layers.turn.toTurnStartParams(), {
      'personality': 'brief',
    });
    expect(turnRunner.startedTurns, isEmpty);
    expect(find.text('Personality override updated.'), findsOneWidget);
  });

  testWidgets('/plan applies a next-turn collaboration mode override', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final configOverrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        appDefault: CodexConfigOverrides(model: 'gpt-5-codex'),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => configOverrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(configOverrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: configOverrideController,
    );

    await _submitComposerText(tester, '/plan');

    expect(turnRunner.startedTurns, isEmpty);
    expect(configOverrideController.layers.turn.toTurnStartParams(), {
      'collaborationMode': {
        'mode': 'plan',
        'settings': {
          'model': 'gpt-5-codex',
          'reasoning_effort': 'medium',
          'developer_instructions': null,
        },
      },
    });
    expect(find.text('Plan mode applied.'), findsOneWidget);

    await _submitComposerText(tester, 'outline the fix');

    expect(turnRunner.startedTurns, [
      (threadId: 'thr_new', text: 'outline the fix'),
    ]);
    expect(turnRunner.startedTurnOverrides.single.toTurnStartParams(), {
      'collaborationMode': {
        'mode': 'plan',
        'settings': {
          'model': 'gpt-5-codex',
          'reasoning_effort': 'medium',
          'developer_instructions': null,
        },
      },
    });
    expect(configOverrideController.layers.turn.toTurnStartParams(), isEmpty);
  });

  testWidgets('/plan with inline prompt submits that prompt in Plan mode', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final configOverrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        appDefault: CodexConfigOverrides(model: 'gpt-5-codex'),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => configOverrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(configOverrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: configOverrideController,
    );

    await _submitComposerText(tester, '/plan build a patch plan');

    expect(turnRunner.startedTurns, [
      (threadId: 'thr_new', text: 'build a patch plan'),
    ]);
    expect(turnRunner.startedTurnOverrides.single.toTurnStartParams(), {
      'collaborationMode': {
        'mode': 'plan',
        'settings': {
          'model': 'gpt-5-codex',
          'reasoning_effort': 'medium',
          'developer_instructions': null,
        },
      },
    });
    expect(configOverrideController.layers.turn.toTurnStartParams(), isEmpty);
    expect(find.text('Plan mode applied.'), findsOneWidget);
  });

  testWidgets('/quit disconnects without interrupting an active turn', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await turnController.submitText('Run long task');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/quit',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(sessionController.status, CodexSessionStatus.idle);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(
      find.text(
        'Disconnected from the mobile proxy. Server tasks were not interrupted.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('/copy copies the latest assistant message', (tester) async {
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);
    timelineController.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_1',
        'sessionId': 'sess_1',
        'preview': 'Thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': [
          {
            'id': 'turn_1',
            'status': 'completed',
            'itemsView': 'full',
            'items': [
              {
                'id': 'assistant_1',
                'type': 'agentMessage',
                'text': 'Copied response',
              },
            ],
          },
        ],
      }),
    );
    Object? clipboardText;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'];
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpChatPage(tester, timelineController: timelineController);
    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/copy',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(clipboardText, 'Copied response');
    expect(find.text('Copied last response.'), findsOneWidget);
  });

  testWidgets('/status shows local connection and override state', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(model: 'gpt-5-codex', cwd: '/repo'),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadListController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(threadListController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await threadListController.refresh();
    await turnController.submitText('Run long task');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadListController: threadListController,
      turnController: turnController,
      configOverrideController: overrideController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/status',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(turnRunner.startedTurns, [
      (threadId: 'thr_new', text: 'Run long task'),
    ]);
    expect(
      find.text(
        'Connection status: Connected\n'
        'Host: tester@localhost:22\n'
        'Thread: thr_new\n'
        'Sessions: 0\n'
        'Turn: Turn submitted: turn_1\n'
        'Model: gpt-5-codex / session override\n'
        'Reasoning effort: server default\n'
        'Collaboration mode: server default\n'
        'Approval policy: server default\n'
        'Permission profile: server default\n'
        'Sandbox mode: server default\n'
        'Working directory: /repo / session override\n'
        'Personality: server default',
      ),
      findsOneWidget,
    );
  });

  testWidgets('/status refreshes thread detail and server config snapshot', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_new',
          'sessionId': 'sess_1',
          'preview': 'Active thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': <Object?>[],
        }),
      ),
    );
    final configReader = _RecordingConfigSnapshotReader(
      snapshot: CodexConfigSnapshot.fromJson({
        'config': {
          'model': 'gpt-5-codex',
          'model_reasoning_effort': 'high',
          'approval_policy': {'type': 'on-request'},
          'default_permissions': ':workspace',
          'sandbox_mode': {'type': 'workspace-write'},
        },
      }),
    );
    final accountReader = _RecordingAccountSnapshotReader(
      snapshot: const AccountSnapshot(
        account: AccountSummary(
          type: 'chatgpt',
          email: 'user@example.com',
          planType: 'pro',
        ),
        requiresOpenaiAuth: true,
      ),
    );
    final usageReader = _RecordingAccountUsageSnapshotReader(
      snapshot: const AccountUsageSnapshot(
        summary: AccountTokenUsageSummary(
          lifetimeTokens: 1234,
          peakDailyTokens: 900,
        ),
        dailyUsageBuckets: [],
        rateLimits: AccountRateLimitsSnapshot(
          primary: AccountRateLimitWindow(
            usedPercent: 25,
            windowDurationMins: 15,
            resetsAt: 1730947200,
          ),
        ),
        rateLimitsByLimitId: {},
        rateLimitResetCredits: null,
      ),
    );
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(cwd: '/repo'),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final configSnapshotController = CodexConfigSnapshotController(
      readerProvider: () => configReader,
    );
    final accountSnapshotController = AccountSnapshotController(
      readerProvider: () => accountReader,
    );
    final accountUsageSnapshotController = AccountUsageSnapshotController(
      readerProvider: () => usageReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(turnController.dispose);
    addTearDown(accountUsageSnapshotController.dispose);
    addTearDown(accountSnapshotController.dispose);
    addTearDown(configSnapshotController.dispose);
    addTearDown(threadDetailController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await turnController.submitText('Run status refresh');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      configOverrideController: overrideController,
      configSnapshotController: configSnapshotController,
      accountSnapshotController: accountSnapshotController,
      accountUsageSnapshotController: accountUsageSnapshotController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/status',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(detailReader.threadIds, ['thr_new']);
    expect(detailReader.includeTurnsValues, [false]);
    expect(configReader.cwdValues, ['/repo']);
    expect(accountReader.refreshTokenValues, [false]);
    expect(usageReader.calls, 1);
    expect(
      find.textContaining(
        'Server config snapshot: Model=gpt-5-codex, Reasoning effort=high, Approval policy=on-request, Permission profile=:workspace, Sandbox mode=workspace-write',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Account: ChatGPT / user@example.com / pro / OpenAI auth required',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Usage: Lifetime tokens=1234 tokens'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Rate limits: Primary: 25% used'),
      findsOneWidget,
    );
  });

  testWidgets('/debug-config refreshes and shows config layers', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final configReader = _RecordingConfigSnapshotReader(
      snapshot: CodexConfigSnapshot.fromJson({
        'config': {
          'model': 'gpt-5-codex',
          'approval_policy': {'type': 'on-request'},
        },
        'origins': {
          'model': {
            'name': {'type': 'user', 'file': '/home/me/.codex/config.toml'},
            'version': 'v1',
          },
        },
        'layers': [
          {
            'version': 'v1',
            'config': {'model': 'gpt-5-codex'},
          },
        ],
      }),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final detailController = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_selected',
            'sessionId': 'sess_1',
            'preview': 'Selected thread',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'turns': <Object?>[],
          }),
        ),
      ),
    );
    final configSnapshotController = CodexConfigSnapshotController(
      readerProvider: () => configReader,
    );
    addTearDown(configSnapshotController.dispose);
    addTearDown(detailController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    await sessionController.connect(_profile);
    await detailController.readThread('thr_selected');

    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: detailController,
      configSnapshotController: configSnapshotController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/debug-config',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(configReader.cwdValues, ['/repo']);
    expect(find.textContaining('Debug config'), findsOneWidget);
    expect(find.textContaining('Effective values'), findsOneWidget);
    expect(find.textContaining('model: gpt-5-codex'), findsOneWidget);
    expect(find.textContaining('Origins'), findsOneWidget);
    expect(find.textContaining('Config layers: 1'), findsOneWidget);
    expect(find.textContaining('Layer 1: v1'), findsOneWidget);
  });

  testWidgets('/debug-config unsupported arguments do not refresh', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final configReader = _RecordingConfigSnapshotReader(
      snapshot: const CodexConfigSnapshot(config: {}, origins: {}, layers: []),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final configSnapshotController = CodexConfigSnapshotController(
      readerProvider: () => configReader,
    );
    addTearDown(configSnapshotController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    await sessionController.connect(_profile);

    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      configSnapshotController: configSnapshotController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/debug-config sideways',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(configReader.cwdValues, isEmpty);
    expect(
      find.text('/debug-config is unavailable right now.'),
      findsOneWidget,
    );
  });

  testWidgets('/diff renders selected workspace git diff', (tester) async {
    final approvalController = ApprovalStateController();
    final diffReader = _RecordingGitDiffReader(
      result: const GitDiffResult(
        isGitRepository: true,
        stat: ' lib/main.dart | 2 +-',
        diff: 'diff --git a/lib/main.dart b/lib/main.dart',
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      gitDiffReader: diffReader,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final detailController = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_selected',
            'sessionId': 'sess_1',
            'preview': 'Selected thread',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'turns': <Object?>[],
          }),
        ),
      ),
    );
    addTearDown(detailController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await detailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: detailController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/diff',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(diffReader.cwdValues, ['/repo']);
    expect(find.textContaining('Git diff'), findsOneWidget);
    expect(find.textContaining('lib/main.dart | 2 +-'), findsOneWidget);
    expect(find.textContaining('diff --git'), findsOneWidget);
  });

  testWidgets('/mention inserts a file mention and submits text elements', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final fileSearchReader = _RecordingFileSearchReader(
      page: const FileSearchResultPage(
        files: [
          FileSearchMatch(
            root: '/repo',
            path: 'lib/main.dart',
            matchType: 'fuzzy',
            fileName: 'main.dart',
            score: 100,
            indices: [4, 5, 6, 7],
          ),
        ],
      ),
    );
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(cwd: '/repo'),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
      fileSearchReader: fileSearchReader,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/mention',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chat-mention-search-field')),
      'main',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('chat-mention-file-lib/main.dart')),
    );
    await tester.pumpAndSettle();

    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-composer-field')),
    );
    expect(composer.controller?.text, '@lib/main.dart');
    expect(fileSearchReader.calls.last.query, 'main');
    expect(fileSearchReader.calls.last.roots, ['/repo']);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '@lib/main.dart explain',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(turnRunner.startedTurns, [
      (threadId: 'thr_new', text: '@lib/main.dart explain'),
    ]);
    expect(turnRunner.startedTurnTextElements.single.single.toJson(), {
      'byte_range': {'start': 0, 'end': 14},
    });
  });

  testWidgets('/ide attaches mobile context with an initial file query', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final fileSearchReader = _RecordingFileSearchReader(
      page: const FileSearchResultPage(
        files: [
          FileSearchMatch(
            root: '/repo',
            path: 'lib/main.dart',
            matchType: 'fuzzy',
            fileName: 'main.dart',
            score: 100,
            indices: [4, 5, 6, 7],
          ),
        ],
      ),
    );
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(cwd: '/repo'),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
      fileSearchReader: fileSearchReader,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      configOverrideController: overrideController,
    );

    await _submitComposerText(tester, '/ide main');

    expect(find.text('Mobile context'), findsOneWidget);
    final searchField = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-mention-search-field')),
    );
    expect(searchField.controller?.text, 'main');
    expect(fileSearchReader.calls.last.query, 'main');
    expect(fileSearchReader.calls.last.roots, ['/repo']);

    await tester.tap(
      find.byKey(const ValueKey('chat-mention-file-lib/main.dart')),
    );
    await tester.pumpAndSettle();

    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-composer-field')),
    );
    expect(composer.controller?.text, '@lib/main.dart');
    expect(find.text('Mobile context attached.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '@lib/main.dart explain',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(turnRunner.startedTurns, [
      (threadId: 'thr_new', text: '@lib/main.dart explain'),
    ]);
    expect(turnRunner.startedTurnTextElements.single.single.toJson(), {
      'byte_range': {'start': 0, 'end': 14},
    });
  });

  testWidgets('/usage refreshes account usage and rate-limit snapshots', (
    tester,
  ) async {
    final usageReader = _RecordingAccountUsageSnapshotReader(
      snapshot: const AccountUsageSnapshot(
        summary: AccountTokenUsageSummary(
          lifetimeTokens: 1234,
          peakDailyTokens: 900,
          currentStreakDays: 3,
          longestStreakDays: 4,
          longestRunningTurnSec: 120,
        ),
        dailyUsageBuckets: [
          AccountTokenUsageDailyBucket(startDate: '2026-07-08', tokens: 111),
          AccountTokenUsageDailyBucket(startDate: '2026-07-09', tokens: 222),
        ],
        rateLimits: AccountRateLimitsSnapshot(
          primary: AccountRateLimitWindow(
            usedPercent: 25,
            windowDurationMins: 15,
            resetsAt: 1730947200,
          ),
          planType: 'pro',
        ),
        rateLimitsByLimitId: {},
        rateLimitResetCredits: AccountRateLimitResetCreditsSummary(
          availableCount: 2,
          credits: null,
        ),
      ),
    );
    final accountUsageSnapshotController = AccountUsageSnapshotController(
      readerProvider: () => usageReader,
    );
    addTearDown(accountUsageSnapshotController.dispose);

    await _pumpChatPage(
      tester,
      accountUsageSnapshotController: accountUsageSnapshotController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/usage',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(usageReader.calls, 1);
    expect(
      find.textContaining('Token usage: Lifetime tokens=1234 tokens'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Recent daily usage: 2026-07-08 111 tokens'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Rate limits: Primary: 25% used'),
      findsOneWidget,
    );
    expect(find.textContaining('Reset credits: 2 available'), findsOneWidget);
  });

  testWidgets('/logout confirms and signs out account', (tester) async {
    final approvalController = ApprovalStateController();
    final logoutRunner = _RecordingAccountLogoutRunner();
    final accountReader = _RecordingAccountSnapshotReader(
      snapshot: const AccountSnapshot(account: null, requiresOpenaiAuth: false),
    );
    final usageReader = _RecordingAccountUsageSnapshotReader(
      snapshot: const AccountUsageSnapshot(
        summary: AccountTokenUsageSummary(),
        dailyUsageBuckets: [],
        rateLimits: null,
        rateLimitsByLimitId: {},
        rateLimitResetCredits: null,
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      accountLogoutRunner: logoutRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final accountSnapshotController = AccountSnapshotController(
      readerProvider: () => accountReader,
    );
    final accountUsageSnapshotController = AccountUsageSnapshotController(
      readerProvider: () => usageReader,
    );
    addTearDown(accountUsageSnapshotController.dispose);
    addTearDown(accountSnapshotController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      accountSnapshotController: accountSnapshotController,
      accountUsageSnapshotController: accountUsageSnapshotController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/logout',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of Codex?'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(logoutRunner.calls, 1);
    expect(accountReader.refreshTokenValues, [false]);
    expect(usageReader.calls, 1);
    expect(sessionController.status, CodexSessionStatus.connected);
    expect(find.text('Signed out of Codex account.'), findsOneWidget);
  });

  testWidgets('/feedback submits category note and log consent', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final feedbackRunner = _RecordingFeedbackUploadRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      feedbackUploadRunner: feedbackRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final detailController = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_selected',
            'sessionId': 'sess_1',
            'preview': 'Selected thread',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'turns': <Object?>[],
          }),
        ),
      ),
    );
    addTearDown(detailController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await detailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: detailController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/feedback',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Send feedback'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('chat-feedback-note')),
      'The command output was confusing.',
    );
    await tester.tap(find.text('Include server logs'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send feedback'));
    await tester.pumpAndSettle();

    expect(feedbackRunner.calls.single, (
      classification: 'bug',
      reason: 'The command output was confusing.',
      threadId: 'thr_selected',
      turnId: null,
      includeLogs: true,
    ));
    expect(find.text('Feedback submitted.'), findsOneWidget);
  });

  testWidgets('/theme applies mobile theme preference', (tester) async {
    final appearanceController = AppAppearanceController();
    addTearDown(appearanceController.dispose);

    await _pumpChatPage(tester, appearanceController: appearanceController);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/theme',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsWidgets);
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-theme-command-apply')));
    await tester.pumpAndSettle();

    expect(appearanceController.theme, AppThemePreference.dark);
    expect(find.text('Theme updated.'), findsOneWidget);
  });

  testWidgets('/title applies mobile title display settings', (tester) async {
    final appearanceController = AppAppearanceController();
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_selected',
          'sessionId': 'sess_1',
          'preview': 'Selected thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
        }),
      ),
    );
    final detailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    addTearDown(detailController.dispose);
    addTearDown(appearanceController.dispose);
    await detailController.readThread('thr_selected');

    await _pumpChatPage(
      tester,
      appearanceController: appearanceController,
      threadDetailController: detailController,
    );

    await _submitComposerText(tester, '/title');

    expect(find.text('Title display'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-title-command-thread')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-title-command-cwd')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-title-command-apply')));
    await tester.pumpAndSettle();

    expect(appearanceController.titleDisplay.showThreadTitle, isTrue);
    expect(appearanceController.titleDisplay.showWorkingDirectory, isTrue);
    expect(find.text('Chat / Selected thread / /repo'), findsOneWidget);
    expect(find.text('Title display updated.'), findsOneWidget);
  });

  testWidgets('/statusline applies mobile status line settings', (
    tester,
  ) async {
    final appearanceController = AppAppearanceController();
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(model: 'gpt-5-codex', effort: 'high'),
      ),
    );
    addTearDown(overrideController.dispose);
    addTearDown(appearanceController.dispose);

    await _pumpChatPage(
      tester,
      appearanceController: appearanceController,
      configOverrideController: overrideController,
    );

    await _submitComposerText(tester, '/statusline');

    expect(find.text('Status line display'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('chat-statusline-command-model')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('chat-statusline-command-effort')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('chat-statusline-command-apply')),
    );
    await tester.pumpAndSettle();

    expect(appearanceController.statusLineDisplay.showModel, isTrue);
    expect(appearanceController.statusLineDisplay.showEffort, isTrue);
    expect(find.byKey(const ValueKey('chat-status-line')), findsOneWidget);
    expect(find.text('Model: gpt-5-codex'), findsOneWidget);
    expect(find.text('Reasoning effort: high'), findsOneWidget);
    expect(find.text('Status line display updated.'), findsOneWidget);
  });

  testWidgets('/keymap applies mobile keyboard shortcut settings', (
    tester,
  ) async {
    final appearanceController = AppAppearanceController();
    addTearDown(appearanceController.dispose);

    await _pumpChatPage(tester, appearanceController: appearanceController);

    expect(
      appearanceController.composerSendShortcut,
      AppComposerSendShortcut.enter,
    );
    expect(find.textContaining('Send: Enter'), findsOneWidget);

    var composer = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-composer-field')),
    );
    expect(composer.textInputAction, TextInputAction.send);
    expect(composer.maxLines, 1);

    await _submitComposerText(tester, '/keymap');

    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    await tester.tap(find.text('Ctrl+Enter sends'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-keymap-command-apply')));
    await tester.pumpAndSettle();

    expect(
      appearanceController.composerSendShortcut,
      AppComposerSendShortcut.ctrlEnter,
    );
    expect(find.textContaining('Send: Ctrl+Enter'), findsOneWidget);
    expect(find.text('Keyboard shortcut settings updated.'), findsOneWidget);

    composer = tester.widget<TextField>(
      find.byKey(const ValueKey('chat-composer-field')),
    );
    expect(composer.textInputAction, TextInputAction.newline);
    expect(composer.maxLines, 4);
  });

  testWidgets('/keymap inline argument restores Enter send shortcut', (
    tester,
  ) async {
    final appearanceController = AppAppearanceController(
      composerSendShortcut: AppComposerSendShortcut.ctrlEnter,
    );
    addTearDown(appearanceController.dispose);

    await _pumpChatPage(tester, appearanceController: appearanceController);

    expect(find.textContaining('Send: Ctrl+Enter'), findsOneWidget);

    await _submitComposerText(tester, '/keymap enter');

    expect(
      appearanceController.composerSendShortcut,
      AppComposerSendShortcut.enter,
    );
    expect(find.textContaining('Send: Enter'), findsOneWidget);
    expect(find.text('Keyboard shortcut settings updated.'), findsOneWidget);
  });

  testWidgets('Enter action submits when keymap uses Enter to send', (
    tester,
  ) async {
    final appearanceController = AppAppearanceController();
    final harness = await _pumpConnectedChatPage(
      tester,
      appearanceController: appearanceController,
    );
    addTearDown(appearanceController.dispose);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      'Ship shortcut handling',
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(harness.turnRunner.startedTurns, [
      (threadId: 'thr_new', text: 'Ship shortcut handling'),
    ]);
  });

  testWidgets('/keymap unsupported arguments do not send a prompt', (
    tester,
  ) async {
    final appearanceController = AppAppearanceController();
    final harness = await _pumpConnectedChatPage(
      tester,
      appearanceController: appearanceController,
    );
    addTearDown(appearanceController.dispose);

    await _submitComposerText(tester, '/keymap space');

    expect(harness.turnRunner.startedTurns, isEmpty);
    expect(
      appearanceController.composerSendShortcut,
      AppComposerSendShortcut.enter,
    );
    expect(find.text('/keymap is unavailable right now.'), findsOneWidget);
  });

  testWidgets('/vim enables the mobile composer Vim mode', (tester) async {
    final appearanceController = AppAppearanceController();
    addTearDown(appearanceController.dispose);

    await _pumpChatPage(tester, appearanceController: appearanceController);

    expect(
      appearanceController.composerInputMode,
      AppComposerInputMode.standard,
    );
    expect(find.textContaining('Input mode: Standard'), findsOneWidget);

    await _submitComposerText(tester, '/vim');

    expect(appearanceController.composerInputMode, AppComposerInputMode.vim);
    expect(find.textContaining('Input mode: Vim'), findsOneWidget);
    expect(find.text('Composer Vim mode enabled.'), findsOneWidget);
  });

  testWidgets('/vim disables the mobile composer Vim mode', (tester) async {
    final appearanceController = AppAppearanceController(
      composerInputMode: AppComposerInputMode.vim,
    );
    addTearDown(appearanceController.dispose);

    await _pumpChatPage(tester, appearanceController: appearanceController);

    expect(appearanceController.composerInputMode, AppComposerInputMode.vim);
    expect(find.textContaining('Input mode: Vim'), findsOneWidget);

    await _submitComposerText(tester, '/vim');

    expect(
      appearanceController.composerInputMode,
      AppComposerInputMode.standard,
    );
    expect(find.textContaining('Input mode: Standard'), findsOneWidget);
    expect(find.text('Composer Vim mode disabled.'), findsOneWidget);
  });

  testWidgets('/pets opens mobile terminal pet display settings', (
    tester,
  ) async {
    final appearanceController = AppAppearanceController();
    addTearDown(appearanceController.dispose);

    await _pumpChatPage(tester, appearanceController: appearanceController);

    expect(
      appearanceController.terminalPetPreference,
      AppTerminalPetPreference.tuiOnly,
    );
    expect(find.textContaining('Pet: TUI-only'), findsOneWidget);

    await _submitComposerText(tester, '/pets');

    expect(find.text('Terminal pet'), findsOneWidget);
    await tester.tap(find.text('Hidden on mobile'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-pets-command-apply')));
    await tester.pumpAndSettle();

    expect(
      appearanceController.terminalPetPreference,
      AppTerminalPetPreference.hidden,
    );
    expect(find.textContaining('Pet: hidden'), findsOneWidget);
    expect(find.text('Terminal pet hidden on mobile.'), findsOneWidget);
  });

  testWidgets('/pet show restores the TUI-only terminal pet state', (
    tester,
  ) async {
    final appearanceController = AppAppearanceController(
      terminalPetPreference: AppTerminalPetPreference.hidden,
    );
    addTearDown(appearanceController.dispose);

    await _pumpChatPage(tester, appearanceController: appearanceController);

    expect(find.textContaining('Pet: hidden'), findsOneWidget);

    await _submitComposerText(tester, '/pet show');

    expect(
      appearanceController.terminalPetPreference,
      AppTerminalPetPreference.tuiOnly,
    );
    expect(find.textContaining('Pet: TUI-only'), findsOneWidget);
    expect(
      find.text('Terminal pet remains TUI-only on mobile.'),
      findsOneWidget,
    );
  });

  testWidgets('/pets unsupported arguments do not send a prompt', (
    tester,
  ) async {
    final appearanceController = AppAppearanceController();
    final harness = await _pumpConnectedChatPage(
      tester,
      appearanceController: appearanceController,
    );
    addTearDown(appearanceController.dispose);

    await _submitComposerText(tester, '/pets dragon');

    expect(harness.turnRunner.startedTurns, isEmpty);
    expect(
      appearanceController.terminalPetPreference,
      AppTerminalPetPreference.tuiOnly,
    );
    expect(find.text('/pets is unavailable right now.'), findsOneWidget);
  });

  testWidgets('/goal reads the selected thread goal', (tester) async {
    final approvalController = ApprovalStateController();
    final goalRunner = _RecordingThreadGoalRunner(
      goal: _goal(
        threadId: 'thr_selected',
        objective: 'Reduce latency',
        tokenBudget: 5000,
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      threadGoalRunner: goalRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final detailController = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_selected',
            'sessionId': 'sess_1',
            'preview': 'Selected thread',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'turns': <Object?>[],
          }),
        ),
      ),
    );
    addTearDown(detailController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await detailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: detailController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/goal',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(goalRunner.getGoalThreadIds, ['thr_selected']);
    expect(goalRunner.setGoalCalls, isEmpty);
    expect(find.textContaining('Objective: Reduce latency'), findsOneWidget);
    expect(find.textContaining('Token budget: 5000'), findsOneWidget);
  });

  testWidgets('/goal sets the selected thread objective', (tester) async {
    final approvalController = ApprovalStateController();
    final goalRunner = _RecordingThreadGoalRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      threadGoalRunner: goalRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await turnController.resumeThread('thr_active');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/goal Ship goal support',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(goalRunner.setGoalCalls, [
      (
        threadId: 'thr_active',
        objective: 'Ship goal support',
        status: null,
        tokenBudget: null,
      ),
    ]);
    expect(find.textContaining('Objective: Ship goal support'), findsOneWidget);
  });

  testWidgets('/goal budget sets budget and optional objective', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final goalRunner = _RecordingThreadGoalRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      threadGoalRunner: goalRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await turnController.resumeThread('thr_active');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/goal budget 7500 Finish benchmark',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(goalRunner.setGoalCalls.single, (
      threadId: 'thr_active',
      objective: 'Finish benchmark',
      status: null,
      tokenBudget: 7500,
    ));
    expect(find.textContaining('Objective: Finish benchmark'), findsOneWidget);
    expect(find.textContaining('Token budget: 7500'), findsOneWidget);
  });

  testWidgets('/goal status updates the selected thread goal status', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final goalRunner = _RecordingThreadGoalRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      threadGoalRunner: goalRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await turnController.resumeThread('thr_active');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/goal status complete',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(goalRunner.setGoalCalls.single, (
      threadId: 'thr_active',
      objective: null,
      status: 'complete',
      tokenBudget: null,
    ));
    expect(find.textContaining('Status: complete'), findsOneWidget);
  });

  testWidgets('/goal clear clears the selected thread goal', (tester) async {
    final approvalController = ApprovalStateController();
    final goalRunner = _RecordingThreadGoalRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      threadGoalRunner: goalRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await turnController.resumeThread('thr_active');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/goal clear',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(goalRunner.clearGoalThreadIds, ['thr_active']);
    expect(goalRunner.setGoalCalls, isEmpty);
    expect(find.text('Goal cleared.'), findsOneWidget);
  });

  testWidgets('/goal unsupported arguments do not call app-server', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final goalRunner = _RecordingThreadGoalRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      threadGoalRunner: goalRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await turnController.resumeThread('thr_active');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/goal status sideways',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(goalRunner.getGoalThreadIds, isEmpty);
    expect(goalRunner.setGoalCalls, isEmpty);
    expect(goalRunner.clearGoalThreadIds, isEmpty);
    expect(find.text('/goal is unavailable right now.'), findsOneWidget);
  });

  testWidgets('/review starts an inline current changes review', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final reviewRunner = _RecordingThreadReviewRunner();
    final turnRunner = _FakeTurnRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
      threadReviewRunner: reviewRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await turnController.resumeThread('thr_active');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/review',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(turnRunner.startedTurns, isEmpty);
    expect(reviewRunner.calls.single.threadId, 'thr_active');
    expect(
      reviewRunner.calls.single.target.kind,
      ThreadReviewTargetKind.uncommittedChanges,
    );
    expect(reviewRunner.calls.single.delivery, isNull);
    expect(turnController.activeThreadId, 'thr_active');
    expect(turnController.activeTurnId, 'turn_review_1');
    expect(find.textContaining('Review started.'), findsOneWidget);
    expect(find.textContaining('Target: current changes'), findsOneWidget);
  });

  testWidgets('/review detached commit tracks the returned review thread', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final reviewRunner = _RecordingThreadReviewRunner(
      reviewThreadId: 'thr_review',
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      threadReviewRunner: reviewRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await turnController.resumeThread('thr_active');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/review detached commit abc123 Polish colors',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    final call = reviewRunner.calls.single;
    expect(call.threadId, 'thr_active');
    expect(call.delivery, ThreadReviewDelivery.detached);
    expect(call.target.kind, ThreadReviewTargetKind.commit);
    expect(call.target.sha, 'abc123');
    expect(call.target.title, 'Polish colors');
    expect(turnController.activeThreadId, 'thr_review');
    expect(turnController.activeTurnId, 'turn_review_1');
    expect(find.textContaining('Delivery: detached'), findsOneWidget);
    expect(find.textContaining('Thread: thr_review'), findsOneWidget);
  });

  testWidgets('/review unsupported arguments do not call app-server', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final reviewRunner = _RecordingThreadReviewRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      threadReviewRunner: reviewRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await turnController.resumeThread('thr_active');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/review commit',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(reviewRunner.calls, isEmpty);
    expect(find.text('/review is unavailable right now.'), findsOneWidget);
  });

  testWidgets('/ps lists background terminals for the selected thread', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final backgroundRunner = _RecordingThreadBackgroundTerminalRunner(
      page: ThreadBackgroundTerminalPage.fromJson({
        'data': [
          {
            'itemId': 'item_1',
            'processId': 'proc_1',
            'command': 'python3 -m http.server',
            'cwd': '/repo',
            'osPid': 1234,
            'cpuPercent': 12.5,
            'rssKb': 2048,
          },
        ],
      }),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      threadBackgroundTerminalRunner: backgroundRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final detailController = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(
        detail: ThreadDetail(thread: _thread('thr_selected')),
      ),
    );
    addTearDown(detailController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await detailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: detailController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/ps',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(backgroundRunner.listCalls.single.threadId, 'thr_selected');
    expect(backgroundRunner.listCalls.single.limit, 25);
    expect(backgroundRunner.cleanCalls, isEmpty);
    expect(find.textContaining('Background terminals'), findsOneWidget);
    expect(
      find.textContaining('process proc_1: python3 -m http.server'),
      findsOneWidget,
    );
    expect(find.textContaining('cwd: /repo'), findsOneWidget);
    expect(find.textContaining('item: item_1'), findsOneWidget);
    expect(find.textContaining('OS pid: 1234'), findsOneWidget);
    expect(find.textContaining('CPU: 12.5%'), findsOneWidget);
    expect(find.textContaining('memory: 2048 KB'), findsOneWidget);
  });

  testWidgets('/stop cleans background terminals without interrupting a turn', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final backgroundRunner = _RecordingThreadBackgroundTerminalRunner();
    final turnRunner = _FakeTurnRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
      threadBackgroundTerminalRunner: backgroundRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await turnController.resumeThread('thr_active');
    final tracked = turnController.trackStartedTurn(
      threadId: 'thr_active',
      turn: _reviewTurn('turn_running'),
    );
    expect(tracked, true);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/stop',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(backgroundRunner.cleanCalls, ['thr_active']);
    expect(backgroundRunner.listCalls, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(
      find.textContaining('Stopping all background terminals.'),
      findsOneWidget,
    );
  });

  testWidgets('/mcp lists MCP servers with compact detail by default', (
    tester,
  ) async {
    final mcpReader = _RecordingMcpServerStatusReader(
      page: McpServerStatusPage.fromJson({
        'data': [
          {
            'name': 'filesystem',
            'authStatus': 'unsupported',
            'tools': {
              'read_file': {'name': 'read_file'},
            },
          },
        ],
      }),
    );
    final mcpController = McpServerStatusController(
      readerProvider: () => mcpReader,
    );
    final detailController = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_selected',
            'sessionId': 'sess_1',
            'preview': 'Selected thread',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'turns': <Object?>[],
          }),
        ),
      ),
    );
    addTearDown(detailController.dispose);
    addTearDown(mcpController.dispose);
    await detailController.readThread('thr_selected');

    await _pumpChatPage(
      tester,
      threadDetailController: detailController,
      mcpServerStatusController: mcpController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/mcp',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(mcpReader.threadIds, ['thr_selected']);
    expect(mcpReader.limits, [25]);
    expect(mcpReader.details, [McpServerStatusDetail.toolsAndAuthOnly]);
    expect(find.textContaining('MCP servers'), findsOneWidget);
    expect(
      find.textContaining('filesystem: auth: unsupported, tools: 1'),
      findsOneWidget,
    );
  });

  testWidgets('/mcp verbose requests full MCP detail', (tester) async {
    final mcpReader = _RecordingMcpServerStatusReader(
      page: McpServerStatusPage.fromJson({
        'data': [
          {
            'name': 'github',
            'authStatus': 'oAuth',
            'serverInfo': {
              'name': 'github-mcp',
              'version': '1.2.3',
              'title': 'GitHub MCP',
            },
            'tools': {
              'search_issues': {
                'name': 'search_issues',
                'title': 'Search issues',
              },
            },
            'resources': [
              {'name': 'readme', 'title': 'README', 'uri': 'repo://readme'},
            ],
            'resourceTemplates': [
              {
                'name': 'repo_file',
                'title': 'Repository file',
                'uriTemplate': 'repo://{path}',
              },
            ],
          },
        ],
      }),
    );
    final mcpController = McpServerStatusController(
      readerProvider: () => mcpReader,
    );
    addTearDown(mcpController.dispose);

    await _pumpChatPage(tester, mcpServerStatusController: mcpController);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/mcp verbose',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(mcpReader.details, [McpServerStatusDetail.full]);
    expect(find.textContaining('github: auth: oAuth'), findsOneWidget);
    expect(find.textContaining('server: GitHub MCP'), findsOneWidget);
    expect(find.textContaining('tools: Search issues'), findsOneWidget);
    expect(find.textContaining('resources: README'), findsOneWidget);
    expect(find.textContaining('templates: Repository file'), findsOneWidget);
  });

  testWidgets('/mcp unsupported arguments do not refresh or send a prompt', (
    tester,
  ) async {
    final mcpReader = _RecordingMcpServerStatusReader(
      page: const McpServerStatusPage(servers: []),
    );
    final mcpController = McpServerStatusController(
      readerProvider: () => mcpReader,
    );
    addTearDown(mcpController.dispose);

    await _pumpChatPage(tester, mcpServerStatusController: mcpController);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/mcp sideways',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(mcpReader.calls, 0);
    expect(find.text('/mcp is unavailable right now.'), findsOneWidget);
  });

  testWidgets('/skills lists skills for the selected thread cwd', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final skillReader = _RecordingSkillListReader(
      page: SkillListPage.fromJson({
        'data': [
          {
            'cwd': '/repo',
            'skills': [
              {
                'name': 'pr-review',
                'description': 'Review PRs',
                'interface': {
                  'displayName': 'PR Babysitter',
                  'shortDescription': 'Review changed files',
                },
                'path': '/repo/.codex/skills/pr-review/SKILL.md',
                'scope': 'repo',
                'enabled': true,
              },
            ],
            'errors': <Object?>[],
          },
        ],
      }),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      skillListReader: skillReader,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final detailController = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_selected',
            'sessionId': 'sess_1',
            'preview': 'Selected thread',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'turns': <Object?>[],
          }),
        ),
      ),
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(detailController.dispose);
    await sessionController.connect(_profile);
    await detailController.readThread('thr_selected');

    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: detailController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/skills',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(skillReader.cwds, [
      ['/repo'],
    ]);
    expect(skillReader.forceReloadValues, [false]);
    expect(find.textContaining('Skills'), findsOneWidget);
    expect(find.textContaining('PR Babysitter (pr-review)'), findsOneWidget);
    expect(
      find.textContaining('Description: Review changed files'),
      findsOneWidget,
    );
  });

  testWidgets('/skills reload forces a rescan and prefers cwd overrides', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(cwd: '/override'),
      ),
    );
    final skillReader = _RecordingSkillListReader(
      page: const SkillListPage(entries: []),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      skillListReader: skillReader,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(overrideController.dispose);
    await sessionController.connect(_profile);

    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      configOverrideController: overrideController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/skills reload',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(skillReader.cwds, [
      ['/override'],
    ]);
    expect(skillReader.forceReloadValues, [true]);
    expect(find.textContaining('No skills available.'), findsOneWidget);
  });

  testWidgets('/plugins lists plugins for the selected thread cwd', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final pluginReader = _RecordingPluginListReader(
      page: PluginListPage.fromJson({
        'marketplaces': [
          {
            'name': 'openai-curated',
            'interface': {'displayName': 'OpenAI curated'},
            'plugins': [
              {
                'id': 'linear',
                'name': 'linear',
                'version': '1.2.3',
                'source': {'type': 'remote'},
                'installed': true,
                'enabled': true,
                'installPolicy': 'AVAILABLE',
                'authPolicy': 'ON_USE',
                'interface': {
                  'displayName': 'Linear',
                  'shortDescription': 'Plan work',
                  'capabilities': ['mcp'],
                },
              },
            ],
          },
        ],
      }),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      pluginListReader: pluginReader,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final detailController = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_selected',
            'sessionId': 'sess_1',
            'preview': 'Selected thread',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'turns': <Object?>[],
          }),
        ),
      ),
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(detailController.dispose);
    await sessionController.connect(_profile);
    await detailController.readThread('thr_selected');

    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: detailController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/plugins',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(pluginReader.cwds, [
      ['/repo'],
    ]);
    expect(pluginReader.marketplaceKinds, [isEmpty]);
    expect(find.textContaining('Plugins'), findsOneWidget);
    expect(find.textContaining('Marketplace: OpenAI curated'), findsOneWidget);
    expect(find.textContaining('Linear (linear)'), findsOneWidget);
    expect(find.textContaining('Capabilities: mcp'), findsOneWidget);
  });

  testWidgets(
    '/plugins unsupported arguments do not refresh or send a prompt',
    (tester) async {
      final approvalController = ApprovalStateController();
      final pluginReader = _RecordingPluginListReader(
        page: const PluginListPage(marketplaces: []),
      );
      final starter = _FakeSessionStarter(
        threadListReader: const _FakeThreadListReader(
          page: ThreadListPage(threads: []),
        ),
        pluginListReader: pluginReader,
      );
      final sessionController = CodexSessionStateController(
        connector: starter,
        approvalController: approvalController,
      );
      addTearDown(sessionController.dispose);
      addTearDown(approvalController.dispose);
      await sessionController.connect(_profile);

      await _pumpChatPage(tester, sessionController: sessionController);

      await tester.enterText(
        find.byKey(const ValueKey('chat-composer-field')),
        '/plugins sideways',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect(pluginReader.cwds, isEmpty);
      expect(find.text('/plugins is unavailable right now.'), findsOneWidget);
    },
  );

  testWidgets('/hooks lists hooks for the selected thread cwd', (tester) async {
    final approvalController = ApprovalStateController();
    final hookReader = _RecordingHookListReader(
      page: HookListPage.fromJson({
        'data': [
          {
            'cwd': '/repo',
            'hooks': [
              {
                'key': 'pre-tool-use-shell',
                'eventName': 'preToolUse',
                'handlerType': 'command',
                'matcher': 'shell',
                'command': 'scripts/check.sh',
                'timeoutSec': 30,
                'statusMessage': 'Checking shell command',
                'sourcePath': '/repo/.codex/hooks.json',
                'source': 'project',
                'displayOrder': 1,
                'enabled': true,
                'isManaged': false,
                'currentHash': 'abc123',
                'trustStatus': 'trusted',
              },
            ],
            'warnings': ['deprecated hook shape'],
            'errors': [
              {'path': '/repo/.codex/bad-hooks.json', 'message': 'bad hook'},
            ],
          },
        ],
      }),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      hookListReader: hookReader,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final detailController = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_selected',
            'sessionId': 'sess_1',
            'preview': 'Selected thread',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'turns': <Object?>[],
          }),
        ),
      ),
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(detailController.dispose);
    await sessionController.connect(_profile);
    await detailController.readThread('thr_selected');

    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: detailController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/hooks',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(hookReader.cwds, [
      ['/repo'],
    ]);
    expect(find.textContaining('Hooks'), findsOneWidget);
    expect(find.textContaining('cwd: /repo'), findsOneWidget);
    expect(
      find.textContaining('preToolUse (pre-tool-use-shell)'),
      findsOneWidget,
    );
    expect(find.textContaining('command: scripts/check.sh'), findsOneWidget);
    expect(find.textContaining('deprecated hook shape'), findsOneWidget);
    expect(find.textContaining('/repo/.codex/bad-hooks.json'), findsOneWidget);
  });

  testWidgets('/hooks unsupported arguments do not refresh or send a prompt', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final hookReader = _RecordingHookListReader(
      page: const HookListPage(entries: []),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      hookListReader: hookReader,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    await sessionController.connect(_profile);

    await _pumpChatPage(tester, sessionController: sessionController);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/hooks sideways',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(hookReader.cwds, isEmpty);
    expect(find.text('/hooks is unavailable right now.'), findsOneWidget);
  });

  testWidgets('/apps lists apps for the selected thread', (tester) async {
    final approvalController = ApprovalStateController();
    final appReader = _RecordingAppListReader(
      page: AppListPage.fromJson({
        'data': [
          {
            'id': 'linear',
            'name': 'Linear',
            'description': 'Plan work',
            'distributionChannel': 'marketplace',
            'branding': {
              'category': 'Project management',
              'developer': 'Linear',
              'website': 'https://linear.app',
            },
            'appMetadata': {
              'review': {'status': 'approved'},
              'version': '1.2.3',
            },
            'isAccessible': true,
            'isEnabled': true,
            'pluginDisplayNames': ['Linear plugin'],
          },
        ],
      }),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      appListReader: appReader,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final detailController = ThreadDetailController(
      readerProvider: () => _FakeThreadDetailReader(
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_selected',
            'sessionId': 'sess_1',
            'preview': 'Selected thread',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'turns': <Object?>[],
          }),
        ),
      ),
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    addTearDown(detailController.dispose);
    await sessionController.connect(_profile);
    await detailController.readThread('thr_selected');

    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: detailController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/apps',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(appReader.threadIds, ['thr_selected']);
    expect(appReader.limits, [25]);
    expect(appReader.forceRefetchValues, [false]);
    expect(find.textContaining('Apps'), findsOneWidget);
    expect(
      find.textContaining('Linear (linear): accessible, enabled'),
      findsOneWidget,
    );
    expect(find.textContaining('Description: Plan work'), findsOneWidget);
    expect(find.textContaining('Plugins: Linear plugin'), findsOneWidget);
  });

  testWidgets('/apps unsupported arguments do not refresh or send a prompt', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final appReader = _RecordingAppListReader(
      page: const AppListPage(apps: []),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      appListReader: appReader,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);
    await sessionController.connect(_profile);

    await _pumpChatPage(tester, sessionController: sessionController);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/apps sideways',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(appReader.threadIds, isEmpty);
    expect(find.text('/apps is unavailable right now.'), findsOneWidget);
  });

  testWidgets('/raw toggles raw timeline item JSON locally', (tester) async {
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);
    timelineController.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_1',
        'sessionId': 'sess_1',
        'preview': 'Thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': [
          {
            'id': 'turn_1',
            'status': 'completed',
            'itemsView': 'full',
            'items': [
              {'id': 'assistant_1', 'type': 'agentMessage', 'text': 'Done'},
            ],
          },
        ],
      }),
    );

    await _pumpChatPage(tester, timelineController: timelineController);
    expect(
      find.byKey(const ValueKey('timeline-raw-assistant_1')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/raw on',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Raw transcript view enabled.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('timeline-raw-assistant_1')),
      findsOneWidget,
    );
    expect(find.textContaining('"id": "assistant_1"'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/raw off',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Raw transcript view disabled.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('timeline-raw-assistant_1')),
      findsNothing,
    );
  });

  testWidgets('/new starts a new thread without sending a turn', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadListController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    final timelineController = ChatTimelineController();
    timelineController.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_old',
        'sessionId': 'sess_1',
        'preview': 'Old thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': [
          {
            'id': 'turn_old',
            'status': 'completed',
            'itemsView': 'full',
            'items': <Object?>[],
          },
        ],
      }),
    );
    addTearDown(timelineController.dispose);
    addTearDown(threadListController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadListController: threadListController,
      turnController: turnController,
      timelineController: timelineController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/new',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(turnRunner.startedThreads, 1);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(turnController.activeThreadId, 'thr_new');
    expect(timelineController.selectedThreadId, 'thr_new');
    expect(timelineController.turns, isEmpty);
    expect(find.text('Started a new thread.'), findsOneWidget);
  });

  testWidgets('/resume resumes a thread without sending a turn', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_existing',
          'sessionId': 'sess_1',
          'preview': 'Existing thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': <Object?>[],
        }),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadListController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);
    addTearDown(threadDetailController.dispose);
    addTearDown(threadListController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      timelineController: timelineController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/resume thr_existing',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(turnRunner.resumedThreads, ['thr_existing']);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(turnController.activeThreadId, 'thr_existing');
    expect(timelineController.selectedThreadId, 'thr_existing');
    expect(detailReader.threadIds, ['thr_existing']);
    expect(find.text('Resumed thread.'), findsOneWidget);
  });

  testWidgets('/rename updates the selected thread name', (tester) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final mutationRunner = _FakeThreadMutationRunner();
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_selected',
          'sessionId': 'sess_1',
          'preview': 'Selected thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': <Object?>[],
        }),
      ),
    );
    final listReader = _CountingThreadListReader(
      page: const ThreadListPage(threads: []),
    );
    final starter = _FakeSessionStarter(
      threadListReader: listReader,
      turnRunner: turnRunner,
      threadMutationRunner: mutationRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadListController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(threadDetailController.dispose);
    addTearDown(threadListController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await threadDetailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
    );
    await tester.pumpAndSettle();
    final callsBeforeRename = listReader.calls;

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/rename Release prep',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(mutationRunner.renamedThreads, [
      (threadId: 'thr_selected', name: 'Release prep'),
    ]);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(listReader.calls, callsBeforeRename + 1);
    expect(detailReader.threadIds, ['thr_selected', 'thr_selected']);
    expect(find.text('Renamed thread.'), findsOneWidget);
  });

  testWidgets('/fork forks and selects the current thread', (tester) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final mutationRunner = _FakeThreadMutationRunner(
      forkedThread: ThreadSummary.fromJson({
        'id': 'thr_fork',
        'sessionId': 'sess_1',
        'preview': 'Forked thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 2,
        'forkedFromId': 'thr_selected',
        'turns': [
          {
            'id': 'turn_forked',
            'status': 'completed',
            'items': <Object?>[],
            'itemsView': 'full',
          },
        ],
      }),
    );
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_fork',
          'sessionId': 'sess_1',
          'preview': 'Forked thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 2,
          'forkedFromId': 'thr_selected',
          'turns': <Object?>[],
        }),
      ),
    );
    final listReader = _CountingThreadListReader(
      page: const ThreadListPage(threads: []),
    );
    final starter = _FakeSessionStarter(
      threadListReader: listReader,
      turnRunner: turnRunner,
      threadMutationRunner: mutationRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadListController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);
    addTearDown(threadDetailController.dispose);
    addTearDown(threadListController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await threadDetailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      timelineController: timelineController,
    );
    await tester.pumpAndSettle();
    final callsBeforeFork = listReader.calls;

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/fork',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(mutationRunner.forkedThreads, [
      (threadId: 'thr_selected', lastTurnId: null, ephemeral: false),
    ]);
    expect(turnRunner.resumedThreads, isEmpty);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(turnController.activeThreadId, 'thr_fork');
    expect(threadDetailController.selectedThreadId, 'thr_fork');
    expect(timelineController.selectedThreadId, 'thr_fork');
    expect(listReader.calls, callsBeforeFork + 1);
    expect(find.text('Forked thread.'), findsOneWidget);
  });

  testWidgets('/side starts a side conversation and returns to main thread', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final mutationRunner = _FakeThreadMutationRunner(
      sideThread: ThreadSummary.fromJson({
        'id': 'thr_side',
        'sessionId': 'sess_1',
        'preview': 'Side thread',
        'ephemeral': true,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 2,
        'forkedFromId': 'thr_selected',
        'turns': [
          {
            'id': 'turn_side_context',
            'status': 'completed',
            'items': <Object?>[],
            'itemsView': 'full',
          },
        ],
      }),
    );
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_selected',
          'sessionId': 'sess_1',
          'preview': 'Selected thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': <Object?>[],
        }),
      ),
    );
    final listReader = _CountingThreadListReader(
      page: const ThreadListPage(threads: []),
    );
    final starter = _FakeSessionStarter(
      threadListReader: listReader,
      turnRunner: turnRunner,
      threadMutationRunner: mutationRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadListController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);
    addTearDown(threadDetailController.dispose);
    addTearDown(threadListController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await threadDetailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      timelineController: timelineController,
    );
    await tester.pumpAndSettle();
    final callsBeforeSide = listReader.calls;

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/side',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(mutationRunner.sideStartedThreads, ['thr_selected']);
    expect(mutationRunner.forkedThreads, isEmpty);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(turnController.activeThreadId, 'thr_side');
    expect(timelineController.selectedThreadId, 'thr_side');
    expect(timelineController.turns.single.turnId, 'turn_side_context');
    expect(threadDetailController.selectedThreadId, 'thr_side');
    expect(detailReader.threadIds, ['thr_selected', 'thr_side']);
    expect(listReader.calls, callsBeforeSide + 1);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chat-side-conversation-panel')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Side conversation'), findsOneWidget);
    expect(find.textContaining('Side thread: thr_side'), findsOneWidget);
    expect(find.text('Started side conversation.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-side-return-main')));
    await tester.pumpAndSettle();

    expect(turnController.activeThreadId, 'thr_selected');
    expect(timelineController.selectedThreadId, 'thr_selected');
    expect(threadDetailController.selectedThreadId, 'thr_selected');
    expect(detailReader.threadIds, [
      'thr_selected',
      'thr_side',
      'thr_selected',
    ]);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(find.text('Side conversation'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Returned to main thread.'), findsOneWidget);
  });

  testWidgets('/btw starts side conversation and submits inline prompt', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final mutationRunner = _FakeThreadMutationRunner(
      sideThread: ThreadSummary.fromJson({
        'id': 'thr_side',
        'sessionId': 'sess_1',
        'preview': 'Side thread',
        'ephemeral': true,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 2,
        'forkedFromId': 'thr_selected',
        'turns': <Object?>[],
      }),
    );
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_selected',
          'sessionId': 'sess_1',
          'preview': 'Selected thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': <Object?>[],
        }),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
      threadMutationRunner: mutationRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);
    addTearDown(threadDetailController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await threadDetailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      timelineController: timelineController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/btw quick question',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(mutationRunner.sideStartedThreads, ['thr_selected']);
    expect(turnRunner.startedTurns, [
      (threadId: 'thr_side', text: 'quick question'),
    ]);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(turnController.activeThreadId, 'thr_side');
    expect(turnController.activeTurnId, 'turn_1');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chat-side-conversation-panel')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Command: /btw'), findsOneWidget);
  });

  testWidgets('side mode rejects unavailable slash commands', (tester) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final mutationRunner = _FakeThreadMutationRunner(
      sideThread: ThreadSummary.fromJson({
        'id': 'thr_side',
        'sessionId': 'sess_1',
        'preview': 'Side thread',
        'ephemeral': true,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 2,
        'forkedFromId': 'thr_selected',
        'turns': <Object?>[],
      }),
    );
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_selected',
          'sessionId': 'sess_1',
          'preview': 'Selected thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': <Object?>[],
        }),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
      threadMutationRunner: mutationRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);
    addTearDown(threadDetailController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await threadDetailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      timelineController: timelineController,
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/side',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/fork',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(mutationRunner.sideStartedThreads, ['thr_selected']);
    expect(mutationRunner.forkedThreads, isEmpty);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(turnController.activeThreadId, 'thr_side');
    expect(find.text('/fork is unavailable right now.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chat-slash-command-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('slash-command-search-field')),
      'fork',
    );
    await tester.pumpAndSettle();

    final forkTile = tester.widget<ListTile>(
      find.byKey(const ValueKey('slash-command-fork')),
    );
    expect(forkTile.enabled, false);
    expect(
      find.textContaining('Unavailable in a side conversation'),
      findsWidgets,
    );
  });

  testWidgets('side mode drops to main thread when the session disconnects', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final mutationRunner = _FakeThreadMutationRunner(
      sideThread: ThreadSummary.fromJson({
        'id': 'thr_side',
        'sessionId': 'sess_1',
        'preview': 'Side thread',
        'ephemeral': true,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 2,
        'forkedFromId': 'thr_selected',
        'turns': <Object?>[],
      }),
    );
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_selected',
          'sessionId': 'sess_1',
          'preview': 'Selected thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': <Object?>[],
        }),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
      threadMutationRunner: mutationRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);
    addTearDown(threadDetailController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await threadDetailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      timelineController: timelineController,
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/side',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(turnController.activeThreadId, 'thr_side');
    expect(threadDetailController.selectedThreadId, 'thr_side');

    await sessionController.disconnect();
    await tester.pumpAndSettle();

    expect(sessionController.status, CodexSessionStatus.idle);
    expect(turnController.activeThreadId, 'thr_selected');
    expect(timelineController.selectedThreadId, 'thr_selected');
    expect(threadDetailController.selectedThreadId, isNull);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(find.text('Side conversation'), findsNothing);
  });

  testWidgets('/agent shows topology and switches selected thread', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final mainThread = ThreadSummary.fromJson({
      'id': 'thr_main',
      'sessionId': 'sess_1',
      'preview': 'Main thread',
      'ephemeral': false,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'turns': <Object?>[],
    });
    final workerThread = ThreadSummary.fromJson({
      'id': 'thr_worker',
      'sessionId': 'sess_1',
      'preview': 'Build patch',
      'ephemeral': false,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 2,
      'agentNickname': 'Builder',
      'agentRole': 'coder',
      'turns': <Object?>[],
    });
    final activeThreadWithActivity = ThreadSummary.fromJson({
      'id': 'thr_main',
      'sessionId': 'sess_1',
      'preview': 'Main thread',
      'ephemeral': false,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'turns': [
        {
          'id': 'turn_1',
          'status': 'completed',
          'itemsView': 'full',
          'items': [
            {
              'id': 'item_spawn',
              'type': 'collabAgentToolCall',
              'tool': 'spawnAgent',
              'status': 'completed',
              'senderThreadId': 'thr_main',
              'receiverThreadIds': ['thr_worker'],
              'agentsStates': {
                'thr_worker': {'status': 'running', 'message': null},
              },
            },
            {
              'id': 'item_path',
              'type': 'subAgentActivity',
              'kind': 'started',
              'agentThreadId': 'thr_worker',
              'agentPath': 'agents/build',
            },
          ],
        },
      ],
    });
    final threads = [mainThread, workerThread];
    final listReader = _CountingThreadListReader(
      page: ThreadListPage(threads: threads),
    );
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(thread: activeThreadWithActivity),
    );
    final starter = _FakeSessionStarter(
      threadListReader: listReader,
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadListController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);
    addTearDown(threadDetailController.dispose);
    addTearDown(threadListController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await threadDetailController.readThread('thr_main');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      timelineController: timelineController,
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/agent',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Agent threads'), findsOneWidget);
    expect(find.textContaining('Builder / coder'), findsOneWidget);
    expect(find.textContaining('Status: running'), findsOneWidget);
    expect(find.textContaining('Agent path: agents/build'), findsOneWidget);
    expect(find.textContaining('Parent thread: thr_main'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-thread-thr_worker')));
    await tester.pumpAndSettle();

    expect(listReader.calls, greaterThanOrEqualTo(1));
    expect(turnController.activeThreadId, 'thr_worker');
    expect(timelineController.selectedThreadId, 'thr_worker');
    expect(threadDetailController.selectedThreadId, 'thr_worker');
    expect(detailReader.threadIds, ['thr_main', 'thr_worker']);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(find.text('Selected agent thread.'), findsOneWidget);
  });

  testWidgets('/subagents shows only subagent entries', (tester) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final threads = [
      ThreadSummary.fromJson({
        'id': 'thr_main',
        'sessionId': 'sess_1',
        'preview': 'Main thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': <Object?>[],
      }),
      ThreadSummary.fromJson({
        'id': 'thr_review',
        'sessionId': 'sess_1',
        'preview': 'Review patch',
        'ephemeral': false,
        'status': 'closed',
        'cwd': '/repo',
        'updatedAt': 2,
        'parentThreadId': 'thr_main',
        'ancestorThreadId': 'thr_main',
        'agentRole': 'reviewer',
        'turns': <Object?>[],
      }),
    ];
    final starter = _FakeSessionStarter(
      threadListReader: _FakeThreadListReader(
        page: ThreadListPage(threads: threads),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadListController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () =>
          _FakeThreadDetailReader(detail: ThreadDetail(thread: threads.first)),
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);
    addTearDown(threadDetailController.dispose);
    addTearDown(threadListController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await threadDetailController.readThread('thr_main');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      timelineController: timelineController,
    );
    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/subagents',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text('Subagents'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-thread-thr_main')), findsNothing);
    expect(
      find.byKey(const ValueKey('agent-thread-thr_review')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('agent-thread-thr_review')));
    await tester.pumpAndSettle();

    expect(turnController.activeThreadId, 'thr_review');
    expect(timelineController.selectedThreadId, 'thr_review');
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
  });

  testWidgets('/compact starts compaction for the current thread', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final mutationRunner = _FakeThreadMutationRunner();
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_selected',
          'sessionId': 'sess_1',
          'preview': 'Selected thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': <Object?>[],
        }),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
      threadMutationRunner: mutationRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(threadDetailController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await threadDetailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: threadDetailController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/compact',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(mutationRunner.compactedThreads, ['thr_selected']);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(find.text('Started thread compaction.'), findsOneWidget);
  });

  testWidgets('/archive confirms and archives the selected thread', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final mutationRunner = _FakeThreadMutationRunner();
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_selected',
          'sessionId': 'sess_1',
          'preview': 'Selected thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': [
            {
              'id': 'turn_1',
              'status': 'completed',
              'items': <Object?>[],
              'itemsView': 'full',
            },
          ],
        }),
      ),
    );
    final listReader = _CountingThreadListReader(
      page: const ThreadListPage(threads: []),
    );
    final starter = _FakeSessionStarter(
      threadListReader: listReader,
      turnRunner: turnRunner,
      threadMutationRunner: mutationRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadListController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);
    addTearDown(threadDetailController.dispose);
    addTearDown(threadListController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await threadDetailController.readThread('thr_selected');
    timelineController.showThread(detailReader.detail.thread);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      timelineController: timelineController,
    );
    await tester.pumpAndSettle();
    final callsBeforeArchive = listReader.calls;

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/archive',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Archive thread?'), findsOneWidget);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(mutationRunner.archivedThreads, ['thr_selected']);
    expect(mutationRunner.deletedThreads, isEmpty);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(threadDetailController.selectedThreadId, isNull);
    expect(timelineController.turns, isEmpty);
    expect(listReader.calls, callsBeforeArchive + 1);
    expect(find.text('Archived thread.'), findsOneWidget);
  });

  testWidgets('/delete confirms and deletes the selected thread', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final mutationRunner = _FakeThreadMutationRunner();
    final detailReader = _FakeThreadDetailReader(
      detail: ThreadDetail(
        thread: ThreadSummary.fromJson({
          'id': 'thr_selected',
          'sessionId': 'sess_1',
          'preview': 'Selected thread',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 1,
          'turns': <Object?>[],
        }),
      ),
    );
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
      threadMutationRunner: mutationRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadDetailController = ThreadDetailController(
      readerProvider: () => detailReader,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(threadDetailController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await threadDetailController.readThread('thr_selected');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadDetailController: threadDetailController,
      turnController: turnController,
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/delete',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Delete thread?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(mutationRunner.deletedThreads, ['thr_selected']);
    expect(mutationRunner.archivedThreads, isEmpty);
    expect(turnRunner.startedTurns, isEmpty);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(threadDetailController.selectedThreadId, isNull);
    expect(find.text('Deleted thread.'), findsOneWidget);
  });

  testWidgets('/clear clears the local transcript without interrupting', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    final timelineController = ChatTimelineController();
    timelineController.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_1',
        'sessionId': 'sess_1',
        'preview': 'Existing thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': [
          {
            'id': 'turn_1',
            'status': 'completed',
            'items': <Object?>[],
            'itemsView': 'full',
          },
        ],
      }),
    );
    addTearDown(timelineController.dispose);
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
      timelineController: timelineController,
    );

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Turn: turn_1 / completed'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('chat-composer-field')),
      '/clear',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(timelineController.turns, isEmpty);
    expect(turnController.activeThreadId, isNull);
    expect(turnRunner.interruptedTurns, isEmpty);
    expect(find.text('Timeline'), findsNothing);
    expect(find.text('Local transcript cleared.'), findsOneWidget);
  });

  testWidgets('interrupt button sends explicit turn interrupt only', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final turnRunner = _FakeTurnRunner();
    final starter = _FakeSessionStarter(
      threadListReader: const _FakeThreadListReader(
        page: ThreadListPage(threads: []),
      ),
      turnRunner: turnRunner,
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
    );
    addTearDown(turnController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await turnController.submitText('Run long task');
    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      turnController: turnController,
    );

    await tester.tap(find.byTooltip('Interrupt turn'));
    await tester.pumpAndSettle();

    expect(turnRunner.interruptedTurns, [
      (threadId: 'thr_new', turnId: 'turn_1'),
    ]);
    expect(find.text('Turn interrupted'), findsOneWidget);
  });

  testWidgets(
    'command palette disables commands unavailable during active turn',
    (tester) async {
      final approvalController = ApprovalStateController();
      final turnRunner = _FakeTurnRunner();
      final starter = _FakeSessionStarter(
        threadListReader: const _FakeThreadListReader(
          page: ThreadListPage(threads: []),
        ),
        turnRunner: turnRunner,
      );
      final sessionController = CodexSessionStateController(
        connector: starter,
        approvalController: approvalController,
      );
      final turnController = TurnController(
        runnerProvider: () => sessionController.turnRunner,
      );
      addTearDown(turnController.dispose);
      addTearDown(sessionController.dispose);
      addTearDown(approvalController.dispose);

      await sessionController.connect(_profile);
      await turnController.submitText('Run long task');
      await _pumpChatPage(
        tester,
        sessionController: sessionController,
        turnController: turnController,
      );

      await tester.tap(find.byKey(const ValueKey('chat-slash-command-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('slash-command-search-field')),
        'delete',
      );
      await tester.pumpAndSettle();

      final deleteTile = tester.widget<ListTile>(
        find.byKey(const ValueKey('slash-command-delete')),
      );
      expect(deleteTile.enabled, false);
      expect(
        find.textContaining('Unavailable while a turn is active'),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders timeline events and completed turns', (tester) async {
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);

    await _pumpChatPage(tester, timelineController: timelineController);
    timelineController.ingest(
      CodexEvent.fromNotification({
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
      }),
    );
    timelineController.ingest(
      CodexEvent.fromNotification({
        'method': 'item/agentMessage/delta',
        'params': {
          'threadId': 'thr_1',
          'turnId': 'turn_1',
          'itemId': 'item_1',
          'delta': 'hello',
        },
      }),
    );
    timelineController.ingest(
      CodexEvent.fromNotification({
        'method': 'turn/completed',
        'params': {
          'threadId': 'thr_1',
          'turn': {
            'id': 'turn_1',
            'status': 'completed',
            'items': <Object?>[],
            'itemsView': 'full',
          },
        },
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Turn: turn_1 / completed'), findsOneWidget);
    expect(find.text('Item: agentMessage'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('renders structured command file and MCP timeline items', (
    tester,
  ) async {
    final timelineController = ChatTimelineController();
    addTearDown(timelineController.dispose);

    timelineController.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_1',
        'sessionId': 'sess_1',
        'preview': 'Fix login bug',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': [
          {
            'id': 'turn_1',
            'status': 'completed',
            'itemsView': 'full',
            'items': [
              {
                'id': 'cmd_1',
                'type': 'commandExecution',
                'command': 'cargo test',
                'cwd': '/repo',
                'status': 'completed',
                'exitCode': 0,
                'durationMs': 1200,
                'aggregatedOutput': 'tests passed',
              },
              {
                'id': 'file_1',
                'type': 'fileChange',
                'status': 'completed',
                'changes': [
                  {'path': 'lib/main.dart', 'kind': 'modify', 'diff': '@@'},
                ],
              },
              {
                'id': 'mcp_1',
                'type': 'mcpToolCall',
                'server': 'github',
                'tool': 'search_issues',
                'status': 'completed',
              },
            ],
          },
        ],
      }),
    );

    await _pumpChatPage(tester, timelineController: timelineController);

    expect(find.text('cargo test'), findsOneWidget);
    expect(find.textContaining('Working directory: /repo'), findsOneWidget);
    expect(find.textContaining('Exit code: 0'), findsOneWidget);
    expect(find.text('tests passed'), findsOneWidget);
    expect(find.text('File changes'), findsOneWidget);
    expect(find.textContaining('modify lib/main.dart'), findsOneWidget);
    expect(find.text('github/search_issues'), findsOneWidget);
    expect(find.textContaining('Tool: search_issues'), findsOneWidget);
  });

  testWidgets('refreshes threads when the session becomes connected', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final starter = _FakeSessionStarter(
      threadListReader: _FakeThreadListReader(
        page: ThreadListPage(
          threads: [
            ThreadSummary.fromJson({
              'id': 'thr_2',
              'sessionId': 'sess_1',
              'preview': 'Review patch',
              'ephemeral': false,
              'status': 'idle',
              'cwd': '/repo',
              'updatedAt': 1,
            }),
          ],
        ),
      ),
    );
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    final threadController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    addTearDown(threadController.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await _pumpChatPage(
      tester,
      sessionController: sessionController,
      threadListController: threadController,
    );
    await sessionController.connect(_profile);
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Review patch'), findsOneWidget);
  });
}

Future<void> _pumpChatPage(
  WidgetTester tester, {
  CodexSessionStateController? sessionController,
  ThreadListController? threadListController,
  ThreadDetailController? threadDetailController,
  TurnController? turnController,
  ChatTimelineController? timelineController,
  AppAppearanceController? appearanceController,
  CodexConfigOverrideController? configOverrideController,
  CodexConfigSnapshotController? configSnapshotController,
  AccountSnapshotController? accountSnapshotController,
  AccountUsageSnapshotController? accountUsageSnapshotController,
  McpServerStatusController? mcpServerStatusController,
  ModelListController? modelListController,
  PermissionProfileListController? permissionProfileListController,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatPage(
          sessionController: sessionController,
          threadListController: threadListController,
          threadDetailController: threadDetailController,
          turnController: turnController,
          timelineController: timelineController,
          appearanceController: appearanceController,
          configOverrideController: configOverrideController,
          configSnapshotController: configSnapshotController,
          accountSnapshotController: accountSnapshotController,
          accountUsageSnapshotController: accountUsageSnapshotController,
          mcpServerStatusController: mcpServerStatusController,
          modelListController: modelListController,
          permissionProfileListController: permissionProfileListController,
        ),
      ),
    ),
  );
}

Future<_ConnectedChatHarness> _pumpConnectedChatPage(
  WidgetTester tester, {
  AppAppearanceController? appearanceController,
}) async {
  final approvalController = ApprovalStateController();
  final turnRunner = _FakeTurnRunner();
  final starter = _FakeSessionStarter(
    threadListReader: const _FakeThreadListReader(
      page: ThreadListPage(threads: []),
    ),
    turnRunner: turnRunner,
  );
  final sessionController = CodexSessionStateController(
    connector: starter,
    approvalController: approvalController,
  );
  final turnController = TurnController(
    runnerProvider: () => sessionController.turnRunner,
  );
  addTearDown(turnController.dispose);
  addTearDown(sessionController.dispose);
  addTearDown(approvalController.dispose);

  await sessionController.connect(_profile);
  await _pumpChatPage(
    tester,
    sessionController: sessionController,
    turnController: turnController,
    appearanceController: appearanceController,
  );
  return _ConnectedChatHarness(turnRunner: turnRunner);
}

Future<void> _submitComposerText(WidgetTester tester, String text) async {
  await tester.enterText(
    find.byKey(const ValueKey('chat-composer-field')),
    text,
  );
  await tester.pump();
  await tester.tap(find.byTooltip('Send'));
  await tester.pumpAndSettle();
}

class _ConnectedChatHarness {
  const _ConnectedChatHarness({required this.turnRunner});

  final _FakeTurnRunner turnRunner;
}

Future<void> _selectDropdownOption(
  WidgetTester tester,
  Key dropdownKey,
  String option,
) async {
  await tester.tap(find.byKey(dropdownKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

class _FakeThreadListReader implements ThreadListReader {
  const _FakeThreadListReader({required this.page});

  final ThreadListPage page;

  @override
  Future<ThreadListPage> listThreads({int limit = 20}) async => page;
}

class _CountingThreadListReader implements ThreadListReader {
  _CountingThreadListReader({required this.page});

  final ThreadListPage page;
  int calls = 0;

  @override
  Future<ThreadListPage> listThreads({int limit = 20}) async {
    calls++;
    return page;
  }
}

class _FakeThreadDetailReader implements ThreadDetailReader {
  _FakeThreadDetailReader({required this.detail});

  final ThreadDetail detail;
  final threadIds = <String>[];
  final includeTurnsValues = <bool>[];

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    threadIds.add(threadId);
    includeTurnsValues.add(includeTurns);
    return detail;
  }
}

class _FakeSessionStarter implements CodexSessionConnectionStarter {
  const _FakeSessionStarter({
    required this.threadListReader,
    this.turnRunner = const _ConstantTurnRunner(),
    this.threadMutationRunner = const _NoopThreadMutationRunner(),
    this.threadBackgroundTerminalRunner =
        const _FakeThreadBackgroundTerminalRunner(),
    this.threadGoalRunner = const _FakeThreadGoalRunner(),
    this.threadReviewRunner = const _FakeThreadReviewRunner(),
    this.skillListReader = const _FakeSkillListReader(),
    this.pluginListReader = const _FakePluginListReader(),
    this.hookListReader = const _FakeHookListReader(),
    this.appListReader = const _FakeAppListReader(),
    this.accountLogoutRunner = const _FakeAccountLogoutRunner(),
    this.feedbackUploadRunner = const _FakeFeedbackUploadRunner(),
    this.gitDiffReader = const _FakeGitDiffReader(),
    this.fileSearchReader = const _FakeFileSearchReader(),
  });

  final ThreadListReader threadListReader;
  final TurnRunner turnRunner;
  final ThreadMutationRunner threadMutationRunner;
  final ThreadBackgroundTerminalRunner threadBackgroundTerminalRunner;
  final ThreadGoalRunner threadGoalRunner;
  final ThreadReviewRunner threadReviewRunner;
  final SkillListReader skillListReader;
  final PluginListReader pluginListReader;
  final HookListReader hookListReader;
  final AppListReader appListReader;
  final AccountLogoutRunner accountLogoutRunner;
  final FeedbackUploadRunner feedbackUploadRunner;
  final GitDiffReader gitDiffReader;
  final FileSearchReader fileSearchReader;

  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    return _FakeSessionConnection(
      profile: profile,
      threadListReader: threadListReader,
      turnRunner: turnRunner,
      threadMutationRunner: threadMutationRunner,
      threadBackgroundTerminalRunner: threadBackgroundTerminalRunner,
      threadGoalRunner: threadGoalRunner,
      threadReviewRunner: threadReviewRunner,
      skillListReader: skillListReader,
      pluginListReader: pluginListReader,
      hookListReader: hookListReader,
      appListReader: appListReader,
      accountLogoutRunner: accountLogoutRunner,
      feedbackUploadRunner: feedbackUploadRunner,
      gitDiffReader: gitDiffReader,
      fileSearchReader: fileSearchReader,
    );
  }
}

class _FakeSessionConnection implements CodexSessionConnectionHandle {
  _FakeSessionConnection({
    required this.profile,
    required this.threadListReader,
    required this.turnRunner,
    required this.threadMutationRunner,
    required this.threadBackgroundTerminalRunner,
    required this.threadGoalRunner,
    required this.threadReviewRunner,
    required this.skillListReader,
    required this.pluginListReader,
    required this.hookListReader,
    required this.appListReader,
    required this.accountLogoutRunner,
    required this.feedbackUploadRunner,
    required this.gitDiffReader,
    required this.fileSearchReader,
  }) : _doneCompleter = Completer<void>();

  final Completer<void> _doneCompleter;

  @override
  final SshProfile profile;

  @override
  final ThreadListReader threadListReader;

  @override
  final TurnRunner turnRunner;

  @override
  final ThreadMutationRunner threadMutationRunner;

  @override
  final ThreadBackgroundTerminalRunner threadBackgroundTerminalRunner;

  @override
  final ThreadGoalRunner threadGoalRunner;

  @override
  final ThreadReviewRunner threadReviewRunner;

  @override
  final SkillListReader skillListReader;

  @override
  final PluginListReader pluginListReader;

  @override
  final HookListReader hookListReader;

  @override
  final AppListReader appListReader;

  @override
  final AccountLogoutRunner accountLogoutRunner;

  @override
  final FeedbackUploadRunner feedbackUploadRunner;

  @override
  final GitDiffReader gitDiffReader;

  @override
  final FileSearchReader fileSearchReader;

  @override
  ModelListReader get modelListReader => const _FakeModelListReader();

  @override
  PermissionProfileListReader get permissionProfileListReader =>
      const _FakePermissionProfileListReader();

  @override
  AccountSnapshotReader get accountSnapshotReader =>
      const _FakeAccountSnapshotReader();

  @override
  AccountUsageSnapshotReader get accountUsageSnapshotReader =>
      const _FakeAccountUsageSnapshotReader();

  @override
  McpServerStatusReader get mcpServerStatusReader =>
      const _FakeMcpServerStatusReader();

  @override
  CodexConfigSnapshotReader get configSnapshotReader =>
      const _FakeConfigSnapshotReader();

  @override
  Stream<CodexEvent> get events => const Stream.empty();

  @override
  ThreadDetailReader get threadDetailReader => _FakeThreadDetailReader(
    detail: ThreadDetail(
      thread: ThreadSummary.fromJson({
        'id': 'thr_1',
        'sessionId': 'sess_1',
        'preview': 'Fake thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': <Object?>[],
      }),
    ),
  );

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  Future<void> close({bool notifyApprovalController = true}) async {}
}

class _FakeConfigSnapshotReader implements CodexConfigSnapshotReader {
  const _FakeConfigSnapshotReader();

  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    return const CodexConfigSnapshot(config: {}, origins: {}, layers: []);
  }
}

class _RecordingConfigSnapshotReader implements CodexConfigSnapshotReader {
  _RecordingConfigSnapshotReader({required this.snapshot});

  final CodexConfigSnapshot snapshot;
  final cwdValues = <String?>[];

  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    cwdValues.add(cwd);
    return snapshot;
  }
}

class _FakeModelListReader implements ModelListReader {
  const _FakeModelListReader();

  @override
  Future<ModelListPage> listModels() async => const ModelListPage(models: []);
}

class _FakePermissionProfileListReader implements PermissionProfileListReader {
  const _FakePermissionProfileListReader();

  @override
  Future<PermissionProfileListPage> listPermissionProfiles({
    String? cwd,
  }) async {
    return const PermissionProfileListPage(profiles: []);
  }
}

class _FakeAccountSnapshotReader implements AccountSnapshotReader {
  const _FakeAccountSnapshotReader();

  @override
  Future<AccountSnapshot> readAccount({bool refreshToken = false}) async {
    return const AccountSnapshot(account: null, requiresOpenaiAuth: false);
  }
}

class _FakeAccountLogoutRunner implements AccountLogoutRunner {
  const _FakeAccountLogoutRunner();

  @override
  Future<void> logout() async {}
}

class _FakeFeedbackUploadRunner implements FeedbackUploadRunner {
  const _FakeFeedbackUploadRunner();

  @override
  Future<FeedbackUploadResult> uploadFeedback({
    required String classification,
    String? reason,
    String? threadId,
    String? turnId,
    bool includeLogs = false,
  }) async {
    return const FeedbackUploadResult(threadId: 'feedback_thread');
  }
}

class _FakeGitDiffReader implements GitDiffReader {
  const _FakeGitDiffReader();

  @override
  Future<GitDiffResult> readDiff({String? cwd}) async {
    return const GitDiffResult(isGitRepository: true, stat: '', diff: '');
  }
}

class _FakeFileSearchReader implements FileSearchReader {
  const _FakeFileSearchReader();

  @override
  Future<FileSearchResultPage> searchFiles({
    required String query,
    List<String> roots = const [],
    String? cancellationToken,
  }) async {
    return const FileSearchResultPage(files: []);
  }
}

class _FakeAccountUsageSnapshotReader implements AccountUsageSnapshotReader {
  const _FakeAccountUsageSnapshotReader();

  @override
  Future<AccountUsageSnapshot> readUsage() async {
    return const AccountUsageSnapshot(
      summary: AccountTokenUsageSummary(),
      dailyUsageBuckets: [],
      rateLimits: null,
      rateLimitsByLimitId: {},
      rateLimitResetCredits: null,
    );
  }
}

class _FakeMcpServerStatusReader implements McpServerStatusReader {
  const _FakeMcpServerStatusReader();

  @override
  Future<McpServerStatusPage> listMcpServers({
    String? threadId,
    String? cursor,
    int? limit,
    McpServerStatusDetail detail = McpServerStatusDetail.toolsAndAuthOnly,
  }) async {
    return const McpServerStatusPage(servers: []);
  }
}

class _FakeSkillListReader implements SkillListReader {
  const _FakeSkillListReader();

  @override
  Future<SkillListPage> listSkills({
    List<String> cwds = const [],
    bool forceReload = false,
  }) async {
    return const SkillListPage(entries: []);
  }
}

class _FakePluginListReader implements PluginListReader {
  const _FakePluginListReader();

  @override
  Future<PluginListPage> listPlugins({
    List<String> cwds = const [],
    List<PluginMarketplaceKind> marketplaceKinds = const [],
  }) async {
    return const PluginListPage(marketplaces: []);
  }
}

class _FakeHookListReader implements HookListReader {
  const _FakeHookListReader();

  @override
  Future<HookListPage> listHooks({List<String> cwds = const []}) async {
    return const HookListPage(entries: []);
  }
}

class _FakeAppListReader implements AppListReader {
  const _FakeAppListReader();

  @override
  Future<AppListPage> listApps({
    String? cursor,
    int? limit,
    String? threadId,
    bool forceRefetch = false,
  }) async {
    return const AppListPage(apps: []);
  }
}

class _FakeThreadBackgroundTerminalRunner
    implements ThreadBackgroundTerminalRunner {
  const _FakeThreadBackgroundTerminalRunner();

  @override
  Future<ThreadBackgroundTerminalPage> listTerminals({
    required String threadId,
    String? cursor,
    int? limit,
  }) async {
    return const ThreadBackgroundTerminalPage(terminals: []);
  }

  @override
  Future<void> cleanTerminals({required String threadId}) async {}
}

class _RecordingThreadBackgroundTerminalRunner
    implements ThreadBackgroundTerminalRunner {
  _RecordingThreadBackgroundTerminalRunner({
    this.page = const ThreadBackgroundTerminalPage(terminals: []),
  });

  final ThreadBackgroundTerminalPage page;
  final listCalls = <({String threadId, String? cursor, int? limit})>[];
  final cleanCalls = <String>[];

  @override
  Future<ThreadBackgroundTerminalPage> listTerminals({
    required String threadId,
    String? cursor,
    int? limit,
  }) async {
    listCalls.add((threadId: threadId, cursor: cursor, limit: limit));
    return page;
  }

  @override
  Future<void> cleanTerminals({required String threadId}) async {
    cleanCalls.add(threadId);
  }
}

class _FakeThreadGoalRunner implements ThreadGoalRunner {
  const _FakeThreadGoalRunner();

  @override
  Future<ThreadGoalGetResult> getGoal({required String threadId}) async {
    return const ThreadGoalGetResult();
  }

  @override
  Future<ThreadGoalSetResult> setGoal({
    required String threadId,
    String? objective,
    String? status,
    int? tokenBudget,
  }) async {
    return ThreadGoalSetResult(
      goal: _goal(
        threadId: threadId,
        objective: objective ?? 'Goal',
        status: status ?? 'active',
        tokenBudget: tokenBudget,
      ),
    );
  }

  @override
  Future<ThreadGoalClearResult> clearGoal({required String threadId}) async {
    return const ThreadGoalClearResult(cleared: false);
  }
}

class _RecordingThreadGoalRunner implements ThreadGoalRunner {
  _RecordingThreadGoalRunner({ThreadGoal? goal}) : goal = goal ?? _goal();

  ThreadGoal goal;
  final getGoalThreadIds = <String>[];
  final setGoalCalls =
      <
        ({String threadId, String? objective, String? status, int? tokenBudget})
      >[];
  final clearGoalThreadIds = <String>[];

  @override
  Future<ThreadGoalGetResult> getGoal({required String threadId}) async {
    getGoalThreadIds.add(threadId);
    return ThreadGoalGetResult(goal: goal);
  }

  @override
  Future<ThreadGoalSetResult> setGoal({
    required String threadId,
    String? objective,
    String? status,
    int? tokenBudget,
  }) async {
    setGoalCalls.add((
      threadId: threadId,
      objective: objective,
      status: status,
      tokenBudget: tokenBudget,
    ));
    goal = _goal(
      threadId: threadId,
      objective: objective ?? goal.objective,
      status: status ?? goal.status,
      tokenBudget: tokenBudget ?? goal.tokenBudget,
    );
    return ThreadGoalSetResult(goal: goal);
  }

  @override
  Future<ThreadGoalClearResult> clearGoal({required String threadId}) async {
    clearGoalThreadIds.add(threadId);
    return const ThreadGoalClearResult(cleared: true);
  }
}

ThreadGoal _goal({
  String threadId = 'thr_1',
  String objective = 'Ship the feature',
  String status = 'active',
  int? tokenBudget = 200000,
}) {
  return ThreadGoal(
    threadId: threadId,
    objective: objective,
    status: status,
    tokenBudget: tokenBudget,
    tokensUsed: 1234,
    timeUsedSeconds: 60,
    createdAtSeconds: 1,
    updatedAtSeconds: 2,
    raw: const {},
  );
}

class _FakeThreadReviewRunner implements ThreadReviewRunner {
  const _FakeThreadReviewRunner();

  @override
  Future<ThreadReviewStartResult> startReview({
    required String threadId,
    required ThreadReviewTarget target,
    ThreadReviewDelivery? delivery,
  }) async {
    return ThreadReviewStartResult(
      reviewThreadId: threadId,
      turn: _reviewTurn('turn_review'),
    );
  }
}

class _RecordingThreadReviewRunner implements ThreadReviewRunner {
  _RecordingThreadReviewRunner({this.reviewThreadId});

  final String? reviewThreadId;
  final calls =
      <
        ({
          String threadId,
          ThreadReviewTarget target,
          ThreadReviewDelivery? delivery,
        })
      >[];

  @override
  Future<ThreadReviewStartResult> startReview({
    required String threadId,
    required ThreadReviewTarget target,
    ThreadReviewDelivery? delivery,
  }) async {
    calls.add((threadId: threadId, target: target, delivery: delivery));
    return ThreadReviewStartResult(
      reviewThreadId: reviewThreadId ?? threadId,
      turn: _reviewTurn('turn_review_${calls.length}'),
    );
  }
}

TurnSummary _reviewTurn(String turnId) {
  return TurnSummary.fromJson({
    'id': turnId,
    'status': 'inProgress',
    'itemsView': 'notLoaded',
    'items': [
      {
        'id': '${turnId}_user',
        'type': 'userMessage',
        'content': [
          {'type': 'text', 'text': 'Review current changes'},
        ],
      },
    ],
  });
}

class _RecordingMcpServerStatusReader implements McpServerStatusReader {
  _RecordingMcpServerStatusReader({required this.page});

  final McpServerStatusPage page;
  final threadIds = <String?>[];
  final cursors = <String?>[];
  final limits = <int?>[];
  final details = <McpServerStatusDetail>[];
  int calls = 0;

  @override
  Future<McpServerStatusPage> listMcpServers({
    String? threadId,
    String? cursor,
    int? limit,
    McpServerStatusDetail detail = McpServerStatusDetail.toolsAndAuthOnly,
  }) async {
    calls++;
    threadIds.add(threadId);
    cursors.add(cursor);
    limits.add(limit);
    details.add(detail);
    return page;
  }
}

class _RecordingSkillListReader implements SkillListReader {
  _RecordingSkillListReader({required this.page});

  final SkillListPage page;
  final cwds = <List<String>>[];
  final forceReloadValues = <bool>[];

  @override
  Future<SkillListPage> listSkills({
    List<String> cwds = const [],
    bool forceReload = false,
  }) async {
    this.cwds.add(List.unmodifiable(cwds));
    forceReloadValues.add(forceReload);
    return page;
  }
}

class _RecordingPluginListReader implements PluginListReader {
  _RecordingPluginListReader({required this.page});

  final PluginListPage page;
  final cwds = <List<String>>[];
  final marketplaceKinds = <List<PluginMarketplaceKind>>[];

  @override
  Future<PluginListPage> listPlugins({
    List<String> cwds = const [],
    List<PluginMarketplaceKind> marketplaceKinds = const [],
  }) async {
    this.cwds.add(List.unmodifiable(cwds));
    this.marketplaceKinds.add(List.unmodifiable(marketplaceKinds));
    return page;
  }
}

class _RecordingHookListReader implements HookListReader {
  _RecordingHookListReader({required this.page});

  final HookListPage page;
  final cwds = <List<String>>[];

  @override
  Future<HookListPage> listHooks({List<String> cwds = const []}) async {
    this.cwds.add(List.unmodifiable(cwds));
    return page;
  }
}

class _RecordingAppListReader implements AppListReader {
  _RecordingAppListReader({required this.page});

  final AppListPage page;
  final cursors = <String?>[];
  final limits = <int?>[];
  final threadIds = <String?>[];
  final forceRefetchValues = <bool>[];

  @override
  Future<AppListPage> listApps({
    String? cursor,
    int? limit,
    String? threadId,
    bool forceRefetch = false,
  }) async {
    cursors.add(cursor);
    limits.add(limit);
    threadIds.add(threadId);
    forceRefetchValues.add(forceRefetch);
    return page;
  }
}

class _RecordingAccountUsageSnapshotReader
    implements AccountUsageSnapshotReader {
  _RecordingAccountUsageSnapshotReader({required this.snapshot});

  final AccountUsageSnapshot snapshot;
  int calls = 0;

  @override
  Future<AccountUsageSnapshot> readUsage() async {
    calls++;
    return snapshot;
  }
}

class _RecordingAccountSnapshotReader implements AccountSnapshotReader {
  _RecordingAccountSnapshotReader({required this.snapshot});

  final AccountSnapshot snapshot;
  final refreshTokenValues = <bool>[];

  @override
  Future<AccountSnapshot> readAccount({bool refreshToken = false}) async {
    refreshTokenValues.add(refreshToken);
    return snapshot;
  }
}

class _RecordingAccountLogoutRunner implements AccountLogoutRunner {
  int calls = 0;

  @override
  Future<void> logout() async {
    calls++;
  }
}

class _RecordingFeedbackUploadRunner implements FeedbackUploadRunner {
  final calls =
      <
        ({
          String classification,
          String? reason,
          String? threadId,
          String? turnId,
          bool includeLogs,
        })
      >[];

  @override
  Future<FeedbackUploadResult> uploadFeedback({
    required String classification,
    String? reason,
    String? threadId,
    String? turnId,
    bool includeLogs = false,
  }) async {
    calls.add((
      classification: classification,
      reason: reason,
      threadId: threadId,
      turnId: turnId,
      includeLogs: includeLogs,
    ));
    return const FeedbackUploadResult(threadId: 'feedback_thread');
  }
}

class _RecordingGitDiffReader implements GitDiffReader {
  _RecordingGitDiffReader({required this.result});

  final GitDiffResult result;
  final cwdValues = <String?>[];

  @override
  Future<GitDiffResult> readDiff({String? cwd}) async {
    cwdValues.add(cwd);
    return result;
  }
}

class _RecordingFileSearchReader implements FileSearchReader {
  _RecordingFileSearchReader({required this.page});

  final FileSearchResultPage page;
  final calls = <({String query, List<String> roots})>[];

  @override
  Future<FileSearchResultPage> searchFiles({
    required String query,
    List<String> roots = const [],
    String? cancellationToken,
  }) async {
    calls.add((query: query, roots: roots));
    return page;
  }
}

class _RecordingModelListReader implements ModelListReader {
  _RecordingModelListReader({required this.page});

  final ModelListPage page;
  int calls = 0;

  @override
  Future<ModelListPage> listModels() async {
    calls++;
    return page;
  }
}

class _RecordingPermissionProfileListReader
    implements PermissionProfileListReader {
  _RecordingPermissionProfileListReader({required this.page});

  final PermissionProfileListPage page;
  final cwdValues = <String?>[];

  @override
  Future<PermissionProfileListPage> listPermissionProfiles({
    String? cwd,
  }) async {
    cwdValues.add(cwd);
    return page;
  }
}

class _FakeTurnRunner implements TurnRunner {
  int startedThreads = 0;
  final resumedThreads = <String>[];
  final startedTurns = <({String threadId, String text})>[];
  final startedTurnOverrides = <CodexConfigOverrides>[];
  final startedTurnTextElements = <List<TurnTextElement>>[];
  final interruptedTurns = <({String threadId, String turnId})>[];

  @override
  Future<ThreadSummary> startThread() async {
    startedThreads++;
    return _thread('thr_new');
  }

  @override
  Future<ThreadSummary> resumeThread({required String threadId}) async {
    resumedThreads.add(threadId);
    return _thread(threadId);
  }

  @override
  Future<TurnSummary> startTurn({
    required String threadId,
    required String text,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
    List<TurnTextElement> textElements = const [],
  }) async {
    startedTurns.add((threadId: threadId, text: text));
    startedTurnOverrides.add(overrides);
    startedTurnTextElements.add(textElements);
    return TurnSummary.fromJson({
      'id': 'turn_${startedTurns.length}',
      'status': 'inProgress',
      'items': <Object?>[],
      'itemsView': 'notLoaded',
    });
  }

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    interruptedTurns.add((threadId: threadId, turnId: turnId));
  }
}

class _FakeThreadMutationRunner implements ThreadMutationRunner {
  _FakeThreadMutationRunner({
    ThreadSummary? forkedThread,
    ThreadSummary? sideThread,
  }) : forkedThread = forkedThread ?? _thread('thr_fork'),
       sideThread = sideThread ?? _thread('thr_side');

  final ThreadSummary forkedThread;
  final ThreadSummary sideThread;
  final forkedThreads =
      <({String threadId, String? lastTurnId, bool ephemeral})>[];
  final sideStartedThreads = <String>[];
  final compactedThreads = <String>[];
  final renamedThreads = <({String threadId, String name})>[];
  final archivedThreads = <String>[];
  final deletedThreads = <String>[];

  @override
  Future<ThreadSummary> forkThread({
    required String threadId,
    String? lastTurnId,
    bool ephemeral = false,
  }) async {
    forkedThreads.add((
      threadId: threadId,
      lastTurnId: lastTurnId,
      ephemeral: ephemeral,
    ));
    return forkedThread;
  }

  @override
  Future<ThreadSummary> startSideConversation({
    required String threadId,
  }) async {
    sideStartedThreads.add(threadId);
    return sideThread;
  }

  @override
  Future<void> compactThread({required String threadId}) async {
    compactedThreads.add(threadId);
  }

  @override
  Future<void> setThreadName({
    required String threadId,
    required String name,
  }) async {
    renamedThreads.add((threadId: threadId, name: name));
  }

  @override
  Future<void> archiveThread({required String threadId}) async {
    archivedThreads.add(threadId);
  }

  @override
  Future<void> deleteThread({required String threadId}) async {
    deletedThreads.add(threadId);
  }
}

class _NoopThreadMutationRunner implements ThreadMutationRunner {
  const _NoopThreadMutationRunner();

  @override
  Future<ThreadSummary> forkThread({
    required String threadId,
    String? lastTurnId,
    bool ephemeral = false,
  }) async => _thread('thr_fork');

  @override
  Future<ThreadSummary> startSideConversation({
    required String threadId,
  }) async {
    return _thread('thr_side');
  }

  @override
  Future<void> compactThread({required String threadId}) async {}

  @override
  Future<void> setThreadName({
    required String threadId,
    required String name,
  }) async {}

  @override
  Future<void> archiveThread({required String threadId}) async {}

  @override
  Future<void> deleteThread({required String threadId}) async {}
}

class _ConstantTurnRunner implements TurnRunner {
  const _ConstantTurnRunner();

  @override
  Future<ThreadSummary> startThread() async => _thread('thr_1');

  @override
  Future<ThreadSummary> resumeThread({required String threadId}) async =>
      _thread(threadId);

  @override
  Future<TurnSummary> startTurn({
    required String threadId,
    required String text,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
    List<TurnTextElement> textElements = const [],
  }) async => TurnSummary.fromJson({
    'id': 'turn_1',
    'status': 'inProgress',
    'items': <Object?>[],
    'itemsView': 'notLoaded',
  });

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {}
}

ThreadSummary _thread(String threadId) {
  return ThreadSummary.fromJson({
    'id': threadId,
    'sessionId': 'sess_1',
    'preview': 'Fake thread',
    'ephemeral': false,
    'status': 'idle',
    'cwd': '/repo',
    'updatedAt': 1,
  });
}
