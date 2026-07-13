import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_feedback_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('submits note with confirmed log consent', (tester) async {
    await tester.pumpWidget(const _FeedbackSheetHarness());

    await tester.tap(find.byKey(const ValueKey('open-chat-feedback-sheet')));
    await tester.pumpAndSettle();

    expect(find.text('Send feedback'), findsWidgets);
    expect(find.byKey(const ValueKey('chat-feedback-category')), findsOne);

    await tester.enterText(
      find.byKey(const ValueKey('chat-feedback-note')),
      'The command output was confusing.',
    );
    await tester.tap(find.text('Include server logs'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Send feedback'));
    await tester.pumpAndSettle();

    expect(find.text('Send logs with feedback?'), findsOneWidget);
    await tester.tap(find.text('Send with logs'));
    await tester.pumpAndSettle();

    expect(
      find.text('bug / true / The command output was confusing.'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling log consent keeps the sheet open', (tester) async {
    await tester.pumpWidget(const _FeedbackSheetHarness());

    await tester.tap(find.byKey(const ValueKey('open-chat-feedback-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include server logs'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send feedback'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-feedback-note')), findsOneWidget);
    expect(find.text('No result'), findsOneWidget);
  });
}

class _FeedbackSheetHarness extends StatefulWidget {
  const _FeedbackSheetHarness();

  @override
  State<_FeedbackSheetHarness> createState() => _FeedbackSheetHarnessState();
}

class _FeedbackSheetHarnessState extends State<_FeedbackSheetHarness> {
  ChatFeedbackFormResult? _result;

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
                    key: const ValueKey('open-chat-feedback-sheet'),
                    onPressed: () async {
                      final result =
                          await showModalBottomSheet<ChatFeedbackFormResult>(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => const ChatFeedbackSheet(),
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
                        : '${_result!.category.classification} / '
                              '${_result!.includeLogs} / '
                              '${_result!.note ?? ''}',
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
