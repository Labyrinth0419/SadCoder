import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_side_conversation_panel.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('renders compact side conversation status without thread ids', (
    tester,
  ) async {
    var returned = false;

    await tester.pumpWidget(
      _PanelHarness(
        conversation: const ChatSideConversation(
          parentThreadId: 'thr_parent',
          sideThreadId: 'thr_side',
          slash: '/side',
        ),
        onReturn: () => returned = true,
      ),
    );

    expect(
      find.byKey(const ValueKey('chat-side-conversation-panel')),
      findsOneWidget,
    );
    expect(find.text('Side conversation · /side'), findsOneWidget);
    expect(find.textContaining('thr_parent'), findsNothing);
    expect(find.textContaining('thr_side'), findsNothing);
    expect(find.textContaining('Main thread'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chat-side-return-main')));
    await tester.pump();

    expect(returned, isTrue);
  });

  testWidgets('disables return action when the main thread cannot submit', (
    tester,
  ) async {
    var returned = false;

    await tester.pumpWidget(
      _PanelHarness(
        conversation: const ChatSideConversation(
          parentThreadId: 'thr_parent',
          sideThreadId: 'thr_side',
          slash: '/btw',
        ),
        canReturn: false,
        onReturn: () => returned = true,
      ),
    );

    expect(find.text('Side conversation · /btw'), findsOneWidget);

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('chat-side-return-main')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('chat-side-return-main')));
    await tester.pump();

    expect(returned, isFalse);
  });
}

class _PanelHarness extends StatelessWidget {
  const _PanelHarness({
    required this.conversation,
    required this.onReturn,
    this.canReturn = true,
  });

  final ChatSideConversation conversation;
  final bool canReturn;
  final VoidCallback onReturn;

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
        body: Center(
          child: SizedBox(
            width: 360,
            child: ChatSideConversationPanel(
              conversation: conversation,
              canReturn: canReturn,
              onReturn: onReturn,
            ),
          ),
        ),
      ),
    );
  }
}
