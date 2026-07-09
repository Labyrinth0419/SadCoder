import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/agent/agent_status.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/features/hosts/hosts_page.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/probe/m0_probe_coordinator.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/reconnect_policy.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/turns/turn_runner.dart';

void main() {
  testWidgets('runs a manual M0 probe from the host form', (tester) async {
    final runner = _FakeProbeRunner(
      report: const M0ProbeReport(
        agentStatus: _readyStatus,
        steps: [
          M0ProbeStepResult(step: M0ProbeStep.agentStatus, ok: true),
          M0ProbeStepResult(step: M0ProbeStep.proxyConnect, ok: true),
          M0ProbeStepResult(step: M0ProbeStep.initialize, ok: true),
          M0ProbeStepResult(step: M0ProbeStep.modelList, ok: true),
          M0ProbeStepResult(step: M0ProbeStep.threadList, ok: true),
        ],
      ),
    );

    await _pumpHostsPage(tester, runner);

    await tester.enterText(find.byKey(const ValueKey('host-field')), 'srv.dev');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'alice',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'secret',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('probe-test-button')));

    await tester.tap(find.byKey(const ValueKey('probe-test-button')));
    await tester.pumpAndSettle();

    expect(runner.lastProfile?.host, 'srv.dev');
    expect(runner.lastProfile?.username, 'alice');
    expect(runner.lastProfile?.password, 'secret');
    expect(runner.lastProfile?.agentCommand, 'sadcoder-agent');
    expect(find.text('Probe passed'), findsOneWidget);
    expect(find.text('Backend: stdio fallback'), findsOneWidget);
    expect(
      find.text('Reconnect cache: 1 pending approvals, 7 recent events'),
      findsOneWidget,
    );
    expect(
      find.text('State path: /home/alice/.sadcoder/agent-state.json'),
      findsOneWidget,
    );
    expect(
      find.text(
        'on-demand stdio fallback; SSH disconnect can end this backend',
      ),
      findsOneWidget,
    );
    expect(find.text('Agent status'), findsOneWidget);
    expect(find.text('Thread list'), findsOneWidget);
  });

  testWidgets('validates required host fields before probing', (tester) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));

    await _pumpHostsPage(tester, runner);

    await tester.ensureVisible(find.byKey(const ValueKey('probe-test-button')));
    await tester.tap(find.byKey(const ValueKey('probe-test-button')));
    await tester.pumpAndSettle();

    expect(runner.lastProfile, isNull);
    expect(find.text('Host is required'), findsOneWidget);
    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('connects and disconnects a Codex app session', (tester) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));
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
    final starter = _FakeSessionStarter();
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await _pumpHostsPage(tester, runner, sessionController: sessionController);

    await tester.enterText(find.byKey(const ValueKey('host-field')), 'srv.dev');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'alice',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'secret',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('session-connect-button')),
    );

    await tester.tap(find.byKey(const ValueKey('session-connect-button')));
    await _pumpUntil(
      tester,
      () => sessionController.status == CodexSessionStatus.connected,
      describe: () => 'status=${sessionController.status}',
    );

    expect(starter.connectedProfiles.single.host, 'srv.dev');
    expect(starter.connectedProfiles.single.username, 'alice');
    expect(sessionController.status, CodexSessionStatus.connected);
    expect(find.text('Active connection: alice@srv.dev:22'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('session-disconnect-button')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('session-disconnect-button')),
    );
    await tester.tap(find.byKey(const ValueKey('session-disconnect-button')));
    await _pumpUntil(
      tester,
      () => sessionController.status == CodexSessionStatus.idle,
      describe: () =>
          'status=${sessionController.status}, closeCount=${starter.closeCount}',
    );

    expect(starter.closeCount, 1);
    expect(sessionController.status, CodexSessionStatus.idle);
    expect(approvalController.approvals.single.requestId, 'approval-1');
    expect(approvalController.canRespond, false);
    expect(find.text('No active connection'), findsOneWidget);
  });

  testWidgets('shows connection failure from the session controller', (
    tester,
  ) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));
    final approvalController = ApprovalStateController();
    final sessionController = CodexSessionStateController(
      connector: _FakeSessionStarter(failConnect: true),
      approvalController: approvalController,
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await _pumpHostsPage(tester, runner, sessionController: sessionController);

    await tester.enterText(find.byKey(const ValueKey('host-field')), 'srv.dev');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'alice',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'secret',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('session-connect-button')),
    );

    await tester.tap(find.byKey(const ValueKey('session-connect-button')));
    await _pumpUntil(
      tester,
      () => sessionController.status == CodexSessionStatus.failed,
      describe: () => 'status=${sessionController.status}',
    );

    expect(sessionController.status, CodexSessionStatus.failed);
    expect(find.text('Connection failed: alice@srv.dev:22'), findsOneWidget);
    expect(find.textContaining('connect failed'), findsOneWidget);
  });

  testWidgets('shows reconnecting state after an observed session drops', (
    tester,
  ) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));
    final approvalController = ApprovalStateController();
    final starter = _FakeSessionStarter();
    final sessionController = CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
      reconnectPolicy: const ReconnectPolicy.fixed(
        delays: [Duration(seconds: 1)],
      ),
      reconnectDelayScheduler: _FakeReconnectDelayScheduler(),
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await _pumpHostsPage(tester, runner, sessionController: sessionController);

    await tester.enterText(find.byKey(const ValueKey('host-field')), 'srv.dev');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'alice',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-field')),
      'secret',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('session-connect-button')),
    );

    await tester.tap(find.byKey(const ValueKey('session-connect-button')));
    await _pumpUntil(
      tester,
      () => sessionController.status == CodexSessionStatus.connected,
      describe: () => 'status=${sessionController.status}',
    );

    starter.connections.single.completeDone();
    await _pumpUntil(
      tester,
      () => sessionController.status == CodexSessionStatus.reconnecting,
      describe: () => 'status=${sessionController.status}',
    );

    expect(find.text('Reconnecting: alice@srv.dev:22 (1s)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('session-disconnect-button')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  String Function()? describe,
}) async {
  for (var i = 0; i < 20; i++) {
    if (predicate()) {
      await tester.pump();
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(predicate(), isTrue, reason: describe?.call());
}

Future<void> _pumpHostsPage(
  WidgetTester tester,
  M0ProbeRunner runner, {
  CodexSessionStateController? sessionController,
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
      home: HostsPage(
        probeRunner: runner,
        sessionController: sessionController,
      ),
    ),
  );
}

const _readyStatus = AgentStatus(
  agentVersion: '0.1.0',
  platformOs: 'linux',
  platformArch: 'x86_64',
  codexPath: 'codex',
  codexAvailable: true,
  codexVersion: 'codex-cli 0.142.5',
  backendKind: BackendKind.codexAppServerStdio,
  backendState: BackendState.ready,
  backendDetail:
      'on-demand stdio fallback; SSH disconnect can end this backend',
  reconnectCache: AgentReconnectCacheStatus(
    statePath: '/home/alice/.sadcoder/agent-state.json',
    schemaVersion: 1,
    pendingApprovals: 1,
    recentEvents: 7,
  ),
);

class _FakeProbeRunner implements M0ProbeRunner {
  _FakeProbeRunner({required this.report});

  final M0ProbeReport report;
  SshProfile? lastProfile;

  @override
  Future<M0ProbeReport> run(SshProfile profile) async {
    lastProfile = profile;
    return report;
  }
}

class _FakeSessionStarter implements CodexSessionConnectionStarter {
  _FakeSessionStarter({this.failConnect = false});

  final bool failConnect;
  final connectedProfiles = <SshProfile>[];
  final connections = <_FakeSessionConnection>[];
  int closeCount = 0;

  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    if (failConnect) {
      throw StateError('connect failed');
    }
    connectedProfiles.add(profile);
    final connection = _FakeSessionConnection(
      profile: profile,
      onClose: () => closeCount++,
    );
    connections.add(connection);
    return connection;
  }
}

