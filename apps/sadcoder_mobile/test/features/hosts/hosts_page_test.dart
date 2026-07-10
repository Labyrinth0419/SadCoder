import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/account_logout_runner.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/agent/agent_status.dart';
import 'package:sadcoder_mobile/src/apps/app_list_reader.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal_runner.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/diffs/git_diff_reader.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/feedback/feedback_upload_runner.dart';
import 'package:sadcoder_mobile/src/files/file_search_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_directory_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_kind.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_reader.dart';
import 'package:sadcoder_mobile/src/features/hosts/hosts_page.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal_runner.dart';
import 'package:sadcoder_mobile/src/hooks/hook_list_reader.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_config_runner.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_oauth_runner.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_reader.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_detail_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_list_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_mutation_runner.dart';
import 'package:sadcoder_mobile/src/probe/m0_probe_coordinator.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc_diagnostic_log.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review_runner.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/reconnect_policy.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/skills/skill_list_reader.dart';
import 'package:sadcoder_mobile/src/ssh/known_host.dart';
import 'package:sadcoder_mobile/src/ssh/known_host_verifier.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_import_file_source.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_mutation_runner.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/turns/turn_runner.dart';
import 'package:sadcoder_mobile/src/turns/turn_text_element.dart';
import 'package:sadcoder_mobile/src/usage/account_usage_snapshot_reader.dart';

