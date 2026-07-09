import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/agent/agent_status.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal_runner.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/features/hosts/hosts_page.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal_runner.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_reader.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_reader.dart';
import 'package:sadcoder_mobile/src/probe/m0_probe_coordinator.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review_runner.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/reconnect_policy.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/skills/skill_list_reader.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_mutation_runner.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/turns/turn_runner.dart';
import 'package:sadcoder_mobile/src/usage/account_usage_snapshot_reader.dart';

void main() {
  testWidgets('runs a manual M0 probe from the host form', (tester) async {
    final runner = _FakeProbeRunner(
      report: const M0ProbeReport(
        agentStatus: _readyStatus,
        steps: [
          M0ProbeStepResult(step: M0ProbeStep.agentStatus, ok: true),
          M0ProbeStepResult(step: M0ProbeStep.proxyConnect, ok: true),
          M0ProbeStepResult(step: M0ProbeStep.initialize, ok: true),
          M0ProbeStepResult(step: M0ProbeStep.accountRead, ok: true),
          M0ProbeStepResult(step: M0ProbeStep.modelList, ok: true),
          M0ProbeStepResult(step: M0ProbeStep.configRead, ok: true),
          M0ProbeStepResult(step: M0ProbeStep.permissionProfileList, ok: true),
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('probe-test-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

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
    expect(find.text('Account read'), findsOneWidget);
    expect(find.text('Permission profile list'), findsOneWidget);
    expect(find.text('Thread list'), findsOneWidget);
  });

  testWidgets('validates required host fields before probing', (tester) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));

    await _pumpHostsPage(tester, runner);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('probe-test-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('probe-test-button')));
    await tester.pumpAndSettle();

    expect(runner.lastProfile, isNull);
    expect(find.text('Host is required'), findsOneWidget);
    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('validates private key auth before probing', (tester) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));

    await _pumpHostsPage(tester, runner);

    await tester.enterText(find.byKey(const ValueKey('host-field')), 'srv.dev');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'alice',
    );
    await tester.tap(find.text('Private key'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('probe-test-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('probe-test-button')));
    await tester.pumpAndSettle();

    expect(runner.lastProfile, isNull);
    expect(find.text('Private key is required'), findsOneWidget);
    expect(find.text('Password is required'), findsNothing);
  });

  testWidgets('runs a manual M0 probe with private key auth', (tester) async {
    final runner = _FakeProbeRunner(
      report: const M0ProbeReport(
        steps: [M0ProbeStepResult(step: M0ProbeStep.agentStatus, ok: true)],
      ),
    );

    await _pumpHostsPage(tester, runner);

    await tester.enterText(find.byKey(const ValueKey('host-field')), 'srv.dev');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'alice',
    );
    await tester.tap(find.text('Private key'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('private-key-field')),
      '-----BEGIN OPENSSH PRIVATE KEY-----\nkey\n-----END OPENSSH PRIVATE KEY-----',
    );
    await tester.enterText(
      find.byKey(const ValueKey('passphrase-field')),
      'key-passphrase',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('probe-test-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('probe-test-button')));
    await tester.pumpAndSettle();

    expect(runner.lastProfile?.authType, SshAuthType.privateKey);
    expect(runner.lastProfile?.password, isNull);
    expect(runner.lastProfile?.privateKeyPem, contains('OPENSSH'));
    expect(runner.lastProfile?.passphrase, 'key-passphrase');
  });

  testWidgets('saves host profile metadata without requiring password', (
    tester,
  ) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));
    final store = _FakeProfileStore();

    await _pumpHostsPage(tester, runner, profileStore: store);

    await tester.enterText(
      find.byKey(const ValueKey('host-name-field')),
      'Dev',
    );
    await tester.enterText(find.byKey(const ValueKey('host-field')), 'srv.dev');
    await tester.enterText(find.byKey(const ValueKey('port-field')), '2200');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'alice',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agent-command-field')),
      'sadcoder-agent --verbose',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('host-save-profile-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('host-save-profile-button')));
    await tester.pumpAndSettle();

    expect(store.savedProfile?.name, 'Dev');
    expect(store.savedProfile?.host, 'srv.dev');
    expect(store.savedProfile?.port, 2200);
    expect(store.savedProfile?.username, 'alice');
    expect(store.savedProfile?.authType, SshAuthType.password);
    expect(store.savedProfile?.password, isEmpty);
    expect(store.savedProfile?.agentCommand, 'sadcoder-agent --verbose');
    expect(find.text('Profile saved.'), findsOneWidget);
  });

  testWidgets('saves private key auth profile fields', (tester) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));
    final store = _FakeProfileStore();

    await _pumpHostsPage(tester, runner, profileStore: store);

    await tester.enterText(
      find.byKey(const ValueKey('host-name-field')),
      'Dev',
    );
    await tester.enterText(find.byKey(const ValueKey('host-field')), 'srv.dev');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'alice',
    );
    await tester.tap(find.text('Private key'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('private-key-field')),
      'private-key',
    );
    await tester.enterText(
      find.byKey(const ValueKey('passphrase-field')),
      'passphrase',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('host-save-profile-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('host-save-profile-button')));
    await tester.pumpAndSettle();

    expect(store.savedProfile?.authType, SshAuthType.privateKey);
    expect(store.savedProfile?.password, isNull);
    expect(store.savedProfile?.privateKeyPem, 'private-key');
    expect(store.savedProfile?.passphrase, 'passphrase');
    expect(find.text('Profile saved.'), findsOneWidget);
  });

  testWidgets('loads saved host profile metadata into the form', (
    tester,
  ) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));
    final store = _FakeProfileStore(
      initialProfile: const SshProfile(
        id: 'manual',
        name: 'Dev',
        host: 'srv.dev',
        port: 2200,
        username: 'alice',
        password: 'should-not-fill',
        agentCommand: 'sadcoder-agent --verbose',
      ),
    );

    await _pumpHostsPage(tester, runner, profileStore: store);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('host-name-field')))
          .controller
          ?.text,
      'Dev',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('host-field')))
          .controller
          ?.text,
      'srv.dev',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('port-field')))
          .controller
          ?.text,
      '2200',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('username-field')))
          .controller
          ?.text,
      'alice',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('password-field')))
          .controller
          ?.text,
      'should-not-fill',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('agent-command-field')),
          )
          .controller
          ?.text,
      'sadcoder-agent --verbose',
    );
  });

  testWidgets('loads saved private key profile into the form', (tester) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));
    final store = _FakeProfileStore(
      initialProfile: const SshProfile(
        id: 'manual',
        name: 'Dev',
        host: 'srv.dev',
        username: 'alice',
        authType: SshAuthType.privateKey,
        privateKeyPem: 'private-key',
        passphrase: 'passphrase',
      ),
    );

    await _pumpHostsPage(tester, runner, profileStore: store);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('password-field')), findsNothing);
    expect(find.byKey(const ValueKey('private-key-field')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('private-key-field')),
          )
          .controller
          ?.text,
      'private-key',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('passphrase-field')))
          .controller
          ?.text,
      'passphrase',
    );
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
  SshProfileStore? profileStore,
}) {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
        profileStore: profileStore,
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

class _FakeProfileStore implements SshProfileStore {
  _FakeProfileStore({this.initialProfile});

  final SshProfile? initialProfile;
  SshProfile? savedProfile;

  @override
  Future<SshProfile?> loadLastProfile() async => initialProfile;

  @override
  Future<void> saveLastProfile(SshProfile profile) async {
    savedProfile = profile;
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
  AccountSnapshotReader get accountSnapshotReader =>
      const _FakeAccountSnapshotReader();

  @override
  AccountUsageSnapshotReader get accountUsageSnapshotReader =>
      const _FakeAccountUsageSnapshotReader();

  @override
  McpServerStatusReader get mcpServerStatusReader =>
      const _FakeMcpServerStatusReader();

  @override
  ModelListReader get modelListReader => const _FakeModelListReader();

  @override
  PermissionProfileListReader get permissionProfileListReader =>
      const _FakePermissionProfileListReader();

  @override
  SkillListReader get skillListReader => const _FakeSkillListReader();

  @override
  ThreadMutationRunner get threadMutationRunner =>
      const _FakeThreadMutationRunner();

  @override
  ThreadBackgroundTerminalRunner get threadBackgroundTerminalRunner =>
      const _FakeThreadBackgroundTerminalRunner();

  @override
  ThreadGoalRunner get threadGoalRunner => const _FakeThreadGoalRunner();

  @override
  ThreadReviewRunner get threadReviewRunner => const _FakeThreadReviewRunner();

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

class _FakeAccountSnapshotReader implements AccountSnapshotReader {
  const _FakeAccountSnapshotReader();

  @override
  Future<AccountSnapshot> readAccount({bool refreshToken = false}) async {
    return const AccountSnapshot(account: null, requiresOpenaiAuth: false);
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

class _FakeModelListReader implements ModelListReader {
  const _FakeModelListReader();

  @override
  Future<ModelListPage> listModels() async {
    return const ModelListPage(models: []);
  }
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

class _FakeThreadMutationRunner implements ThreadMutationRunner {
  const _FakeThreadMutationRunner();

  @override
  Future<ThreadSummary> forkThread({
    required String threadId,
    String? lastTurnId,
    bool ephemeral = false,
  }) async {
    return ThreadSummary.fromJson({
      'id': 'thr_fork',
      'sessionId': 'sess_1',
      'preview': 'Forked thread',
      'ephemeral': ephemeral,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'forkedFromId': threadId,
    });
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
      goal: ThreadGoal(
        threadId: threadId,
        objective: objective ?? 'Goal',
        status: status ?? 'active',
        tokenBudget: tokenBudget,
        tokensUsed: 0,
        timeUsedSeconds: 0,
        createdAtSeconds: 1,
        updatedAtSeconds: 1,
        raw: const {},
      ),
    );
  }

  @override
  Future<ThreadGoalClearResult> clearGoal({required String threadId}) async {
    return const ThreadGoalClearResult(cleared: false);
  }
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
      turn: TurnSummary.fromJson({
        'id': 'turn_review',
        'status': 'inProgress',
        'items': <Object?>[],
        'itemsView': 'notLoaded',
      }),
    );
  }
}

class _FakeReconnectDelayScheduler implements ReconnectDelayScheduler {
  @override
  Future<void> wait(Duration delay) => Completer<void>().future;
}
