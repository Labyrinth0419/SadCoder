import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_reasoning_overlay.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_timeline_controller.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  testWidgets('active reasoning floats as markdown without disclosure UI', (
    tester,
  ) async {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);
    controller.ingest(_turnStarted());
    controller.ingest(_reasoningDelta('**Inspecting**\n\n- `lib/main.dart`'));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatReasoningOverlay(
            controller: controller,
            activeTurnId: 'turn_1',
            compact: false,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('chat-reasoning-overlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-reasoning-markdown')),
      findsOneWidget,
    );
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Inspecting'), findsOneWidget);
    expect(find.text('lib/main.dart'), findsOneWidget);
  });

  testWidgets('reasoning is hidden without an active turn', (tester) async {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);
    controller.ingest(_turnStarted());
    controller.ingest(_reasoningDelta('Hidden reasoning'));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatReasoningOverlay(
            controller: null,
            activeTurnId: null,
            compact: false,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chat-reasoning-overlay')), findsNothing);
  });
}

CodexEvent _turnStarted() => CodexEvent.fromNotification({
  'method': 'turn/started',
  'params': {
    'threadId': 'thr_1',
    'turn': {
      'id': 'turn_1',
      'status': 'inProgress',
      'items': <Object?>[],
      'itemsView': 'notLoaded',
    },
  },
});

CodexEvent _reasoningDelta(String delta) => CodexEvent.fromNotification({
  'method': 'item/reasoning/summaryTextDelta',
  'params': {
    'threadId': 'thr_1',
    'turnId': 'turn_1',
    'itemId': 'reason_1',
    'delta': delta,
  },
});
