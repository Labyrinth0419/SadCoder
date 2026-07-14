import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/realtime/method_channel_realtime_audio_device.dart';
import 'package:sadcoder_mobile/src/realtime/realtime_audio_device.dart';
import 'package:sadcoder_mobile/src/realtime/realtime_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends structured capture and playback method calls', () async {
    final calls = <MethodCall>[];
    final channel = MethodChannel('test/realtime_audio');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final device = MethodChannelRealtimeAudioDevice(
      methodChannel: channel,
      inputChannel: const EventChannel('test/realtime_audio_input'),
    );
    await device.startCapture(
      sampleRate: 24000,
      numChannels: 1,
      samplesPerChannel: 480,
    );
    await device.play(
      const RealtimeAudioFrame(
        data: 'AAE=',
        sampleRate: 24000,
        numChannels: 1,
        samplesPerChannel: 1,
      ),
    );
    await device.stopCapture();
    await device.stopPlayback();

    expect(calls.map((call) => call.method), [
      'startCapture',
      'play',
      'stopCapture',
      'stopPlayback',
    ]);
    expect(calls.first.arguments, {
      'sampleRate': 24000,
      'numChannels': 1,
      'samplesPerChannel': 480,
    });
    final playArguments = calls[1].arguments as Map<Object?, Object?>;
    expect(playArguments['data'], isA<Uint8List>());
    expect(playArguments['sampleRate'], 24000);
    expect(playArguments['numChannels'], 1);
    expect(playArguments['samplesPerChannel'], 1);
  });

  test(
    'rejects invalid playback base64 before invoking the platform',
    () async {
      final channel = MethodChannel('test/realtime_audio_invalid');
      var invoked = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            invoked = true;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final device = MethodChannelRealtimeAudioDevice(
        methodChannel: channel,
        inputChannel: const EventChannel('test/realtime_audio_invalid_input'),
      );

      await expectLater(
        device.play(
          const RealtimeAudioFrame(
            data: 'not base64',
            sampleRate: 24000,
            numChannels: 1,
          ),
        ),
        throwsA(isA<RealtimeAudioDeviceException>()),
      );
      expect(invoked, isFalse);
    },
  );
}
