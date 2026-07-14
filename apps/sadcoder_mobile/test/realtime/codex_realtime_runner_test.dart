import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/realtime/codex_realtime_runner.dart';
import 'package:sadcoder_mobile/src/realtime/realtime_runner.dart';

void main() {
  test(
    'uses text websocket wire shape and maps realtime notifications',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return switch (request.method) {
          'thread/realtime/listVoices' => {
            'voices': {
              'v1': ['alloy'],
              'v2': ['marin', 'cedar'],
              'defaultV1': 'alloy',
              'defaultV2': 'marin',
            },
          },
          _ => <String, Object?>{},
        };
      });
      final notifications = StreamController<CodexEvent>.broadcast();
      addTearDown(() async {
        await notifications.close();
        await transport.close();
      });
      final runner = CodexRealtimeRunner(
        client: CodexAppServerClient(transport),
        events: notifications.stream,
      );

      final eventFuture = runner.events.first;
      notifications.add(
        CodexEvent.fromNotification({
          'method': 'thread/realtime/transcript/delta',
          'params': {
            'threadId': 'thr_1',
            'role': 'assistant',
            'delta': 'hello',
          },
        }),
      );
      final event = await eventFuture;
      expect(event.kind, ThreadRealtimeEventKind.transcriptDelta);
      expect(event.threadId, 'thr_1');
      expect(event.role, 'assistant');
      expect(event.delta, 'hello');

      final voices = await runner.listVoices();
      expect(voices.v1, ['alloy']);
      expect(voices.v2, ['marin', 'cedar']);
      expect(voices.defaultV2, 'marin');

      await runner.startText(
        threadId: ' thr_1 ',
        version: RealtimeConversationVersion.v2,
        model: ' realtime-model ',
        prompt: ' say hello ',
        includeStartupContext: false,
        codexResponsesAsItems: true,
      );
      await runner.appendText(
        threadId: 'thr_1',
        text: ' hi ',
        role: RealtimeTextRole.user,
      );
      await runner.appendAudio(
        threadId: 'thr_1',
        audio: const RealtimeAudioFrame(
          data: 'AA==',
          sampleRate: 24000,
          numChannels: 1,
          samplesPerChannel: 10,
        ),
      );
      await runner.appendSpeech(threadId: 'thr_1', text: ' speak this ');
      await runner.stop(threadId: 'thr_1');

      expect(requests.map((request) => request.method), [
        'thread/realtime/listVoices',
        'thread/realtime/start',
        'thread/realtime/appendText',
        'thread/realtime/appendAudio',
        'thread/realtime/appendSpeech',
        'thread/realtime/stop',
      ]);
      expect(requests[1].params, {
        'threadId': 'thr_1',
        'codexResponsesAsItems': true,
        'model': 'realtime-model',
        'outputModality': 'text',
        'includeStartupContext': false,
        'prompt': 'say hello',
        'transport': {'type': 'websocket'},
        'version': 'v2',
      });
      expect(requests[2].params, {
        'threadId': 'thr_1',
        'text': 'hi',
        'role': 'user',
      });
      expect(requests[3].params, {
        'threadId': 'thr_1',
        'audio': {
          'data': 'AA==',
          'sampleRate': 24000,
          'numChannels': 1,
          'samplesPerChannel': 10,
        },
      });
      expect(requests[4].params, {'threadId': 'thr_1', 'text': 'speak this'});
    },
  );

  test('rejects blank realtime identifiers and text', () async {
    final runner = CodexRealtimeRunner(
      client: CodexAppServerClient(MemoryJsonRpcTransport((_) => {})),
      events: const Stream<CodexEvent>.empty(),
    );

    expect(
      () => runner.startText(threadId: ' '),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => runner.appendText(threadId: 'thr_1', text: ' '),
      throwsA(isA<ArgumentError>()),
    );
    expect(() => runner.stop(threadId: ' '), throwsA(isA<ArgumentError>()));
  });
}
