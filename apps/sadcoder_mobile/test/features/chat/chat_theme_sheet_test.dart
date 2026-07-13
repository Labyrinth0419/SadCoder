import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_theme_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('returns selected theme and color palette', (tester) async {
    await tester.pumpWidget(const _ThemeSheetHarness());

    await tester.tap(find.byKey(const ValueKey('open-chat-theme-sheet')));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Color palette'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    final candyPop = find.byKey(const ValueKey('chat-color-palette-candy-pop'));
    await tester.ensureVisible(candyPop);
    await tester.tap(candyPop);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chat-theme-command-apply')));
    await tester.pumpAndSettle();

    expect(find.text('dark / candy-pop'), findsOneWidget);
  });
}

class _ThemeSheetHarness extends StatefulWidget {
  const _ThemeSheetHarness();

  @override
  State<_ThemeSheetHarness> createState() => _ThemeSheetHarnessState();
}

class _ThemeSheetHarnessState extends State<_ThemeSheetHarness> {
  ChatThemeSheetResult? _result;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        body: Builder(
          builder: (context) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    key: const ValueKey('open-chat-theme-sheet'),
                    onPressed: () async {
                      final result =
                          await showModalBottomSheet<ChatThemeSheetResult>(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => const ChatThemeSheet(
                              initialTheme: AppThemePreference.system,
                              initialColorPalette: AppColorPalette.sadcoder,
                            ),
                          );
                      if (mounted) {
                        setState(() => _result = result);
                      }
                    },
                    child: const Text('Open'),
                  ),
                  if (_result != null)
                    Text(
                      '${_result!.theme.commandValue} / '
                      '${_result!.colorPalette.commandValue}',
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
