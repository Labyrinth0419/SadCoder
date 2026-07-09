import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
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
}

Future<void> _pumpSettings(
  WidgetTester tester,
  CodexConfigOverrideController controller,
) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SettingsPage(configOverrideController: controller)),
    ),
  );
}
