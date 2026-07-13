import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_timeline_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_timeline_renderer.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

void main() {
  testWidgets('timeline renderer shows empty state', (tester) async {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);

    await _pumpRenderer(tester, controller);

    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('timeline renderer keeps message direction contract', (
    tester,
  ) async {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);
    controller.showThreadItemWindow(
      thread: _thread(),
      items: const [
        ThreadItemSummary(
          id: 'user_1',
          type: 'userMessage',
          text: 'Hello from user',
          output: '',
          turnId: 'turn_1',
        ),
        ThreadItemSummary(
          id: 'agent_1',
          type: 'agentMessage',
          text: 'Hello from Codex',
          output: '',
          turnId: 'turn_1',
        ),
      ],
    );

    await _pumpRenderer(tester, controller);

    final userAlign = tester.widget<Align>(
      find.byKey(const ValueKey('timeline-message-align-user_1')),
    );
    final agentAlign = tester.widget<Align>(
      find.byKey(const ValueKey('timeline-message-align-agent_1')),
    );
    final userWidth = tester.widget<FractionallySizedBox>(
      find.byKey(const ValueKey('timeline-message-width-user_1')),
    );
    final agentWidth = tester.widget<FractionallySizedBox>(
      find.byKey(const ValueKey('timeline-message-width-agent_1')),
    );
    expect(userAlign.alignment, AlignmentDirectional.centerEnd);
    expect(agentAlign.alignment, AlignmentDirectional.centerStart);
    expect(userWidth.widthFactor, 0.92);
    expect(agentWidth.widthFactor, 0.92);
    expect(find.text('Hello from user'), findsOneWidget);
    expect(find.text('Hello from Codex'), findsOneWidget);
  });

  testWidgets('timeline renderer collapses long command output', (
    tester,
  ) async {
    final controller = ChatTimelineController();
    addTearDown(controller.dispose);
    controller.showThreadItemWindow(
      thread: _thread(),
      items: [
        ThreadItemSummary(
          id: 'cmd_1',
          type: 'commandExecution',
          text: '',
          output: List.generate(40, (index) => 'line $index').join('\n'),
          command: 'npm test',
          turnId: 'turn_1',
        ),
      ],
    );

    await _pumpRenderer(tester, controller);

    expect(find.text('npm test'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('timeline-command-output-collapsed-cmd_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('timeline-command-output-expand-cmd_1')),
      findsOneWidget,
    );
  });
}

ThreadSummary _thread() => const ThreadSummary(
  id: 'thr_1',
  sessionId: 'sess_1',
  preview: 'Thread',
  ephemeral: false,
  status: 'active',
  cwd: '/repo',
  updatedAtSeconds: 0,
);

Future<void> _pumpRenderer(
  WidgetTester tester,
  ChatTimelineController controller,
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
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChatTimelinePanel(
            controller: controller,
            showRaw: false,
            onRetryOlderHistory: () {},
          ),
        ),
      ),
    ),
  );
}
