import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/background/background_connection_policy.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/diagnostics/diagnostic_log_export_controller.dart';
import 'package:sadcoder_mobile/src/features/settings/settings_page.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc_diagnostic_log.dart';

void main() {
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

    expect(preferences.keepConnectionDuringActiveTurn, true);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-background-active-turn-keepalive')),
      160,
      scrollable: find.byType(Scrollable).first,
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

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-copy-diagnostic-logs')),
      160,
      scrollable: find.byType(Scrollable).first,
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

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-copy-diagnostic-logs')),
      160,
      scrollable: find.byType(Scrollable).first,
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
          backgroundConnectionPreferences: backgroundConnectionPreferences,
          diagnosticLogExportController: diagnosticLogExportController,
        ),
      ),
    ),
  );
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
