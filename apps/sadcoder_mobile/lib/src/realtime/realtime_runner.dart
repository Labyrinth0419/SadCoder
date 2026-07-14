enum RealtimeConversationVersion {
  v1('v1'),
  v2('v2');

  const RealtimeConversationVersion(this.wireName);

  final String wireName;

  static RealtimeConversationVersion? fromWire(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'v1' => v1,
      'v2' => v2,
      _ => null,
    };
  }
}

enum RealtimeTextRole {
  user('user'),
  developer('developer'),
  assistant('assistant');

  const RealtimeTextRole(this.wireName);

  final String wireName;
}

class RealtimeVoiceCatalog {
  const RealtimeVoiceCatalog({
    this.v1 = const [],
    this.v2 = const [],
    this.defaultV1,
    this.defaultV2,
  });

  factory RealtimeVoiceCatalog.fromJson(Map<String, Object?> json) {
    return RealtimeVoiceCatalog(
      v1: _strings(json['v1']),
      v2: _strings(json['v2']),
      defaultV1: _string(json['defaultV1'] ?? json['default_v1']),
      defaultV2: _string(json['defaultV2'] ?? json['default_v2']),
    );
  }

  final List<String> v1;
  final List<String> v2;
  final String? defaultV1;
  final String? defaultV2;
}

class RealtimeAudioFrame {
  const RealtimeAudioFrame({
    required this.data,
    required this.sampleRate,
    required this.numChannels,
    this.samplesPerChannel,
    this.itemId,
  });

  factory RealtimeAudioFrame.fromJson(Map<String, Object?> json) {
    return RealtimeAudioFrame(
      data: json['data']?.toString() ?? '',
      sampleRate: _int(json['sampleRate'] ?? json['sample_rate']) ?? 0,
      numChannels: _int(json['numChannels'] ?? json['num_channels']) ?? 0,
      samplesPerChannel: _int(
        json['samplesPerChannel'] ?? json['samples_per_channel'],
      ),
      itemId: _string(json['itemId'] ?? json['item_id']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'data': data,
      'sampleRate': sampleRate,
      'numChannels': numChannels,
      if (samplesPerChannel != null) 'samplesPerChannel': samplesPerChannel,
      if (itemId != null) 'itemId': itemId,
    };
  }

  final String data;
  final int sampleRate;
  final int numChannels;
  final int? samplesPerChannel;
  final String? itemId;
}

enum ThreadRealtimeEventKind {
  started,
  itemAdded,
  transcriptDelta,
  transcriptDone,
  outputAudioDelta,
  sdp,
  error,
  closed,
}

class ThreadRealtimeEvent {
  const ThreadRealtimeEvent({
    required this.kind,
    required this.threadId,
    required this.method,
    required this.raw,
    this.realtimeSessionId,
    this.version,
    this.role,
    this.delta,
    this.text,
    this.item,
    this.audio,
    this.audioFrame,
    this.sdp,
    this.message,
    this.reason,
  });

  final ThreadRealtimeEventKind kind;
  final String threadId;
  final String method;
  final Map<String, Object?> raw;
  final String? realtimeSessionId;
  final RealtimeConversationVersion? version;
  final String? role;
  final String? delta;
  final String? text;
  final Map<String, Object?>? item;
  final Map<String, Object?>? audio;
  final RealtimeAudioFrame? audioFrame;
  final String? sdp;
  final String? message;
  final String? reason;
}

abstract interface class RealtimeRunner {
  Stream<ThreadRealtimeEvent> get events;

  Future<RealtimeVoiceCatalog> listVoices();

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
  });

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
  });

  Future<void> appendText({
    required String threadId,
    required String text,
    RealtimeTextRole role = RealtimeTextRole.user,
  });

  Future<void> appendAudio({
    required String threadId,
    required RealtimeAudioFrame audio,
  });

  Future<void> appendSpeech({required String threadId, required String text});

  Future<void> stop({required String threadId});
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}

List<String> _strings(Object? value) {
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(value.whereType<String>());
}
