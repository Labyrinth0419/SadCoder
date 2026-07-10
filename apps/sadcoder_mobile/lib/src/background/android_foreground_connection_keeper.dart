import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_background_channel.dart';
import 'background_connection_policy.dart';

class AndroidForegroundConnectionKeeper implements BackgroundConnectionKeeper {
  const AndroidForegroundConnectionKeeper({
    MethodChannel channel = androidBackgroundConnectionChannel,
    TargetPlatform? platform,
  }) : _channel = channel,
       _platform = platform;

  final MethodChannel _channel;
  final TargetPlatform? _platform;

  TargetPlatform get _currentPlatform => _platform ?? defaultTargetPlatform;

  @override
  Future<BackgroundConnectionRetention> retain(
    BackgroundConnectionContext context,
  ) async {
    if (_currentPlatform != TargetPlatform.android) {
      throw const BackgroundConnectionUnsupportedException(
        'Foreground background connection retention is only supported on Android.',
      );
    }

    await _channel.invokeMethod<void>('retain', {
      'profileId': context.profileId,
      'endpoint': context.endpoint,
      'threadId': context.threadId,
      'turnId': context.turnId,
    });
    return _AndroidForegroundConnectionRetention(_channel);
  }
}

class _AndroidForegroundConnectionRetention
    implements BackgroundConnectionRetention {
  _AndroidForegroundConnectionRetention(this._channel);

  final MethodChannel _channel;
  bool _released = false;

  @override
  Future<void> release() async {
    if (_released) {
      return;
    }
    _released = true;
    await _channel.invokeMethod<void>('release');
  }
}
