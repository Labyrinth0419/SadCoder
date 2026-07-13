import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_activity_strip.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_timeline_controller.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/turns/turn_controller.dart';

void main() {
  testWidgets('renders active work without protocol identifiers', (
    tester,
  ) async {
    final turnController = TurnController(runnerProvider: () => null);
    final timelineController = ChatTimelineController();
    addTearDown(turnController.dispose);
    addTearDown(timelineController.dispose);

    turnController.trackStartedTurn(
      threadId: 'thr_activity_debug',
      turn: TurnSummary.fromJson({
        'id': 'turn_activity_debug',
        'status': 'inProgress',
        'items': <Object?>[],
        'itemsView': 'notLoaded',
      }),
    );
    timelineController.showThread(
      ThreadSummary.fromJson({
        'id': 'thr_activity_debug',
        'sessionId': 'sess_1',
        'preview': 'Build activity strip',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': [
          {
            'id': 'turn_activity_debug',
            'status': 'inProgress',
            'itemsView': 'full',
            'items': [
              {
                'id': 'cmd_activity',
                'type': 'commandExecution',
                'command': 'flutter test',
                'status': 'running',
              },
            ],
          },
        ],
      }),
    );

    await _pumpActivityStrip(
      tester,
      turnController: turnController,
      timelineController: timelineController,
      statusLineParts: const ['Model: gpt-5-codex'],
    );

    expect(find.byKey(const ValueKey('chat-session-sidebar-toggle')), findsOne);
    expect(find.byKey(const ValueKey('chat-tui-status-mark')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-running-progress')), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Model: gpt-5-codex'), findsOneWidget);
    final detail = tester.widget<Text>(
      find.byKey(const ValueKey('chat-activity-detail')),
    );
    expect(detail.data, contains('Command: flutter test'));
    expect(find.textContaining('thr_activity_debug'), findsNothing);
    expect(find.textContaining('turn_activity_debug'), findsNothing);
  });

  testWidgets('sidebar button invokes the provided callback', (tester) async {
    var toggled = false;

    await _pumpActivityStrip(tester, onToggleSidebar: () => toggled = true);

    await tester.tap(find.byKey(const ValueKey('chat-session-sidebar-toggle')));
    await tester.pump();

    expect(toggled, isTrue);
  });
}

Future<void> _pumpActivityStrip(
  WidgetTester tester, {
  bool sidebarVisible = false,
  VoidCallback? onToggleSidebar,
  TurnController? turnController,
  ChatTimelineController? timelineController,
  List<String> statusLineParts = const [],
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
            width: 520,
            child: ChatActivityStrip(
              sidebarVisible: sidebarVisible,
              onToggleSidebar: onToggleSidebar ?? () {},
              sessionController: null,
              turnController: turnController,
              timelineController: timelineController,
              statusLineParts: statusLineParts,
              connectionControls: const SizedBox(
                key: ValueKey('chat-activity-connection-controls'),
                width: 24,
                height: 24,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
