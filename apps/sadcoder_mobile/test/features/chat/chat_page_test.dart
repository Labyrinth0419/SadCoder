import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_page.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_timeline_controller.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_mutation_runner.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/turns/turn_controller.dart';
import 'package:sadcoder_mobile/src/turns/turn_runner.dart';

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
      '/keymap',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(turnRunner.startedTurns, isEmpty);
    expect(find.text('/keymap is not implemented yet.'), findsOneWidget);
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
        'Approval policy: server default\n'
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
          'sandbox_mode': {'type': 'workspace-write'},
        },
      }),
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
    final turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      overrideLayersProvider: () => overrideController.layers,
    );
    addTearDown(turnController.dispose);
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
    expect(
      find.textContaining(
        'Server config snapshot: Model=gpt-5-codex, Reasoning effort=high, Approval policy=on-request, Sandbox mode=workspace-write',
      ),
      findsOneWidget,
    );
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
  CodexConfigOverrideController? configOverrideController,
  CodexConfigSnapshotController? configSnapshotController,
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
          configOverrideController: configOverrideController,
          configSnapshotController: configSnapshotController,
        ),
      ),
    ),
  );
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
  });

  final ThreadListReader threadListReader;
  final TurnRunner turnRunner;
  final ThreadMutationRunner threadMutationRunner;

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
    );
  }
}

class _FakeSessionConnection implements CodexSessionConnectionHandle {
  _FakeSessionConnection({
    required this.profile,
    required this.threadListReader,
    required this.turnRunner,
    required this.threadMutationRunner,
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

class _FakeTurnRunner implements TurnRunner {
  int startedThreads = 0;
  final resumedThreads = <String>[];
  final startedTurns = <({String threadId, String text})>[];
  final startedTurnOverrides = <CodexConfigOverrides>[];
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
  }) async {
    startedTurns.add((threadId: threadId, text: text));
    startedTurnOverrides.add(overrides);
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
  final renamedThreads = <({String threadId, String name})>[];
  final archivedThreads = <String>[];
  final deletedThreads = <String>[];

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
