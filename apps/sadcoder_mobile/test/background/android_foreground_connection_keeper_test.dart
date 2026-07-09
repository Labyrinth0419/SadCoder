import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/background/android_foreground_connection_keeper.dart';
import 'package:sadcoder_mobile/src/background/background_connection_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retains and releases through the Android method channel', () async {
    const channel = MethodChannel(
      'com.sadcoder.sadcoder_mobile/background_connection_test',
    );
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    const keeper = AndroidForegroundConnectionKeeper(
      channel: channel,
      platform: TargetPlatform.android,
    );
    final retention = await keeper.retain(
      const BackgroundConnectionContext(
        endpoint: 'tester@example.com:22',
        threadId: 'thr_1',
        turnId: 'turn_1',
      ),
    );
    await retention.release();
    await retention.release();

    expect(calls.map((call) => call.method), ['retain', 'release']);
    expect(calls.first.arguments, {
      'endpoint': 'tester@example.com:22',
      'threadId': 'thr_1',
      'turnId': 'turn_1',
    });
  });

  test('reports unsupported retention on non-Android platforms', () async {
    const channel = MethodChannel(
      'com.sadcoder.sadcoder_mobile/background_connection_noop_test',
    );
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    const keeper = AndroidForegroundConnectionKeeper(
      channel: channel,
      platform: TargetPlatform.iOS,
    );

    await expectLater(
      keeper.retain(const BackgroundConnectionContext(turnId: 'turn_1')),
      throwsA(isA<BackgroundConnectionUnsupportedException>()),
    );

    expect(calls, isEmpty);
  });
}
