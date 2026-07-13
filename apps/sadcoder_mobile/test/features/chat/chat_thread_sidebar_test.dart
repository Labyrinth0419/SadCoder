import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_thread_sidebar.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('thread sidebar owns its scroll surface slot', (tester) async {
    await _pumpSidebar(
      tester,
      const ChatThreadSidebar(overlay: false, child: Text('sidebar child')),
    );

    final sidebar = find.byKey(const ValueKey('chat-session-sidebar'));
    expect(sidebar, findsOneWidget);
    expect(
      find.descendant(of: sidebar, matching: find.text('sidebar child')),
      findsOneWidget,
    );
  });

  testWidgets('workspace header shows summary and advanced action', (
    tester,
  ) async {
    var opened = false;
    await _pumpSidebar(
      tester,
      ChatSidebarWorkspaceHeader(
        workspace: '/repo/project',
        onOpenAdvanced: () => opened = true,
      ),
    );

    expect(
      find.byKey(const ValueKey('chat-sidebar-workspace-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-sidebar-workspace-summary')),
      findsOneWidget,
    );
    expect(find.text('/repo/project'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('chat-sidebar-advanced-controls')),
    );
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('thread list panel shows disconnected state without controller', (
    tester,
  ) async {
    await _pumpSidebar(
      tester,
      ChatThreadListPanel(
        controller: null,
        detailController: null,
        archived: false,
        onArchivedChanged: (_) {},
        onUnarchiveThread: null,
      ),
    );

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Connect to a host to load sessions.'), findsOneWidget);
  });
}

Future<void> _pumpSidebar(WidgetTester tester, Widget child) async {
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
      home: Scaffold(body: SizedBox(width: 320, height: 640, child: child)),
    ),
  );
}
