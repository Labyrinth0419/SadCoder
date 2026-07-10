import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/diffs/diff_text_block.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('renders large diffs incrementally until expanded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [SadCoderThemeColors.light]),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: DiffTextBlock(
            label: 'modify lib/main.dart',
            text: '@@ -1 +1 @@\n-old\n+new\n context',
            initialLineLimit: 2,
          ),
        ),
      ),
    );

    expect(find.text('modify lib/main.dart'), findsOneWidget);
    expect(find.text('@@ -1 +1 @@'), findsOneWidget);
    expect(find.text('-old'), findsOneWidget);
    expect(find.text('+new'), findsNothing);
    expect(find.text(' context'), findsNothing);
    expect(find.text('Showing 2 of 4 diff lines.'), findsOneWidget);
    expect(find.byKey(const ValueKey('diff-show-full')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('diff-show-full')));
    await tester.pumpAndSettle();

    expect(find.text('+new'), findsOneWidget);
    expect(find.text(' context'), findsOneWidget);
    expect(find.text('Showing 2 of 4 diff lines.'), findsNothing);
    expect(find.byKey(const ValueKey('diff-show-full')), findsNothing);
  });
}
