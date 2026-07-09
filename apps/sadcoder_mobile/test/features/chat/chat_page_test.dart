import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
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

    expect(find.textContaining('Model: gpt-5 / app default'), findsOneWidget);

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
    expect(find.textContaining('Model: gpt-5 / app default'), findsOneWidget);
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
        ),
      ),
    ),
  );
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

class _FakeThreadDetailReader implements ThreadDetailReader {
  _FakeThreadDetailReader({required this.detail});

  final ThreadDetail detail;
  final threadIds = <String>[];

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    threadIds.add(threadId);
    return detail;
  }
}

class _FakeSessionStarter implements CodexSessionConnectionStarter {
  const _FakeSessionStarter({
    required this.threadListReader,
    this.turnRunner = const _ConstantTurnRunner(),
  });

  final ThreadListReader threadListReader;
  final TurnRunner turnRunner;

  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    return _FakeSessionConnection(
      profile: profile,
      threadListReader: threadListReader,
      turnRunner: turnRunner,
    );
  }
}

class _FakeSessionConnection implements CodexSessionConnectionHandle {
  _FakeSessionConnection({
    required this.profile,
    required this.threadListReader,
    required this.turnRunner,
  }) : _doneCompleter = Completer<void>();

  final Completer<void> _doneCompleter;

  @override
  final SshProfile profile;

  @override
  final ThreadListReader threadListReader;

  @override
  final TurnRunner turnRunner;

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

class _FakeTurnRunner implements TurnRunner {
  int startedThreads = 0;
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
