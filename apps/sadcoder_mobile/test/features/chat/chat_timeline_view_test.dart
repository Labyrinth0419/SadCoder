import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_timeline_view.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('timeline conversation owns header and timeline scroll slots', (
    tester,
  ) async {
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
        home: const Scaffold(
          body: SizedBox(
            width: 420,
            height: 640,
            child: ChatTimelineConversation(
              compact: false,
              timelineController: null,
              onLoadOlderHistory: _noop,
              header: Text('side conversation header'),
              timeline: Text('timeline body'),
            ),
          ),
        ),
      ),
    );

    final mainConversation = find.byKey(
      const ValueKey('chat-main-conversation'),
    );
    expect(mainConversation, findsOneWidget);
    expect(
      find.descendant(
        of: mainConversation,
        matching: find.text('side conversation header'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: mainConversation,
        matching: find.text('timeline body'),
      ),
      findsOneWidget,
    );
  });
}

void _noop() {}
