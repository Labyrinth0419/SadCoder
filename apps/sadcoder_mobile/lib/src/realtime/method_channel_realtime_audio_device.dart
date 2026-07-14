import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

import 'realtime_audio_device.dart';
import 'realtime_runner.dart';

const MethodChannel realtimeAudioMethodChannel = MethodChannel(
  'com.sadcoder.sadcoder_mobile/realtime_audio',
);
const EventChannel realtimeAudioInputChannel = EventChannel(
  'com.sadcoder.sadcoder_mobile/realtime_audio_input',
);

class MethodChannelRealtimeAudioDevice implements RealtimeAudioDevice {
  MethodChannelRealtimeAudioDevice({
    MethodChannel methodChannel = realtimeAudioMethodChannel,
    EventChannel inputChannel = realtimeAudioInputChannel,
  }) : _methodChannel = methodChannel,
       _capturedFrames = inputChannel.receiveBroadcastStream().map(
         _decodeCapturedFrame,
       );

  final MethodChannel _methodChannel;
  final Stream<RealtimeAudioFrame> _capturedFrames;

  @override
  Stream<RealtimeAudioFrame> get capturedFrames => _capturedFrames;

  @override
  Future<void> startCapture({
    int sampleRate = 24000,
    int numChannels = 1,
    int samplesPerChannel = 480,
  }) async {
    if (sampleRate <= 0 || numChannels <= 0 || samplesPerChannel <= 0) {
      throw ArgumentError(
        'Audio capture dimensions must all be greater than zero.',
      );
    }
    await _invoke('startCapture', {
      'sampleRate': sampleRate,
      'numChannels': numChannels,
      'samplesPerChannel': samplesPerChannel,
    });
  }

  @override
  Future<void> stopCapture() => _invoke('stopCapture');

  @override
  Future<void> play(RealtimeAudioFrame frame) async {
    if (frame.sampleRate <= 0 || frame.numChannels <= 0) {
      throw const RealtimeAudioDeviceException(
        code: 'invalid_audio_frame',
        message: 'Realtime audio dimensions must be greater than zero.',
      );
    }
    Uint8List bytes;
    try {
      bytes = base64Decode(frame.data);
    } on FormatException catch (error) {
      throw RealtimeAudioDeviceException(
        code: 'invalid_audio_frame',
        message: 'Realtime audio data is not valid base64.',
        details: error,
      );
    }
    await _invoke('play', {
      'data': bytes,
      'sampleRate': frame.sampleRate,
      'numChannels': frame.numChannels,
      if (frame.samplesPerChannel != null)
        'samplesPerChannel': frame.samplesPerChannel,
    });
  }

  @override
  Future<void> stopPlayback() => _invoke('stopPlayback');

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _methodChannel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      throw RealtimeAudioDeviceException(
        code: error.code,
        message: error.message ?? 'Realtime audio device operation failed.',
        details: error.details,
      );
    } on MissingPluginException catch (error) {
      throw RealtimeAudioDeviceException(
        code: 'realtime_audio_unavailable',
        message: 'Realtime audio is not available on this platform.',
        details: error,
      );
    }
  }
}

RealtimeAudioFrame _decodeCapturedFrame(Object? value) {
  final map = _map(value);
  final bytes = _bytes(map['data']);
  final sampleRate = _positiveInt(map['sampleRate'], 'sampleRate');
  final numChannels = _positiveInt(map['numChannels'], 'numChannels');
  final samplesPerChannel =
      _int(map['samplesPerChannel']) ?? bytes.length ~/ (2 * numChannels);
  if (samplesPerChannel <= 0) {
    throw const FormatException(
      'Captured audio samplesPerChannel must be greater than zero.',
    );
  }
  return RealtimeAudioFrame(
    data: base64Encode(bytes),
    sampleRate: sampleRate,
    numChannels: numChannels,
    samplesPerChannel: samplesPerChannel,
  );
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }
  throw const FormatException('Captured audio event must be an object.');
}

Uint8List _bytes(Object? value) {
  if (value is Uint8List) {
    return value;
  }
  if (value is ByteData) {
    return value.buffer.asUint8List(value.offsetInBytes, value.lengthInBytes);
  }
  if (value is List) {
    return Uint8List.fromList(value.cast<int>());
  }
  if (value is String) {
    return base64Decode(value);
  }
  throw const FormatException('Captured audio data must be PCM bytes.');
}

int _positiveInt(Object? value, String name) {
  final parsed = _int(value);
  if (parsed == null || parsed <= 0) {
    throw FormatException('Captured audio $name must be greater than zero.');
  }
  return parsed;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}
