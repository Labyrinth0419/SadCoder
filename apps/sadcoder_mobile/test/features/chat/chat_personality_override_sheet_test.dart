import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_personality_override_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('returns typed turn personality override', (tester) async {
    final overrideController = CodexConfigOverrideController();
    addTearDown(overrideController.dispose);

    await tester.pumpWidget(
      _PersonalitySheetHarness(overrideController: overrideController),
    );

    await tester.tap(find.byKey(const ValueKey('open-chat-personality-sheet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chat-personality-command-personality')),
      'Be concise and point out risky assumptions.',
    );
    await tester.tap(
      find.byKey(const ValueKey('chat-personality-command-apply')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('turn / Be concise and point out risky assumptions.'),
      findsOneWidget,
    );
  });

  testWidgets('session scope uses existing session personality', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController()
      ..setSessionPersonality('Use Chinese for summaries.');
    addTearDown(overrideController.dispose);

    await tester.pumpWidget(
      _PersonalitySheetHarness(overrideController: overrideController),
    );

    await tester.tap(find.byKey(const ValueKey('open-chat-personality-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('chat-personality-command-personality')),
          )
          .controller
          ?.text,
      'Use Chinese for summaries.',
    );

    await tester.tap(
      find.byKey(const ValueKey('chat-personality-command-apply')),
    );
    await tester.pumpAndSettle();

    expect(find.text('session / Use Chinese for summaries.'), findsOneWidget);
  });
}

class _PersonalitySheetHarness extends StatefulWidget {
  const _PersonalitySheetHarness({required this.overrideController});

  final CodexConfigOverrideController overrideController;

  @override
  State<_PersonalitySheetHarness> createState() =>
      _PersonalitySheetHarnessState();
}

class _PersonalitySheetHarnessState extends State<_PersonalitySheetHarness> {
  ChatPersonalityOverrideResult? _result;

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
                    key: const ValueKey('open-chat-personality-sheet'),
                    onPressed: () async {
                      final result =
                          await showModalBottomSheet<
                            ChatPersonalityOverrideResult
                          >(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => ChatPersonalityOverrideSheet(
                              controller: widget.overrideController,
                            ),
                          );
                      if (mounted) {
                        setState(() => _result = result);
                      }
                    },
                    child: const Text('Open'),
                  ),
                  Text(
                    _result == null
                        ? 'No result'
                        : '${_result!.scope.name} / ${_result!.personality}',
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
