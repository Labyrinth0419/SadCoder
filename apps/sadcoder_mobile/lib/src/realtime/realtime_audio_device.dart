import 'realtime_runner.dart';

abstract interface class RealtimeAudioDevice {
  Stream<RealtimeAudioFrame> get capturedFrames;

  Future<void> startCapture({
    int sampleRate = 24000,
    int numChannels = 1,
    int samplesPerChannel = 480,
  });

  Future<void> stopCapture();

  Future<void> play(RealtimeAudioFrame frame);

  Future<void> stopPlayback();
}

class RealtimeAudioDeviceException implements Exception {
  const RealtimeAudioDeviceException({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => '$code: $message';
}
