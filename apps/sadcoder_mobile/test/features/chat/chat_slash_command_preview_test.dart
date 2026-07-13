import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_registry.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_slash_command_preview.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('known slash command preview renders command details', (
    tester,
  ) async {
    final result = const SlashCommandRegistry().parseComposerText('/status');

    await _pumpPreview(tester, result: result);

    expect(find.text('/status'), findsOneWidget);
    expect(find.text(result.command!.description), findsOneWidget);
    expect(
      find.byKey(const ValueKey('slash-command-send-as-text')),
      findsOneWidget,
    );
  });

  testWidgets('unknown slash command preview can be marked as text', (
    tester,
  ) async {
    var sendAsText = false;
    final result = const SlashCommandRegistry().parseComposerText('/wat now');

    await _pumpPreview(
      tester,
      result: result,
      onSendAsText: () => sendAsText = true,
    );

    expect(find.text('Unknown command: /wat'), findsOneWidget);
    expect(find.text('Not sent as a prompt'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('slash-command-send-as-text')));
    await tester.pump();
    expect(sendAsText, isTrue);
  });
}

Future<void> _pumpPreview(
  WidgetTester tester, {
  required SlashCommandParseResult result,
  bool sendAsText = false,
  VoidCallback? onSendAsText,
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
        body: Center(
          child: SizedBox(
            width: 420,
            child: ChatSlashCommandPreview(
              result: result,
              sendAsText: sendAsText,
              onSendAsText: onSendAsText ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
}