class _FakeSessionConnection implements CodexSessionConnectionHandle {
  _FakeSessionConnection({required this.profile, required this.onClose});

  final _doneCompleter = Completer<void>();

  @override
  final SshProfile profile;

  @override
  ThreadListReader get threadListReader => const _FakeThreadListReader();

  @override
  ThreadDetailReader get threadDetailReader => const _FakeThreadDetailReader();

  @override
  CodexConfigSnapshotReader get configSnapshotReader =>
      const _FakeConfigSnapshotReader();

  @override
  TurnRunner get turnRunner => const _FakeTurnRunner();

  @override
  Stream<CodexEvent> get events => const Stream.empty();

  final VoidCallback onClose;
  bool _closed = false;

  @override
  Future<void> get done => _doneCompleter.future;

  void completeDone() {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  @override
  Future<void> close({bool notifyApprovalController = true}) async {
    if (_closed) {
      return;
    }
    _closed = true;
    onClose();
  }
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

class _FakeThreadListReader implements ThreadListReader {
  const _FakeThreadListReader();

  @override
  Future<ThreadListPage> listThreads({int limit = 20}) async {
    return const ThreadListPage(threads: []);
  }
}

class _FakeThreadDetailReader implements ThreadDetailReader {
  const _FakeThreadDetailReader();

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    return ThreadDetail(
      thread: ThreadSummary.fromJson({
        'id': threadId,
        'sessionId': 'sess_1',
        'preview': 'Fake thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': <Object?>[],
      }),
    );
  }
}

class _FakeTurnRunner implements TurnRunner {
  const _FakeTurnRunner();

  @override
  Future<ThreadSummary> startThread() async => ThreadSummary.fromJson({
    'id': 'thr_1',
    'sessionId': 'sess_1',
    'preview': 'Fake thread',
    'ephemeral': false,
    'status': 'idle',
    'cwd': '/repo',
    'updatedAt': 1,
  });

  @override
  Future<ThreadSummary> resumeThread({required String threadId}) async =>
      ThreadSummary.fromJson({
        'id': threadId,
        'sessionId': 'sess_1',
        'preview': 'Fake thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
      });

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

class _FakeReconnectDelayScheduler implements ReconnectDelayScheduler {
  @override
  Future<void> wait(Duration delay) => Completer<void>().future;
}
