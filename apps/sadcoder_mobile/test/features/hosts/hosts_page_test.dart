import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/agent/agent_status.dart';
import 'package:sadcoder_mobile/src/features/hosts/hosts_page.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/probe/m0_probe_coordinator.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

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
}

Future<void> _pumpHostsPage(WidgetTester tester, M0ProbeRunner runner) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: HostsPage(probeRunner: runner),
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
