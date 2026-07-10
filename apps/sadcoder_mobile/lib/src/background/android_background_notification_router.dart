import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_background_channel.dart';
import 'background_notification_router.dart';

class AndroidBackgroundNotificationRouter
    implements BackgroundNotificationRouter {
  AndroidBackgroundNotificationRouter({
    MethodChannel channel = androidBackgroundConnectionChannel,
    TargetPlatform? platform,
  }) : _channel = channel,
       _platform = platform;

  final MethodChannel _channel;
  final TargetPlatform? _platform;
  BackgroundNotificationRouteHandler? _handler;

  TargetPlatform get _currentPlatform => _platform ?? defaultTargetPlatform;

  @override
  Future<void> attach(BackgroundNotificationRouteHandler handler) async {
    if (_currentPlatform != TargetPlatform.android) {
      return;
    }
    _handler = handler;
    _channel.setMethodCallHandler(_handleMethodCall);
    final pending = await _channel.invokeMethod<Object?>(
      'startNotificationRouting',
    );
    await _dispatch(pending);
  }

  @override
  Future<void> detach() async {
    if (_currentPlatform != TargetPlatform.android) {
      return;
    }
    _handler = null;
    await _channel.invokeMethod<void>('stopNotificationRouting');
    _channel.setMethodCallHandler(null);
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    if (call.method == 'notificationOpened') {
      await _dispatch(call.arguments);
    }
    return null;
  }

  Future<void> _dispatch(Object? value) async {
    final handler = _handler;
    if (handler == null || value is! Map) {
      return;
    }
    await handler(BackgroundNotificationRoute.fromMap(value));
  }
}