void main() {
  testWidgets('runs a manual M0 probe from the host form', (tester) async {
    final runner = _FakeProbeRunner(
      report: const M0ProbeReport(
        agentStatus: _readyStatus,
        steps: _passedProbeSteps,
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
    expect(find.text('TCP connect'), findsOneWidget);
    expect(find.text('Codex version'), findsOneWidget);
    expect(find.text('Account read'), findsOneWidget);
    expect(find.text('Permission profile list'), findsOneWidget);
    expect(find.text('Thread list (limit 1)'), findsOneWidget);
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

  testWidgets('confirms and stores an unknown host key before probing', (
    tester,
  ) async {
    final runner = _HostKeyProbeRunner(
      challenge: _hostKeyChallenge,
      report: const M0ProbeReport(steps: _passedProbeSteps),
    );
    final store = _MemoryKnownHostStore();
    final verifier = KnownHostVerifier(store: store);

    await _pumpHostsPage(tester, runner, knownHostVerifier: verifier);

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
    await tester.pump();

    expect(runner.runCount, 1);
    expect(find.text('Trust this SSH host key?'), findsOneWidget);
    expect(find.textContaining('srv.dev:22'), findsOneWidget);
    expect(find.textContaining('ssh-ed25519'), findsOneWidget);
    expect(find.textContaining('SHA256:first'), findsOneWidget);

    await tester.tap(find.text('Trust and continue'));
    await tester.pumpAndSettle();

    expect(runner.runCount, 2);
    expect(store.entries.single.fingerprintSha256, 'SHA256:first');
    expect(find.text('Probe passed'), findsOneWidget);
  });

  testWidgets('canceling unknown host key confirmation does not probe again', (
    tester,
  ) async {
    final runner = _HostKeyProbeRunner(
      challenge: _hostKeyChallenge,
      report: const M0ProbeReport(steps: []),
    );
    final store = _MemoryKnownHostStore();

    await _pumpHostsPage(
      tester,
      runner,
      knownHostVerifier: KnownHostVerifier(store: store),
    );

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
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(runner.runCount, 1);
    expect(store.entries, isEmpty);
    expect(find.textContaining('Unknown SSH host key'), findsOneWidget);
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
    expect(find.text('Profile saved.', skipOffstage: false), findsOneWidget);
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
    expect(find.text('Profile saved.', skipOffstage: false), findsOneWidget);
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

  testWidgets('imports OpenSSH config profiles from a selected file', (
    tester,
  ) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));
    final store = _FakeProfileStore();
    const config = '''
Host *
  User default-user

Host dev
  HostName dev.example.com
  User alice
  Port 2200
  IdentityFile ~/.ssh/id_ed25519

Host prod
  HostName prod.example.com
''';

    await _pumpHostsPage(
      tester,
      runner,
      profileStore: store,
      importFileSource: const _FakeImportFileSource(config),
    );

    await tester.tap(
      find.byKey(const ValueKey('host-import-ssh-config-button')),
    );
    await tester.pumpAndSettle();

    expect(store.profiles, hasLength(2));
    expect(store.profiles.first.name, 'prod');
    expect(store.profiles.last.name, 'dev');
    expect(store.profiles.last.authType, SshAuthType.privateKey);
    expect(store.profiles.last.privateKeyPem, isNull);
    expect(find.text('dev.example.com:2200'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('2 SSH profiles imported.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('2 SSH profiles imported.', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('host-field')))
          .controller
          ?.text,
      'dev.example.com',
    );
    expect(find.byKey(const ValueKey('private-key-field')), findsOneWidget);
  });

  testWidgets('imports a private key file and saves the current profile', (
    tester,
  ) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));
    final store = _FakeProfileStore();
    const privateKey = '''
-----BEGIN OPENSSH PRIVATE KEY-----
secret-key-material
-----END OPENSSH PRIVATE KEY-----
''';

    await _pumpHostsPage(
      tester,
      runner,
      profileStore: store,
      importFileSource: const _FakeImportFileSource(privateKey),
    );

    await tester.enterText(
      find.byKey(const ValueKey('host-name-field')),
      'Dev',
    );
    await tester.enterText(find.byKey(const ValueKey('host-field')), 'srv.dev');
    await tester.enterText(
      find.byKey(const ValueKey('username-field')),
      'alice',
    );
    await tester.tap(
      find.byKey(const ValueKey('host-import-private-key-button')),
    );
    await tester.pumpAndSettle();

    expect(store.savedProfile?.authType, SshAuthType.privateKey);
    expect(store.savedProfile?.privateKeyPem, contains('secret-key-material'));
    expect(store.savedProfile?.id, 'alice@srv.dev:22');
    expect(
      find.text(
        'Private key imported and profile saved securely.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('private-key-field')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('private-key-field')),
          )
          .controller
          ?.text,
      contains('OPENSSH PRIVATE KEY'),
    );
  });

  testWidgets('groups saved SSH profiles by collapsible host', (tester) async {
    final runner = _FakeProbeRunner(report: const M0ProbeReport(steps: []));
    final store = _FakeProfileStore(
      initialProfiles: const [
        SshProfile(
          id: 'alice@srv.dev:22',
          name: 'Dev Alice',
          host: 'srv.dev',
          username: 'alice',
        ),
        SshProfile(
          id: 'bob@srv.dev:22',
          name: 'Dev Bob',
          host: 'srv.dev',
          username: 'bob',
          authType: SshAuthType.privateKey,
          privateKeyPem: 'bob-key',
        ),
        SshProfile(
          id: 'root@prod.dev:2200',
          name: 'Prod',
          host: 'prod.dev',
          port: 2200,
          username: 'root',
        ),
      ],
    );

    await _pumpHostsPage(tester, runner, profileStore: store);
    await tester.pumpAndSettle();

    expect(find.text('Saved hosts'), findsOneWidget);
    expect(find.text('srv.dev:22'), findsOneWidget);
    expect(find.text('prod.dev:2200'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('saved-host-profile-alice@srv.dev:22')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('saved-host-profile-bob@srv.dev:22')),
      findsOneWidget,
    );
    expect(find.text('Dev Bob'), findsOneWidget);

    await tester.tap(find.text('srv.dev:22'));
    await tester.pumpAndSettle();
    expect(find.text('Dev Bob'), findsNothing);

    await tester.tap(find.text('srv.dev:22'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('saved-host-profile-bob@srv.dev:22')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('host-name-field')))
          .controller
          ?.text,
      'Dev Bob',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('username-field')))
          .controller
          ?.text,
      'bob',
    );
    expect(find.byKey(const ValueKey('private-key-field')), findsOneWidget);
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
  KnownHostVerifier? knownHostVerifier,
  SshImportFileSource importFileSource = const _FakeImportFileSource(null),
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
        knownHostVerifier: knownHostVerifier,
        importFileSource: importFileSource,
      ),
    ),
  );
}

const _hostKeyChallenge = SshHostKeyChallenge(
  host: 'srv.dev',
  port: 22,
  keyType: 'ssh-ed25519',
  fingerprintSha256: 'SHA256:first',
);

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

