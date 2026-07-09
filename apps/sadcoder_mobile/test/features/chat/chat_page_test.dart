import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_page.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_controller.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

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

class _FakeSessionStarter implements CodexSessionConnectionStarter {
  const _FakeSessionStarter({required this.threadListReader});

  final ThreadListReader threadListReader;

  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    return _FakeSessionConnection(
      profile: profile,
      threadListReader: threadListReader,
    );
  }
}

class _FakeSessionConnection implements CodexSessionConnectionHandle {
  _FakeSessionConnection({
    required this.profile,
    required this.threadListReader,
  }) : _doneCompleter = Completer<void>();

  final Completer<void> _doneCompleter;

  @override
  final SshProfile profile;

  @override
  final ThreadListReader threadListReader;

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  Future<void> close({bool notifyApprovalController = true}) async {}
}
