import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_realtime_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/realtime/realtime_audio_device.dart';
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
    expect(find.text('Realtime'), findsOneWidget);

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

  testWidgets('captures and plays audio in audio mode', (tester) async {
    final runner = _FakeRealtimeRunner();
    final device = _FakeRealtimeAudioDevice();
    addTearDown(runner.eventsController.close);
    addTearDown(device.framesController.close);
    await tester.pumpWidget(_localizedApp(runner, audioDevice: device));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-realtime-start')));
    await tester.pumpAndSettle();
    expect(runner.audioStartCalls, 1);
    expect(device.startCaptureCalls, 1);

    runner.eventsController.add(
      const ThreadRealtimeEvent(
        kind: ThreadRealtimeEventKind.started,
        threadId: 'thr_1',
        method: 'thread/realtime/started',
        raw: {},
      ),
    );
    const input = RealtimeAudioFrame(
      data: 'AA==',
      sampleRate: 24000,
      numChannels: 1,
      samplesPerChannel: 1,
    );
    device.framesController.add(input);
    await tester.pumpAndSettle();
    expect(runner.audioAppendCalls, [input]);

    runner.eventsController.add(
      const ThreadRealtimeEvent(
        kind: ThreadRealtimeEventKind.outputAudioDelta,
        threadId: 'thr_1',
        method: 'thread/realtime/outputAudio/delta',
        raw: {},
        audioFrame: input,
      ),
    );
    await tester.pumpAndSettle();
    expect(device.playedFrames, [input]);

    await tester.tap(find.byKey(const ValueKey('chat-realtime-stop')));
    await tester.pumpAndSettle();
    expect(runner.stopCalls, 1);
    expect(device.stopCaptureCalls, 1);
    expect(device.stopPlaybackCalls, 1);
  });

  testWidgets('shows microphone errors before starting the server session', (
    tester,
  ) async {
    final runner = _FakeRealtimeRunner();
    final device = _FakeRealtimeAudioDevice()
      ..startError = const RealtimeAudioDeviceException(
        code: 'microphone_permission_denied',
        message: 'Microphone permission is required for realtime audio.',
      );
    addTearDown(runner.eventsController.close);
    addTearDown(device.framesController.close);
    await tester.pumpWidget(_localizedApp(runner, audioDevice: device));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-realtime-start')));
    await tester.pumpAndSettle();

    expect(runner.audioStartCalls, 0);
    expect(find.textContaining('microphone_permission_denied'), findsOneWidget);
  });
}

Widget _localizedApp(
  RealtimeRunner runner, {
  RealtimeAudioDevice? audioDevice,
}) {
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
              audioDevice: audioDevice,
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
  int audioStartCalls = 0;
  int stopCalls = 0;
  final audioAppendCalls = <RealtimeAudioFrame>[];
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
  Future<void> startAudio({
    required String threadId,
    RealtimeConversationVersion? version,
    String? voice,
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
    audioStartCalls++;
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
  }) async {
    audioAppendCalls.add(audio);
  }

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

class _FakeRealtimeAudioDevice implements RealtimeAudioDevice {
  final framesController = StreamController<RealtimeAudioFrame>.broadcast();
  final playedFrames = <RealtimeAudioFrame>[];
  int startCaptureCalls = 0;
  int stopCaptureCalls = 0;
  int stopPlaybackCalls = 0;
  Object? startError;

  @override
  Stream<RealtimeAudioFrame> get capturedFrames => framesController.stream;

  @override
  Future<void> startCapture({
    int sampleRate = 24000,
    int numChannels = 1,
    int samplesPerChannel = 480,
  }) async {
    if (startError != null) {
      throw startError!;
    }
    startCaptureCalls++;
  }

  @override
  Future<void> stopCapture() async {
    stopCaptureCalls++;
  }

  @override
  Future<void> play(RealtimeAudioFrame frame) async {
    playedFrames.add(frame);
  }

  @override
  Future<void> stopPlayback() async {
    stopPlaybackCalls++;
  }
}
