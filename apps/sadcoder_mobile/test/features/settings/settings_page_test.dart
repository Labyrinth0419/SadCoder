import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/agent/agent_codex_configure.dart';
import 'package:sadcoder_mobile/src/agent/agent_codex_configure_controller.dart';
import 'package:sadcoder_mobile/src/agent/agent_codex_configure_runner.dart';
import 'package:sadcoder_mobile/src/agent/agent_doctor.dart';
import 'package:sadcoder_mobile/src/agent/agent_doctor_controller.dart';
import 'package:sadcoder_mobile/src/agent/agent_doctor_reader.dart';
import 'package:sadcoder_mobile/src/agent/agent_logs.dart';
import 'package:sadcoder_mobile/src/agent/agent_logs_controller.dart';
import 'package:sadcoder_mobile/src/agent/agent_logs_reader.dart';
import 'package:sadcoder_mobile/src/agent/agent_schema.dart';
import 'package:sadcoder_mobile/src/agent/agent_schema_controller.dart';
import 'package:sadcoder_mobile/src/agent/agent_schema_reader.dart';
import 'package:sadcoder_mobile/src/agent/agent_status.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/background/background_connection_policy.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/diagnostics/diagnostic_log_export_controller.dart';
import 'package:sadcoder_mobile/src/features/settings/settings_page.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/models/model_list_controller.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc_diagnostic_log.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  testWidgets('uses first-level settings sections with one detail group open', (
    tester,
  ) async {
    final controller = CodexConfigOverrideController();
    final appearanceController = AppAppearanceController();
    addTearDown(controller.dispose);
    addTearDown(appearanceController.dispose);

    await _pumpSettings(
      tester,
      controller,
      appearanceController: appearanceController,
    );

    expect(
      find.byKey(const ValueKey('settings-section-permissions')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-section-account')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-section-models')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-section-appearance')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-section-ssh')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-section-diagnostics')),
      findsOneWidget,
    );
    expect(find.text('Server defaults'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-theme-selector')), findsNothing);

    await _openSettingsSection(tester, 'appearance');

    expect(find.text('Server defaults'), findsNothing);
    expect(
      find.byKey(const ValueKey('settings-theme-selector')),
      findsOneWidget,
    );
  });

  testWidgets('uses a two-level settings menu on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = CodexConfigOverrideController();
    final appearanceController = AppAppearanceController();
    addTearDown(controller.dispose);
    addTearDown(appearanceController.dispose);

    await _pumpSettings(
      tester,
      controller,
      appearanceController: appearanceController,
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-section-account')),
      findsOneWidget,
    );
    expect(find.text('Server defaults'), findsNothing);
    expect(find.byKey(const ValueKey('settings-theme-selector')), findsNothing);

    await _openSettingsSection(tester, 'appearance');

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-section-back')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-theme-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-section-account')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('settings-section-back')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-section-account')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-theme-selector')), findsNothing);
  });

  testWidgets('applies and clears app default config overrides', (
    tester,
  ) async {
    final controller = CodexConfigOverrideController();
    addTearDown(controller.dispose);

    await _pumpSettings(tester, controller);

    expect(find.textContaining('Source: server default'), findsNWidgets(7));

    await tester.enterText(
      find.byKey(const ValueKey('settings-model-override')),
      'gpt-5-codex',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-effort-override')),
      'high',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-cwd-override')),
      '/repo',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-personality-override')),
      'concise',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-service-tier-override')),
      'priority',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-approval-policy-override')),
      'on-request',
    );
    await tester.enterText(
      find.byKey(const ValueKey('settings-permission-profile-override')),
      'trusted-workspace',
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -720));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply overrides'));
    await tester.pumpAndSettle();

    expect(controller.layers.appDefault.toTurnStartParams(), {
      'model': 'gpt-5-codex',
      'effort': 'high',
      'cwd': '/repo',
      'personality': 'concise',
      'serviceTier': 'priority',
      'approvalPolicy': 'on-request',
      'permissions': 'trusted-workspace',
    });
    expect(find.textContaining('Source: app default'), findsNWidgets(7));

    await tester.drag(find.byType(ListView).last, const Offset(0, -720));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear overrides'));
    await tester.pumpAndSettle();

    expect(controller.layers.appDefault.toTurnStartParams(), isEmpty);
    expect(find.textContaining('Source: server default'), findsNWidgets(7));
  });

  testWidgets('restores every config override layer to server defaults', (
    tester,
  ) async {
    final controller = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        appDefault: CodexConfigOverrides(model: 'gpt-5'),
        session: CodexConfigOverrides(effort: 'high'),
        turn: CodexConfigOverrides(cwd: '/repo', personality: 'concise'),
      ),
    );
    addTearDown(controller.dispose);

    await _pumpSettings(tester, controller);

    expect(controller.resolved.toTurnStartParams(), {
      'model': 'gpt-5',
      'effort': 'high',
      'cwd': '/repo',
      'personality': 'concise',
    });

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-restore-server-defaults')),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-restore-server-defaults')),
    );
    await tester.pumpAndSettle();

    expect(controller.layers.appDefault.toTurnStartParams(), isEmpty);
    expect(controller.layers.session.toTurnStartParams(), isEmpty);
    expect(controller.layers.turn.toTurnStartParams(), isEmpty);
    expect(controller.resolved.toTurnStartParams(), isEmpty);
    expect(find.textContaining('Source: server default'), findsNWidgets(7));
  });

  testWidgets('refreshes and renders server config snapshot read-only', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    final snapshotController = CodexConfigSnapshotController(
      readerProvider: () => _FakeConfigSnapshotReader(),
    );
    addTearDown(overrideController.dispose);
    addTearDown(snapshotController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      configSnapshotController: snapshotController,
    );

    expect(find.text('Server config snapshot'), findsOneWidget);
    expect(
      find.text('Connect to a host, then refresh server config.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-server-config-refresh')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Model: gpt-5-codex'), findsOneWidget);
    expect(find.textContaining('Model provider: openai'), findsOneWidget);
    expect(find.textContaining('Reasoning effort: high'), findsOneWidget);
    expect(find.textContaining('Approval policy: on-request'), findsOneWidget);
    expect(
      find.textContaining('Permission profile: :workspace'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Sandbox mode: workspace-write'),
      findsOneWidget,
    );
    expect(find.text('Config layers loaded: 1'), findsOneWidget);
    expect(
      snapshotController.snapshot?.displayValueFor('model'),
      'gpt-5-codex',
    );
  });

  testWidgets('flags high-risk server config permissions', (tester) async {
    final overrideController = CodexConfigOverrideController();
    final snapshotController = CodexConfigSnapshotController(
      readerProvider: () => _FakeConfigSnapshotReader(
        config: const {
          'model': 'gpt-5-codex',
          'approval_policy': {'type': 'never'},
          'default_permissions': ':danger-full-access',
          'sandbox_mode': {'type': 'dangerFullAccess'},
        },
      ),
    );
    addTearDown(overrideController.dispose);
    addTearDown(snapshotController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      configSnapshotController: snapshotController,
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-server-config-refresh')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'High risk: these permissions can let Codex run with less review or broader filesystem access.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('refreshes and renders account status read-only', (tester) async {
    final overrideController = CodexConfigOverrideController();
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
    final accountController = AccountSnapshotController(
      readerProvider: () => accountReader,
    );
    addTearDown(accountController.dispose);
    addTearDown(overrideController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      accountSnapshotController: accountController,
    );
    await _openSettingsSection(tester, 'account');

    expect(find.text('Account'), findsWidgets);
    expect(
      find.text('Connect to a host, then refresh account.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('settings-account-refresh')));
    await tester.pumpAndSettle();

    expect(accountReader.refreshTokenValues, [false]);
    expect(
      find.text('Signed in: ChatGPT / user@example.com / pro'),
      findsOneWidget,
    );
    expect(find.text('OpenAI auth required'), findsOneWidget);
  });

  testWidgets('refreshes and renders model list read-only', (tester) async {
    final overrideController = CodexConfigOverrideController();
    final modelReader = _RecordingModelListReader(
      page: const ModelListPage(
        models: [
          CodexModelSummary(
            id: 'gpt-5-codex',
            name: 'GPT-5 Codex',
            provider: 'openai',
            isDefault: true,
          ),
          CodexModelSummary(id: 'gpt-5'),
        ],
      ),
    );
    final modelController = ModelListController(
      readerProvider: () => modelReader,
    );
    addTearDown(modelController.dispose);
    addTearDown(overrideController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      modelListController: modelController,
    );
    await _openSettingsSection(tester, 'models');

    expect(find.text('Model list'), findsOneWidget);
    expect(
      find.text('Connect to a host, then refresh model list.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('settings-model-list-refresh')));
    await tester.pumpAndSettle();

    expect(modelReader.calls, 1);
    expect(find.text('Available models: 2'), findsOneWidget);
    expect(find.text('GPT-5 Codex (openai) (default)'), findsOneWidget);
    expect(find.text('gpt-5'), findsOneWidget);
  });

  testWidgets('updates app theme preference from settings', (tester) async {
    final overrideController = CodexConfigOverrideController();
    final appearanceController = AppAppearanceController(
      theme: AppThemePreference.light,
    );
    addTearDown(overrideController.dispose);
    addTearDown(appearanceController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      appearanceController: appearanceController,
    );
    await _openSettingsSection(tester, 'appearance');

    expect(appearanceController.theme, AppThemePreference.light);
    expect(
      find.byKey(const ValueKey('settings-theme-selector')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-theme-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    expect(appearanceController.theme, AppThemePreference.dark);
  });

  testWidgets('updates app color palette from settings', (tester) async {
    final overrideController = CodexConfigOverrideController();
    final appearanceController = AppAppearanceController();
    addTearDown(overrideController.dispose);
    addTearDown(appearanceController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      appearanceController: appearanceController,
    );
    await _openSettingsSection(tester, 'appearance');

    expect(appearanceController.colorPalette, AppColorPalette.sadcoder);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-color-palette-candy')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-color-palette-candy')),
    );
    await tester.pumpAndSettle();

    expect(appearanceController.colorPalette, AppColorPalette.candy);
  });

  testWidgets('updates app font size from settings', (tester) async {
    final overrideController = CodexConfigOverrideController();
    final appearanceController = AppAppearanceController();
    addTearDown(overrideController.dispose);
    addTearDown(appearanceController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      appearanceController: appearanceController,
    );
    await _openSettingsSection(tester, 'appearance');

    expect(appearanceController.fontSize, AppFontSizePreference.medium);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-font-size-extra-large')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-font-size-extra-large')),
    );
    await tester.pumpAndSettle();

    expect(appearanceController.fontSize, AppFontSizePreference.extraLarge);
  });

  testWidgets('toggles unavailable slash command display from settings', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    final appearanceController = AppAppearanceController();
    addTearDown(overrideController.dispose);
    addTearDown(appearanceController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      appearanceController: appearanceController,
    );
    await _openSettingsSection(tester, 'appearance');

    expect(appearanceController.showUnavailableSlashCommands, false);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-appearance-advanced')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-appearance-advanced')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-show-unavailable-slash-commands')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-show-unavailable-slash-commands')),
    );
    await tester.pumpAndSettle();

    expect(appearanceController.showUnavailableSlashCommands, true);
  });

  testWidgets('toggles active-turn background connection retention', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    final preferences = BackgroundConnectionPreferences();
    addTearDown(overrideController.dispose);
    addTearDown(preferences.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      backgroundConnectionPreferences: preferences,
    );
    await _openSettingsSection(tester, 'ssh');

    expect(preferences.keepConnectionDuringActiveTurn, true);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-background-active-turn-keepalive')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-background-active-turn-keepalive')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-background-active-turn-keepalive')),
    );
    await tester.pumpAndSettle();

    expect(preferences.keepConnectionDuringActiveTurn, false);
  });

  testWidgets('refreshes and renders agent doctor diagnostics read-only', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    final doctorReader = _RecordingAgentDoctorReader(
      result: const AgentDoctorResult(
        configPath: '/home/tester/.config/sadcoder/agent.json',
        codex: AgentCodexCommandDiagnostic(
          program: '/home/tester/.nvm/versions/node/v24/bin/codex',
          args: [],
          pathPrepend: ['/home/tester/.nvm/versions/node/v24/bin'],
          source: 'config',
          available: true,
          version: 'codex-cli 0.143.0',
        ),
        status: AgentStatus(
          agentVersion: '0.2.0',
          platformOs: 'linux',
          platformArch: 'x86_64',
          codexPath: '/home/tester/.nvm/versions/node/v24/bin/codex',
          codexAvailable: true,
          codexVersion: 'codex-cli 0.143.0',
          backendKind: BackendKind.sadcoderAgentService,
          backendState: BackendState.ready,
          backendDetail: 'SadCoder service is listening',
          reconnectCache: AgentReconnectCacheStatus(
            statePath: '/home/tester/.sadcoder/agent-state.json',
            pendingApprovals: 2,
            recentEvents: 7,
            threads: 4,
            deliveredCursor: 'event-7',
          ),
        ),
      ),
    );
    final doctorController = AgentDoctorController(
      readerProvider: () => doctorReader,
      profileProvider: () => _profile,
    );
    addTearDown(overrideController.dispose);
    addTearDown(doctorController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      agentDoctorController: doctorController,
    );
    await _openSettingsSection(tester, 'diagnostics');

    expect(find.text('Agent doctor'), findsOneWidget);
    expect(
      find.text('Connect to a host, then run agent doctor.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-agent-doctor-refresh')),
    );
    await tester.pumpAndSettle();

    expect(doctorReader.profiles, [_profile]);
    expect(find.text('Agent version: 0.2.0'), findsOneWidget);
    expect(find.text('Codex version: codex-cli 0.143.0'), findsOneWidget);
    expect(
      find.text('Codex program: /home/tester/.nvm/versions/node/v24/bin/codex'),
      findsOneWidget,
    );
    expect(find.text('Codex source: config'), findsOneWidget);
    expect(
      find.text('Agent config: /home/tester/.config/sadcoder/agent.json'),
      findsOneWidget,
    );
    expect(find.text('Backend: agent service / ready'), findsOneWidget);
    expect(
      find.text('Backend detail: SadCoder service is listening'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Reconnect cache: 2 pending approvals, 7 recent events, 4 threads',
      ),
      findsOneWidget,
    );
    expect(find.text('Delivered cursor: event-7'), findsOneWidget);
    expect(
      find.text('State path: /home/tester/.sadcoder/agent-state.json'),
      findsOneWidget,
    );
  });

  testWidgets('renders agent doctor Codex failure diagnostics', (tester) async {
    final overrideController = CodexConfigOverrideController();
    final doctorReader = _RecordingAgentDoctorReader(
      result: const AgentDoctorResult(
        configPath: '/home/tester/.config/sadcoder/agent.json',
        codex: AgentCodexCommandDiagnostic(
          program: '/home/tester/.nvm/versions/node/v24/bin/codex',
          args: [],
          pathPrepend: ['/home/tester/.nvm/versions/node/v24/bin'],
          source: 'config',
          available: false,
          failure: AgentCodexFailure(
            kind: 'runtime-not-found',
            detail: 'node 24 was not found',
          ),
        ),
        status: AgentStatus(
          agentVersion: '0.2.0',
          platformOs: 'linux',
          platformArch: 'x86_64',
          codexPath: '/home/tester/.nvm/versions/node/v24/bin/codex',
          codexAvailable: false,
          codexFailure: AgentCodexFailure(
            kind: 'non-zero-exit',
            detail: 'SyntaxError: Unexpected token',
          ),
          backendKind: BackendKind.sadcoderAgentService,
          backendState: BackendState.unavailable,
          backendDetail: 'service socket is not ready',
          reconnectCache: AgentReconnectCacheStatus(
            loadError: 'state file is corrupt',
          ),
        ),
      ),
    );
    final doctorController = AgentDoctorController(
      readerProvider: () => doctorReader,
      profileProvider: () => _profile,
    );
    addTearDown(overrideController.dispose);
    addTearDown(doctorController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      agentDoctorController: doctorController,
    );
    await _openSettingsSection(tester, 'diagnostics');

    await tester.tap(
      find.byKey(const ValueKey('settings-agent-doctor-refresh')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Codex command failure: runtime-not-found: node 24 was not found',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Codex status failure: non-zero-exit: SyntaxError: Unexpected token',
      ),
      findsOneWidget,
    );
    expect(find.text('Backend: agent service / unavailable'), findsOneWidget);
    expect(
      find.text('Backend detail: service socket is not ready'),
      findsOneWidget,
    );
    expect(
      find.text('Reconnect cache load error: state file is corrupt'),
      findsOneWidget,
    );
  });

  testWidgets('configures persistent agent Codex launch settings', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    final doctorReader = _RecordingAgentDoctorReader(
      result: const AgentDoctorResult(
        configPath: '/home/tester/.config/sadcoder/agent.json',
        codex: AgentCodexCommandDiagnostic(
          program: '/home/tester/.nvm/versions/node/v24/bin/codex',
          args: ['--profile', 'mobile'],
          pathPrepend: ['/home/tester/.nvm/versions/node/v24/bin'],
          source: 'config',
          available: true,
          version: 'codex-cli 0.143.0',
        ),
        status: AgentStatus(
          agentVersion: '0.2.0',
          platformOs: 'linux',
          platformArch: 'x86_64',
          codexPath: '/home/tester/.nvm/versions/node/v24/bin/codex',
          codexAvailable: true,
          codexVersion: 'codex-cli 0.143.0',
          backendKind: BackendKind.sadcoderAgentService,
          backendState: BackendState.ready,
        ),
      ),
    );
    final doctorController = AgentDoctorController(
      readerProvider: () => doctorReader,
      profileProvider: () => _profile,
    );
    final configureRunner = _RecordingAgentCodexConfigureRunner(
      result: const AgentCodexConfigureResult(
        configPath: '/home/tester/.config/sadcoder/agent.json',
        codex: AgentCodexCommandDiagnostic(
          program: '/home/tester/.nvm/versions/node/v24/bin/codex',
          args: ['--profile', 'mobile'],
          pathPrepend: ['/home/tester/.nvm/versions/node/v24/bin'],
          source: 'config',
          available: true,
          version: 'codex-cli 0.143.0',
        ),
      ),
    );
    final configureController = AgentCodexConfigureController(
      runnerProvider: () => configureRunner,
      profileProvider: () => _profile,
    );
    addTearDown(overrideController.dispose);
    addTearDown(doctorController.dispose);
    addTearDown(configureController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      agentDoctorController: doctorController,
      agentCodexConfigureController: configureController,
    );
    await _openSettingsSection(tester, 'diagnostics');

    expect(
      find.byKey(const ValueKey('settings-agent-codex-configure-fill-doctor')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-agent-doctor-refresh')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-agent-codex-configure-fill-doctor')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-agent-codex-configure-fill-doctor')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('settings-agent-codex-program')),
          )
          .controller
          ?.text,
      '/home/tester/.nvm/versions/node/v24/bin/codex',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('settings-agent-codex-args')),
          )
          .controller
          ?.text,
      '--profile\nmobile',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('settings-agent-codex-path-prepend')),
          )
          .controller
          ?.text,
      '/home/tester/.nvm/versions/node/v24/bin',
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-agent-codex-configure-save')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-agent-codex-configure-save')),
    );
    await tester.pumpAndSettle();

    expect(configureRunner.profiles, [_profile]);
    expect(
      configureRunner.requests.single.program,
      '/home/tester/.nvm/versions/node/v24/bin/codex',
    );
    expect(configureRunner.requests.single.args, ['--profile', 'mobile']);
    expect(configureRunner.requests.single.pathPrepend, [
      '/home/tester/.nvm/versions/node/v24/bin',
    ]);
    expect(doctorReader.profiles, [_profile, _profile]);
    expect(
      find.text('Agent config: /home/tester/.config/sadcoder/agent.json'),
      findsWidgets,
    );
    expect(find.text('Codex version: codex-cli 0.143.0'), findsWidgets);
  });

  testWidgets('refreshes and renders agent service logs read-only', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    final logsReader = _RecordingAgentLogsReader(
      result: const AgentLogsResult(
        schemaVersion: 1,
        maxTailBytes: 262144,
        logs: [
          AgentLogEntry(
            name: 'app-server.stderr',
            path: '/home/tester/.sadcoder/app-server.stderr.log',
            exists: true,
            sizeBytes: 4096,
            tailBytes: 128,
            truncated: true,
            content: 'first line\nlast line\n',
          ),
        ],
      ),
    );
    final logsController = AgentLogsController(
      readerProvider: () => logsReader,
      profileProvider: () => _profile,
      tailBytes: 8192,
    );
    addTearDown(overrideController.dispose);
    addTearDown(logsController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      agentLogsController: logsController,
    );
    await _openSettingsSection(tester, 'diagnostics');

    expect(find.text('Agent service logs'), findsOneWidget);
    expect(find.text('Connect to a host, then refresh logs.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-agent-logs-refresh')));
    await tester.pumpAndSettle();

    expect(logsReader.profiles, [_profile]);
    expect(logsReader.tailBytesValues, [8192]);
    expect(find.text('app-server.stderr'), findsOneWidget);
    expect(
      find.text('Log path: /home/tester/.sadcoder/app-server.stderr.log'),
      findsOneWidget,
    );
    expect(
      find.text('Showing the newest portion of this log.'),
      findsOneWidget,
    );
    expect(find.textContaining('last line'), findsOneWidget);
  });

  testWidgets('refreshes and renders app-server schema diagnostics read-only', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    final schemaReader = _RecordingAgentSchemaReader(
      result: const AgentSchemaResult(
        schemaVersion: 1,
        source: 'codex app-server generate-json-schema',
        experimental: false,
        generated: false,
        cacheDir: '/home/tester/.sadcoder/app-server-schema/json',
        metadataPath:
            '/home/tester/.sadcoder/app-server-schema/json/sadcoder-schema-cache.json',
        codexVersion: 'codex-cli 1.2.3',
        generatedAtUnixMs: 9,
        bundlePath:
            '/home/tester/.sadcoder/app-server-schema/json/codex_app_server_protocol.schemas.json',
        fileCount: 2,
        totalBytes: 128,
        digest: '0123456789abcdef',
        files: [
          AgentSchemaFile(
            path: 'codex_app_server_protocol.schemas.json',
            sizeBytes: 64,
            digest: 'abcdef0123456789',
          ),
          AgentSchemaFile(
            path: 'v2/ClientRequest.json',
            sizeBytes: 64,
            digest: 'fedcba9876543210',
          ),
        ],
      ),
    );
    final schemaController = AgentSchemaController(
      readerProvider: () => schemaReader,
      profileProvider: () => _profile,
    );
    addTearDown(overrideController.dispose);
    addTearDown(schemaController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      agentSchemaController: schemaController,
    );
    await _openSettingsSection(tester, 'diagnostics');

    expect(find.text('App-server schema'), findsOneWidget);
    expect(
      find.text('Connect to a host, then refresh schema diagnostics.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-agent-schema-refresh')),
    );
    await tester.pumpAndSettle();

    expect(schemaReader.profiles, [_profile]);
    expect(schemaReader.refreshValues, [false]);
    expect(schemaReader.experimentalValues, [false]);
    expect(find.text('Read existing schema cache.'), findsOneWidget);
    expect(find.text('Schema mode: Stable'), findsOneWidget);
    expect(find.text('Codex version: codex-cli 1.2.3'), findsOneWidget);
    expect(find.text('Schema files: 2 files, 128 B'), findsOneWidget);
    expect(find.text('Schema digest: 0123456789abcdef'), findsOneWidget);
    expect(
      find.text('codex_app_server_protocol.schemas.json (64 B)'),
      findsOneWidget,
    );

    await tester.tap(find.text('Experimental'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-agent-schema-regenerate')),
    );
    await tester.pumpAndSettle();

    expect(schemaReader.refreshValues, [false, true]);
    expect(schemaReader.experimentalValues, [false, true]);
  });

  testWidgets('confirms before copying diagnostic logs', (tester) async {
    final overrideController = CodexConfigOverrideController();
    final copied = <String>[];
    final exportController = DiagnosticLogExportController(
      entriesProvider: () => [
        JsonRpcDiagnosticLogEntry(
          direction: JsonRpcDiagnosticLogDirection.outgoing,
          capturedAt: DateTime.utc(2026, 1, 2, 3),
          redactedJson: const {
            'jsonrpc': '2.0',
            'method': 'account/login',
            'params': {'password': '[REDACTED]', 'cwd': '/repo'},
          },
        ),
      ],
      clipboardSetter: (text) async => copied.add(text),
    );
    addTearDown(overrideController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      diagnosticLogExportController: exportController,
    );
    await _openSettingsSection(tester, 'diagnostics');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-copy-diagnostic-logs')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-copy-diagnostic-logs')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Copy diagnostic logs?'), findsOneWidget);
    expect(
      find.textContaining('exported logs may still include paths'),
      findsOneWidget,
    );
    expect(copied, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Copy logs').last);
    await tester.pumpAndSettle();

    expect(copied.single, contains('"direction":"outgoing"'));
    expect(copied.single, contains('"password":"[REDACTED]"'));
    expect(find.text('Copied 1 diagnostic log entries.'), findsOneWidget);
  });

  testWidgets('confirms before exporting diagnostic logs', (tester) async {
    final overrideController = CodexConfigOverrideController();
    final saved = <({String fileName, String text, String dialogTitle})>[];
    final exportController = DiagnosticLogExportController(
      entriesProvider: () => [
        JsonRpcDiagnosticLogEntry(
          direction: JsonRpcDiagnosticLogDirection.outgoing,
          capturedAt: DateTime.utc(2026, 1, 2, 3),
          redactedJson: const {
            'jsonrpc': '2.0',
            'method': 'turn/start',
            'params': {'apiKey': '[REDACTED]', 'cwd': '/repo'},
          },
        ),
      ],
      fileSaver:
          ({required fileName, required text, required dialogTitle}) async {
            saved.add((
              fileName: fileName,
              text: text,
              dialogTitle: dialogTitle,
            ));
            return '/tmp/$fileName';
          },
      clock: () => DateTime.utc(2026, 7, 10, 11, 12, 13),
    );
    addTearDown(overrideController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      diagnosticLogExportController: exportController,
    );
    await _openSettingsSection(tester, 'diagnostics');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-export-diagnostic-logs')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-export-diagnostic-logs')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Export diagnostic logs?'), findsOneWidget);
    expect(
      find.textContaining('exported logs may still include paths'),
      findsOneWidget,
    );
    expect(saved, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Export logs').last);
    await tester.pumpAndSettle();

    expect(
      saved.single.fileName,
      'sadcoder-diagnostic-logs-20260710-111213.jsonl',
    );
    expect(saved.single.dialogTitle, 'Export logs');
    expect(saved.single.text, contains('"direction":"outgoing"'));
    expect(saved.single.text, contains('"apiKey":"[REDACTED]"'));
    expect(find.text('Exported 1 diagnostic log entries.'), findsOneWidget);
  });

  testWidgets('reports empty diagnostic logs without opening confirmation', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    final exportController = DiagnosticLogExportController(
      entriesProvider: () => const [],
      clipboardSetter: (_) async => fail('clipboard should not be written'),
    );
    addTearDown(overrideController.dispose);

    await _pumpSettings(
      tester,
      overrideController,
      diagnosticLogExportController: exportController,
    );
    await _openSettingsSection(tester, 'diagnostics');

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-copy-diagnostic-logs')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-copy-diagnostic-logs')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No diagnostic logs captured yet.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester,
  CodexConfigOverrideController controller, {
  AppAppearanceController? appearanceController,
  CodexConfigSnapshotController? configSnapshotController,
  AccountSnapshotController? accountSnapshotController,
  ModelListController? modelListController,
  BackgroundConnectionPreferences? backgroundConnectionPreferences,
  AgentDoctorController? agentDoctorController,
  AgentCodexConfigureController? agentCodexConfigureController,
  AgentLogsController? agentLogsController,
  AgentSchemaController? agentSchemaController,
  DiagnosticLogExportController? diagnosticLogExportController,
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
        body: SettingsPage(
          appearanceController: appearanceController,
          configOverrideController: controller,
          configSnapshotController: configSnapshotController,
          accountSnapshotController: accountSnapshotController,
          modelListController: modelListController,
          backgroundConnectionPreferences: backgroundConnectionPreferences,
          agentDoctorController: agentDoctorController,
          agentCodexConfigureController: agentCodexConfigureController,
          agentLogsController: agentLogsController,
          agentSchemaController: agentSchemaController,
          diagnosticLogExportController: diagnosticLogExportController,
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

Future<void> _openSettingsSection(WidgetTester tester, String section) async {
  final sectionFinder = find.byKey(ValueKey('settings-section-$section'));
  await tester.ensureVisible(sectionFinder);
  await tester.pumpAndSettle();
  await tester.tap(sectionFinder);
  await tester.pumpAndSettle();
}

class _FakeConfigSnapshotReader implements CodexConfigSnapshotReader {
  const _FakeConfigSnapshotReader({this.config = _defaultConfig});

  final Map<String, Object?> config;

  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    return CodexConfigSnapshot.fromJson({
      'config': config,
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
    });
  }
}

const _defaultConfig = {
  'model': 'gpt-5-codex',
  'model_provider': 'openai',
  'model_reasoning_effort': 'high',
  'approval_policy': {'type': 'on-request'},
  'default_permissions': ':workspace',
  'sandbox_mode': {'type': 'workspace-write'},
};

class _RecordingAccountSnapshotReader implements AccountSnapshotReader {
  _RecordingAccountSnapshotReader({required this.snapshot});

  final AccountSnapshot snapshot;
  final List<bool> refreshTokenValues = [];

  @override
  Future<AccountSnapshot> readAccount({bool refreshToken = false}) async {
    refreshTokenValues.add(refreshToken);
    return snapshot;
  }
}

class _RecordingModelListReader implements ModelListReader {
  _RecordingModelListReader({required this.page});

  final ModelListPage page;
  int calls = 0;

  @override
  Future<ModelListPage> listModels({
    String? cursor,
    int? limit,
    bool includeHidden = false,
  }) async {
    calls++;
    return page;
  }
}

class _RecordingAgentDoctorReader implements AgentDoctorReader {
  _RecordingAgentDoctorReader({required this.result});

  final AgentDoctorResult result;
  final List<SshProfile> profiles = [];

  @override
  Future<AgentDoctorResult> readDoctor(SshProfile profile) async {
    profiles.add(profile);
    return result;
  }
}

class _RecordingAgentLogsReader implements AgentLogsReader {
  _RecordingAgentLogsReader({required this.result});

  final AgentLogsResult result;
  final List<SshProfile> profiles = [];
  final List<int?> tailBytesValues = [];

  @override
  Future<AgentLogsResult> readLogs(SshProfile profile, {int? tailBytes}) async {
    profiles.add(profile);
    tailBytesValues.add(tailBytes);
    return result;
  }
}

class _RecordingAgentSchemaReader implements AgentSchemaReader {
  _RecordingAgentSchemaReader({required this.result});

  final AgentSchemaResult result;
  final List<SshProfile> profiles = [];
  final List<bool> refreshValues = [];
  final List<bool> experimentalValues = [];

  @override
  Future<AgentSchemaResult> readSchema(
    SshProfile profile, {
    bool refresh = false,
    bool experimental = false,
  }) async {
    profiles.add(profile);
    refreshValues.add(refresh);
    experimentalValues.add(experimental);
    return result;
  }
}

class _RecordingAgentCodexConfigureRunner implements AgentCodexConfigureRunner {
  _RecordingAgentCodexConfigureRunner({required this.result});

  final AgentCodexConfigureResult result;
  final List<SshProfile> profiles = [];
  final List<AgentCodexConfigureRequest> requests = [];

  @override
  Future<AgentCodexConfigureResult> configureCodex(
    SshProfile profile,
    AgentCodexConfigureRequest request,
  ) async {
    profiles.add(profile);
    requests.add(request);
    return result;
  }
}
