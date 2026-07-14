import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_realtime_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/realtime/realtime_runner.dart';

void main() {
  testWidgets('starts, appends text, renders deltas, and stops realtime', (
    tester,
  ) async {
    final runner = _FakeRealtimeRunner();
    addTearDown(runner.eventsController.close);
    await tester.pumpWidget(_localizedApp(runner));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Realtime text'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-realtime-start')));
    await tester.pumpAndSettle();
    expect(runner.startCalls, 1);

    runner.eventsController.add(
      const ThreadRealtimeEvent(
        kind: ThreadRealtimeEventKind.started,
        threadId: 'thr_1',
        method: 'thread/realtime/started',
        raw: {},
      ),
    );
    runner.eventsController.add(
      const ThreadRealtimeEvent(
        kind: ThreadRealtimeEventKind.transcriptDelta,
        threadId: 'thr_1',
        method: 'thread/realtime/transcript/delta',
        raw: {},
        role: 'assistant',
        delta: 'hello',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('chat-realtime-message')),
      'next',
    );
    await tester.tap(find.byKey(const ValueKey('chat-realtime-send')));
    await tester.pumpAndSettle();
    expect(runner.appendCalls.single.text, 'next');

    await tester.tap(find.byKey(const ValueKey('chat-realtime-stop')));
    await tester.pumpAndSettle();
    expect(runner.stopCalls, 1);
  });
}

Widget _localizedApp(RealtimeRunner runner) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showChatRealtimeSheet(
              context: context,
              runner: runner,
              threadId: 'thr_1',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

class _FakeRealtimeRunner implements RealtimeRunner {
  final eventsController = StreamController<ThreadRealtimeEvent>.broadcast();
  int startCalls = 0;
  int stopCalls = 0;
  final appendCalls =
      <({String threadId, String text, RealtimeTextRole role})>[];

  @override
  Stream<ThreadRealtimeEvent> get events => eventsController.stream;

  @override
  Future<RealtimeVoiceCatalog> listVoices() async =>
      const RealtimeVoiceCatalog();

  @override
  Future<void> startText({
    required String threadId,
    RealtimeConversationVersion? version,
    String? model,
    String? prompt,
    bool? includeStartupContext,
    bool? clientManagedHandoffs,
    bool? flushTranscriptTailOnSessionEnd,
    bool? codexResponsesAsItems,
    String? codexResponseItemPrefix,
    String? codexResponseHandoffPrefix,
    String? realtimeSessionId,
  }) async {
    startCalls++;
  }

  @override
  Future<void> appendText({
    required String threadId,
    required String text,
    RealtimeTextRole role = RealtimeTextRole.user,
  }) async {
    appendCalls.add((threadId: threadId, text: text, role: role));
  }

  @override
  Future<void> appendAudio({
    required String threadId,
    required RealtimeAudioFrame audio,
  }) async {}

  @override
  Future<void> appendSpeech({
    required String threadId,
    required String text,
  }) async {}

  @override
  Future<void> stop({required String threadId}) async {
    stopCalls++;
  }
}
