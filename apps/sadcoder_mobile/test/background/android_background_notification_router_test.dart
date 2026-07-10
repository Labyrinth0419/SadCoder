import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/background/android_background_notification_router.dart';
import 'package:sadcoder_mobile/src/background/background_notification_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('routes the pending Android notification and stops routing', () async {
    const channel = MethodChannel(
      'com.sadcoder.sadcoder_mobile/background_notification_router_test',
    );
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'startNotificationRouting') {
        return {
          'profileId': ' remote ',
          'endpoint': 'dev@remote.example.com:22',
          'threadId': 'thr_remote',
          'turnId': 'turn_remote',
        };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final routes = <BackgroundNotificationRoute>[];
    final router = AndroidBackgroundNotificationRouter(
      channel: channel,
      platform: TargetPlatform.android,
    );

    await router.attach(routes.add);
    await router.detach();

    expect(calls.map((call) => call.method), [
      'startNotificationRouting',
      'stopNotificationRouting',
    ]);
    expect(routes, hasLength(1));
    expect(routes.single.profileId, 'remote');
    expect(routes.single.endpoint, 'dev@remote.example.com:22');
    expect(routes.single.threadId, 'thr_remote');
    expect(routes.single.turnId, 'turn_remote');
  });

  test('does not touch the Android channel on other platforms', () async {
    const channel = MethodChannel(
      'com.sadcoder.sadcoder_mobile/background_notification_router_noop_test',
    );
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final router = AndroidBackgroundNotificationRouter(
      channel: channel,
      platform: TargetPlatform.iOS,
    );

    await router.attach((route) {});
    await router.detach();

    expect(calls, isEmpty);
  });
}