const _passedProbeSteps = [
  M0ProbeStepResult(step: M0ProbeStep.tcpConnect, ok: true),
  M0ProbeStepResult(step: M0ProbeStep.sshHandshake, ok: true),
  M0ProbeStepResult(step: M0ProbeStep.hostKey, ok: true),
  M0ProbeStepResult(step: M0ProbeStep.auth, ok: true),
  M0ProbeStepResult(step: M0ProbeStep.remoteShell, ok: true),
  M0ProbeStepResult(
    step: M0ProbeStep.codexVersion,
    ok: true,
    detail: 'codex-cli 0.142.5',
  ),
  M0ProbeStepResult(step: M0ProbeStep.agentStatus, ok: true),
  M0ProbeStepResult(step: M0ProbeStep.proxyConnect, ok: true),
  M0ProbeStepResult(step: M0ProbeStep.initialize, ok: true),
  M0ProbeStepResult(step: M0ProbeStep.accountRead, ok: true),
  M0ProbeStepResult(step: M0ProbeStep.modelList, ok: true),
  M0ProbeStepResult(step: M0ProbeStep.configRead, ok: true),
  M0ProbeStepResult(step: M0ProbeStep.permissionProfileList, ok: true),
  M0ProbeStepResult(step: M0ProbeStep.threadList, ok: true),
];

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

class _HostKeyProbeRunner implements M0ProbeRunner {
  _HostKeyProbeRunner({required this.challenge, required this.report});

  final SshHostKeyChallenge challenge;
  final M0ProbeReport report;
  int runCount = 0;

  @override
  Future<M0ProbeReport> run(SshProfile profile) async {
    runCount++;
    if (runCount == 1) {
      throw UnknownHostKeyException(challenge);
    }
    return report;
  }
}

class _MemoryKnownHostStore implements KnownHostStore {
  final entries = <KnownHostEntry>[];

