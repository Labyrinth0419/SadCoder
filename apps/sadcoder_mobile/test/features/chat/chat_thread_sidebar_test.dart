import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_thread_sidebar.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/session/host_session_summary.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

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

  testWidgets('new thread action is visible and routes taps', (tester) async {
    var started = false;
    await _pumpSidebar(
      tester,
      ChatSidebarNewThreadButton(onPressed: () => started = true),
    );

    expect(
      find.byKey(const ValueKey('chat-sidebar-new-thread')),
      findsOneWidget,
    );
    expect(find.text('New chat'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-sidebar-new-thread')));
    await tester.pump();

    expect(started, isTrue);
  });

  testWidgets('new thread action exposes its disabled state', (tester) async {
    await _pumpSidebar(
      tester,
      const ChatSidebarNewThreadButton(onPressed: null),
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('chat-sidebar-new-thread')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('host sessions panel shows per-host thread context', (
    tester,
  ) async {
    final local = _profile(id: 'local', name: 'Local Dev', host: '127.0.0.1');
    final remote = _profile(id: 'remote', name: 'GPU Box', host: '10.0.0.9');
    SshProfile? selected;

    await _pumpSidebar(
      tester,
      ChatHostSessionsPanel(
        hostSessions: [
          HostSessionSummary(
            profile: local,
            status: CodexSessionStatus.connected,
            selectedThreadId: 'thread-local',
            selectedThreadTitle: 'Fix mobile layout',
          ),
          HostSessionSummary(
            profile: remote,
            status: CodexSessionStatus.reconnecting,
            selectedThreadId: 'thread-remote',
            selectedThreadTitle: 'GPU training debug',
          ),
        ],
        selectedProfile: local,
        onProfileSelected: (profile) => selected = profile,
      ),
    );

    expect(
      find.byKey(const ValueKey('chat-sidebar-host-sessions')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-sidebar-host-session-local')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-sidebar-host-session-remote')),
      findsOneWidget,
    );
    expect(find.text('Local Dev'), findsOneWidget);
    expect(find.text('GPU Box'), findsOneWidget);
    expect(find.text('Fix mobile layout'), findsOneWidget);
    expect(find.text('GPU training debug'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Reconnecting'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('chat-sidebar-host-session-remote')),
    );
    await tester.pump();

    expect(selected, same(remote));
  });

  testWidgets('host sessions panel falls back to selected thread id', (
    tester,
  ) async {
    final host = _profile(id: 'host-a', name: 'Build Host', host: 'build.dev');

    await _pumpSidebar(
      tester,
      ChatHostSessionsPanel(
        hostSessions: [
          HostSessionSummary(
            profile: host,
            status: CodexSessionStatus.connected,
            selectedThreadId: 'thread-without-title',
          ),
        ],
        selectedProfile: host,
        onProfileSelected: (_) {},
      ),
    );

    expect(find.text('thread-without-title'), findsOneWidget);
  });

  testWidgets('host sessions panel exposes and routes per-host threads', (
    tester,
  ) async {
    final host = _profile(id: 'host-a', name: 'Build Host', host: 'build.dev');
    SshProfile? selectedProfile;
    String? selectedThreadId;

    await _pumpSidebar(
      tester,
      ChatHostSessionsPanel(
        hostSessions: [
          HostSessionSummary(
            profile: host,
            status: CodexSessionStatus.connected,
            selectedThreadId: 'thread-1',
            threads: [
              _thread(id: 'thread-1', name: 'Release build'),
              _thread(id: 'thread-2', name: 'Fix CI'),
            ],
          ),
        ],
        selectedProfile: host,
        onProfileSelected: (_) {},
        onThreadSelected: (profile, threadId) async {
          selectedProfile = profile;
          selectedThreadId = threadId;
        },
      ),
    );

    expect(
      find.byKey(const ValueKey('chat-sidebar-host-thread-list-host-a')),
      findsOneWidget,
    );
    expect(find.text('Release build'), findsOneWidget);
    expect(find.text('Fix CI'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('chat-sidebar-host-thread-host-a-thread-2')),
    );
    await tester.pump();

    expect(selectedProfile, same(host));
    expect(selectedThreadId, 'thread-2');
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

SshProfile _profile({
  required String id,
  required String name,
  required String host,
}) {
  return SshProfile(id: id, name: name, host: host, username: 'codex');
}

ThreadSummary _thread({required String id, required String name}) {
  return ThreadSummary(
    id: id,
    sessionId: 'session-$id',
    preview: '',
    ephemeral: false,
    status: 'idle',
    cwd: '/repo',
    updatedAtSeconds: 1,
    name: name,
  );
}
