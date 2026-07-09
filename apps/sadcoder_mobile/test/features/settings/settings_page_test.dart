import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/features/settings/settings_page.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

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
      find.textContaining('Sandbox mode: workspace-write'),
      findsOneWidget,
    );
    expect(find.text('Config layers loaded: 1'), findsOneWidget);
    expect(
      snapshotController.snapshot?.displayValueFor('model'),
      'gpt-5-codex',
    );
  });
}

Future<void> _pumpSettings(
  WidgetTester tester,
  CodexConfigOverrideController controller, {
  CodexConfigSnapshotController? configSnapshotController,
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
          configOverrideController: controller,
          configSnapshotController: configSnapshotController,
        ),
      ),
    ),
  );
}

class _FakeConfigSnapshotReader implements CodexConfigSnapshotReader {
  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    return CodexConfigSnapshot.fromJson({
      'config': {
        'model': 'gpt-5-codex',
        'model_provider': 'openai',
        'model_reasoning_effort': 'high',
        'approval_policy': {'type': 'on-request'},
        'sandbox_mode': {'type': 'workspace-write'},
      },
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
