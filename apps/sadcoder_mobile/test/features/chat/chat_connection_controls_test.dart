import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_connection_controls.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/session/host_session_summary.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('shows profile aliases and selects a saved host', (tester) async {
    final local = _profile(id: 'local', name: 'Local Dev', host: '127.0.0.1');
    final remote = _profile(
      id: 'remote',
      name: 'GPU Box',
      host: '10.0.0.9',
      authType: SshAuthType.privateKey,
    );
    SshProfile? selected;

    await _pumpConnectionControls(
      tester,
      profiles: [local, remote],
      selectedProfile: remote,
      hostSessions: [
        HostSessionSummary(
          profile: local,
          status: CodexSessionStatus.reconnecting,
        ),
        HostSessionSummary(
          profile: remote,
          status: CodexSessionStatus.connected,
        ),
      ],
      onProfileSelected: (profile) => selected = profile,
    );

    expect(find.text('GPU Box'), findsOneWidget);
    expect(find.textContaining('10.0.0.9'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chat-host-selector')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-host-option-local')), findsOne);
    expect(find.byKey(const ValueKey('chat-host-option-remote')), findsOne);
    expect(find.byKey(const ValueKey('chat-host-status-local')), findsOne);
    expect(find.byKey(const ValueKey('chat-host-status-remote')), findsOne);

    await tester.tap(find.byKey(const ValueKey('chat-host-option-local')));
    await tester.pumpAndSettle();

    expect(selected, same(local));
  });

  testWidgets('falls back to connection label when no profile is active', (
    tester,
  ) async {
    await _pumpConnectionControls(
      tester,
      profiles: const [],
      selectedProfile: null,
      connectionLabel: 'Disconnected',
    );

    expect(find.text('Disconnected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-host-selector')));
    await tester.pumpAndSettle();

    expect(find.text('No saved SSH profiles.'), findsOneWidget);
  });
}

Future<void> _pumpConnectionControls(
  WidgetTester tester, {
  required List<SshProfile> profiles,
  required SshProfile? selectedProfile,
  SshProfile? connectedProfile,
  List<HostSessionSummary> hostSessions = const [],
  CodexSessionStatus status = CodexSessionStatus.connected,
  String connectionLabel = 'Connected',
  Object? profileLoadError,
  ValueChanged<SshProfile>? onProfileSelected,
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
            width: 360,
            child: ChatConnectionControls(
              profiles: profiles,
              selectedProfile: selectedProfile,
              connectedProfile: connectedProfile,
              hostSessions: hostSessions,
              status: status,
              connectionLabel: connectionLabel,
              profileLoadError: profileLoadError,
              onProfileSelected: onProfileSelected ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

SshProfile _profile({
  required String id,
  required String name,
  required String host,
  SshAuthType authType = SshAuthType.password,
}) {
  return SshProfile(
    id: id,
    name: name,
    host: host,
    username: 'codex',
    authType: authType,
  );
}
