import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/background/background_connection_policy.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/diagnostics/diagnostic_log_export_controller.dart';
import 'package:sadcoder_mobile/src/features/settings/settings_page.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/models/model_list_controller.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc_diagnostic_log.dart';

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

    expect(find.textContaining('server default'), findsNWidgets(3));

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
    await tester.tap(find.text('Apply overrides'));
    await tester.pumpAndSettle();

    expect(controller.layers.appDefault.toTurnStartParams(), {
      'model': 'gpt-5-codex',
      'effort': 'high',
      'cwd': '/repo',
    });
    expect(find.textContaining('app default'), findsNWidgets(3));

    await tester.tap(find.text('Clear overrides'));
    await tester.pumpAndSettle();

    expect(controller.layers.appDefault.toTurnStartParams(), isEmpty);
    expect(find.textContaining('server default'), findsNWidgets(3));
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
    expect(find.text('GPT-5 Codex (openai)'), findsOneWidget);
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
          diagnosticLogExportController: diagnosticLogExportController,
        ),
      ),
    ),
  );
}

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
