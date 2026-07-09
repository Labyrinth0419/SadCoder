import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/app/sadcoder_app.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/turns/turn_runner.dart';

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

  testWidgets('backfills chat timeline from loaded thread detail', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final sessionController = CodexSessionStateController(
      connector: _StaticSessionStarter(
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
                'itemsView': 'full',
                'items': [
                  {
                    'id': 'item_1',
                    'type': 'agentMessage',
                    'text': 'History is visible',
                  },
                ],
              },
            ],
          }),
        ),
      ),
      approvalController: approvalController,
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await tester.pumpWidget(SadCoderApp(sessionController: sessionController));
    await tester.tap(find.text('Chat').last);
    await tester.pumpAndSettle();
    final threadTile = find.byKey(const ValueKey('thread-summary-thr_1'));
    await tester.scrollUntilVisible(
      threadTile,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(threadTile);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Timeline'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Turn: turn_1 / completed'), findsOneWidget);
    expect(find.text('Item: agentMessage'), findsOneWidget);
    expect(find.text('History is visible'), findsOneWidget);
  });
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

class _NeverConnectsSessionStarter implements CodexSessionConnectionStarter {
  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) {
    throw StateError('not used by this widget test');
  }
}

class _StaticSessionStarter implements CodexSessionConnectionStarter {
  const _StaticSessionStarter({required this.threads, required this.detail});

  final List<ThreadSummary> threads;
  final ThreadDetail detail;

  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    return _StaticSessionConnection(
      profile: profile,
      threads: threads,
      detail: detail,
    );
  }
}

class _StaticSessionConnection implements CodexSessionConnectionHandle {
  _StaticSessionConnection({
    required this.profile,
    required List<ThreadSummary> threads,
    required ThreadDetail detail,
  }) : threadListReader = _StaticThreadListReader(threads),
       threadDetailReader = _StaticThreadDetailReader(detail),
       _doneCompleter = Completer<void>();

  final Completer<void> _doneCompleter;

  @override
  final SshProfile profile;

  @override
  final ThreadListReader threadListReader;

  @override
  final ThreadDetailReader threadDetailReader;

  @override
  CodexConfigSnapshotReader get configSnapshotReader =>
      const _StaticConfigSnapshotReader();

  @override
  TurnRunner get turnRunner => const _NoopTurnRunner();

  @override
  Stream<CodexEvent> get events => const Stream.empty();

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  Future<void> close({bool notifyApprovalController = true}) async {}
}

class _StaticConfigSnapshotReader implements CodexConfigSnapshotReader {
  const _StaticConfigSnapshotReader();

  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    return const CodexConfigSnapshot(config: {}, origins: {}, layers: []);
  }
}

class _StaticThreadListReader implements ThreadListReader {
  const _StaticThreadListReader(this.threads);

  final List<ThreadSummary> threads;

  @override
  Future<ThreadListPage> listThreads({int limit = 20}) async {
    return ThreadListPage(threads: threads);
  }
}

class _StaticThreadDetailReader implements ThreadDetailReader {
  const _StaticThreadDetailReader(this.detail);

  final ThreadDetail detail;

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async => detail;
}

class _NoopTurnRunner implements TurnRunner {
  const _NoopTurnRunner();

  @override
  Future<ThreadSummary> startThread() {
    throw UnimplementedError();
  }

  @override
  Future<ThreadSummary> resumeThread({required String threadId}) {
    throw UnimplementedError();
  }

  @override
  Future<TurnSummary> startTurn({
    required String threadId,
    required String text,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) {
    throw UnimplementedError();
  }
}