  @override
  Future<KnownHostEntry?> readKnownHost({
    required String host,
    required int port,
    required String keyType,
  }) async {
    final key = knownHostStoreKey(host: host, port: port, keyType: keyType);
    for (final entry in entries) {
      if (knownHostStoreKey(
            host: entry.host,
            port: entry.port,
            keyType: entry.keyType,
          ) ==
          key) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<KnownHostEntry?> readKnownHostForEndpoint({
    required String host,
    required int port,
  }) async {
    final endpointKey = knownHostEndpointKey(host: host, port: port);
    for (final entry in entries) {
      if (knownHostEndpointKey(host: entry.host, port: entry.port) ==
          endpointKey) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<void> saveKnownHost(KnownHostEntry entry) async {
    entries.add(entry);
  }
}

class _FakeImportFileSource implements SshImportFileSource {
  const _FakeImportFileSource(this.text);

  final String? text;

  @override
  Future<String?> pickTextFile({
    required List<String> allowedExtensions,
    required String dialogTitle,
  }) async {
    return text;
  }
}

class _FakeProfileStore implements SshProfileListStore {
  _FakeProfileStore({this.initialProfile, List<SshProfile>? initialProfiles})
    : profiles = [
        if (initialProfiles != null) ...initialProfiles,
        if (initialProfiles == null && initialProfile != null) initialProfile,
      ];

  final SshProfile? initialProfile;
  final List<SshProfile> profiles;
  SshProfile? savedProfile;

  @override
  Future<SshProfile?> loadLastProfile() async {
    if (initialProfile != null) {
      return initialProfile;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  @override
  Future<void> saveLastProfile(SshProfile profile) async {
    savedProfile = profile;
  }

  @override
  Future<List<SshProfile>> loadProfiles() async => List.unmodifiable(profiles);

  @override
  Future<void> saveProfile(SshProfile profile) async {
    savedProfile = profile;
    profiles
      ..removeWhere((existing) => existing.id == profile.id)
      ..insert(0, profile);
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
  AccountLogoutRunner get accountLogoutRunner =>
      const _FakeAccountLogoutRunner();

  @override
  AccountUsageSnapshotReader get accountUsageSnapshotReader =>
      const _FakeAccountUsageSnapshotReader();

  @override
  FeedbackUploadRunner get feedbackUploadRunner =>
      const _FakeFeedbackUploadRunner();

  @override
  GitDiffReader get gitDiffReader => const _FakeGitDiffReader();

  @override
  FileSearchReader get fileSearchReader => const _FakeFileSearchReader();

  @override
  WorkspaceDirectoryReader get workspaceDirectoryReader =>
      const _FakeWorkspaceDirectoryReader();

  @override
  WorkspaceFileReader get workspaceFileReader =>
      const _FakeWorkspaceFileReader();

  @override
  McpServerConfigRunner get mcpServerConfigRunner =>
      const _FakeMcpServerConfigRunner();

  @override
  McpServerOAuthRunner get mcpServerOAuthRunner =>
      const _FakeMcpServerOAuthRunner();

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
  PluginListReader get pluginListReader => const _FakePluginListReader();

  @override
  PluginDetailReader get pluginDetailReader => const _FakePluginDetailReader();

  @override
  PluginMutationRunner get pluginMutationRunner =>
      const _FakePluginMutationRunner();

  @override
  HookListReader get hookListReader => const _FakeHookListReader();

  @override
  AppListReader get appListReader => const _FakeAppListReader();

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
  List<JsonRpcDiagnosticLogEntry> get diagnosticLogs => const [];

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

class _FakeWorkspaceDirectoryReader implements WorkspaceDirectoryReader {
  const _FakeWorkspaceDirectoryReader();

  @override
  Future<WorkspaceDirectoryPage> listDirectory({
    required String root,
    String path = '',
    int limit = 100,
    String? cursor,
    bool includeHidden = false,
  }) async {
    return WorkspaceDirectoryPage(root: root, path: path, entries: const []);
  }
}

class _FakeWorkspaceFileReader implements WorkspaceFileReader {
  const _FakeWorkspaceFileReader();

  @override
  Future<WorkspaceFileStat> statFile({
    required String root,
    required String path,
  }) async {
    return WorkspaceFileStat(
      root: root,
      path: path,
      kind: WorkspaceFileKind.file,
    );
  }

  @override
  Future<WorkspaceFileReadChunk> readFile({
    required String root,
    required String path,
    int offset = 0,
    int limitBytes = 64 * 1024,
    String encoding = 'utf-8',
  }) async {
    return WorkspaceFileReadChunk(
      root: root,
      path: path,
      sizeBytes: 0,
      offset: offset,
      bytesRead: 0,
      nextOffset: null,
      hasMore: false,
      encoding: encoding,
      isBinary: false,
      content: '',
    );
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

class _FakeMcpServerConfigRunner implements McpServerConfigRunner {
  const _FakeMcpServerConfigRunner();

  @override
  Future<void> reloadMcpServers() async {}
}

class _FakeMcpServerOAuthRunner implements McpServerOAuthRunner {
  const _FakeMcpServerOAuthRunner();

  @override
  Future<McpServerOAuthLoginResult> startOAuthLogin({
    required String serverName,
  }) async {
    return McpServerOAuthLoginResult(
      serverName: serverName,
      raw: const <String, Object?>{},
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

class _FakePluginDetailReader implements PluginDetailReader {
  const _FakePluginDetailReader();

  @override
  Future<PluginDetail> readPlugin({
    required String pluginId,
    List<String> cwds = const [],
  }) async {
    return PluginDetail.fromJson(
      pluginId: pluginId,
      json: {
        'plugin': {
          'id': pluginId,
          'name': pluginId,
          'source': {'type': 'remote'},
        },
      },
    );
  }
}

class _FakePluginMutationRunner implements PluginMutationRunner {
  const _FakePluginMutationRunner();

  @override
  Future<PluginMutationResult> installPlugin({
    required String pluginId,
    List<String> cwds = const [],
  }) async {
    return PluginMutationResult(
      operation: PluginMutationOperation.install,
      pluginId: pluginId,
      raw: const <String, Object?>{},
    );
  }

  @override
  Future<PluginMutationResult> uninstallPlugin({
    required String pluginId,
    List<String> cwds = const [],
  }) async {
    return PluginMutationResult(
      operation: PluginMutationOperation.uninstall,
      pluginId: pluginId,
      raw: const <String, Object?>{},
    );
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
  Future<ThreadSummary> duplicateThread({required String threadId}) async {
    return ThreadSummary.fromJson({
      'id': 'thr_duplicate',
      'sessionId': 'sess_1',
      'preview': 'Duplicated thread',
      'ephemeral': false,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'forkedFromId': threadId,
    });
  }

  @override
  Future<ThreadSummary> rewindThread({
    required String threadId,
    required String lastTurnId,
  }) async {
    return ThreadSummary.fromJson({
      'id': 'thr_rewind',
      'sessionId': 'sess_1',
      'preview': 'Rewound thread',
      'ephemeral': false,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'forkedFromId': threadId,
    });
  }

  @override
  Future<ThreadSummary> startSideConversation({
    required String threadId,
  }) async {
    return ThreadSummary.fromJson({
      'id': 'thr_side',
      'sessionId': 'sess_1',
      'preview': 'Side thread',
      'ephemeral': true,
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
