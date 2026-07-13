import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_advanced_controls_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('renders override controls and raw rpc panel when configured', (
    tester,
  ) async {
    final controller = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(model: 'gpt-5-codex'),
        turn: CodexConfigOverrides(effort: 'high'),
      ),
    );
    addTearDown(controller.dispose);

    await _pumpSheet(
      tester,
      configOverrideController: controller,
      rawRpcSender: ({required method, params}) async => {'ok': true},
    );

    expect(
      find.byKey(const ValueKey('chat-advanced-controls-sheet')),
      findsOneWidget,
    );
    expect(find.text('Advanced controls'), findsOneWidget);
    expect(find.text('Session overrides'), findsOneWidget);
    expect(find.text('Next turn overrides'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-session-overrides-edit')), findsOne);
    expect(find.byKey(const ValueKey('chat-turn-overrides-edit')), findsOne);
    expect(find.byKey(const ValueKey('chat-raw-rpc-panel')), findsOneWidget);
  });

  testWidgets('keeps raw rpc panel without config override controls', (
    tester,
  ) async {
    await _pumpSheet(tester);

    expect(find.byKey(const ValueKey('chat-raw-rpc-panel')), findsOneWidget);
    expect(find.text('Session overrides'), findsNothing);
    expect(find.text('Next turn overrides'), findsNothing);
  });
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  CodexConfigOverrideController? configOverrideController,
  Future<Map<String, Object?>> Function({
    required String method,
    Map<String, Object?>? params,
  })?
  rawRpcSender,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: sadCoderThemeData(
        colorPalette: AppColorPalette.sadcoder,
        brightness: Brightness.light,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatAdvancedControlsSheet(
          configOverrideController: configOverrideController,
          rawRpcSender: rawRpcSender,
          onApplySessionOverrides: (_) async {},
        ),
      ),
    ),
  );
}
