import '../events/codex_event.dart';
import '../protocol/codex_app_server_client.dart';
import 'realtime_runner.dart';

class CodexRealtimeRunner implements RealtimeRunner {
  CodexRealtimeRunner({
    required CodexAppServerClient client,
    required Stream<CodexEvent> events,
  }) : _client = client,
       _events = events
           .where(_isRealtimeEvent)
           .map(_mapRealtimeEvent)
           .asBroadcastStream();

  final CodexAppServerClient _client;
  final Stream<ThreadRealtimeEvent> _events;

  @override
  Stream<ThreadRealtimeEvent> get events => _events;

  @override
  Future<RealtimeVoiceCatalog> listVoices() async {
    final result = await _client.listThreadRealtimeVoices();
    final voices = result['voices'];
    if (voices is Map<String, Object?>) {
      return RealtimeVoiceCatalog.fromJson(voices);
    }
    if (voices is Map) {
      return RealtimeVoiceCatalog.fromJson(
        voices.map((key, value) => MapEntry(key.toString(), value as Object?)),
      );
    }
    return RealtimeVoiceCatalog.fromJson(result);
  }

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
    await _start(
      threadId: threadId,
      outputModality: 'text',
      version: version?.wireName,
      model: _optional(model),
      prompt: _optional(prompt),
      includeStartupContext: includeStartupContext,
      clientManagedHandoffs: clientManagedHandoffs,
      flushTranscriptTailOnSessionEnd: flushTranscriptTailOnSessionEnd,
      codexResponsesAsItems: codexResponsesAsItems,
      codexResponseItemPrefix: _optional(codexResponseItemPrefix),
      codexResponseHandoffPrefix: _optional(codexResponseHandoffPrefix),
      realtimeSessionId: _optional(realtimeSessionId),
    );
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
    await _start(
      threadId: threadId,
      outputModality: 'audio',
      version: version?.wireName,
      voice: _optional(voice),
      model: _optional(model),
      prompt: _optional(prompt),
      includeStartupContext: includeStartupContext,
      clientManagedHandoffs: clientManagedHandoffs,
      flushTranscriptTailOnSessionEnd: flushTranscriptTailOnSessionEnd,
      codexResponsesAsItems: codexResponsesAsItems,
      codexResponseItemPrefix: _optional(codexResponseItemPrefix),
      codexResponseHandoffPrefix: _optional(codexResponseHandoffPrefix),
      realtimeSessionId: _optional(realtimeSessionId),
    );
  }

  @override
  Future<void> appendText({
    required String threadId,
    required String text,
    RealtimeTextRole role = RealtimeTextRole.user,
  }) async {
    await _client.appendThreadRealtimeText(
      threadId: _required(threadId, 'threadId'),
      text: _required(text, 'text'),
      role: role.wireName,
    );
  }

  @override
  Future<void> appendAudio({
    required String threadId,
    required RealtimeAudioFrame audio,
  }) async {
    await _client.appendThreadRealtimeAudio(
      threadId: _required(threadId, 'threadId'),
      audio: audio,
    );
  }

  @override
  Future<void> appendSpeech({
    required String threadId,
    required String text,
  }) async {
    await _client.appendThreadRealtimeSpeech(
      threadId: _required(threadId, 'threadId'),
      text: _required(text, 'text'),
    );
  }

  @override
  Future<void> stop({required String threadId}) async {
    await _client.stopThreadRealtime(threadId: _required(threadId, 'threadId'));
  }

  Future<void> _start({
    required String threadId,
    required String outputModality,
    String? version,
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
    await _client.startThreadRealtime(
      threadId: _required(threadId, 'threadId'),
      outputModality: outputModality,
      transport: const {'type': 'websocket'},
      version: version,
      voice: voice,
      model: model,
      prompt: prompt,
      includeStartupContext: includeStartupContext,
      clientManagedHandoffs: clientManagedHandoffs,
      flushTranscriptTailOnSessionEnd: flushTranscriptTailOnSessionEnd,
      codexResponsesAsItems: codexResponsesAsItems,
      codexResponseItemPrefix: codexResponseItemPrefix,
      codexResponseHandoffPrefix: codexResponseHandoffPrefix,
      realtimeSessionId: realtimeSessionId,
    );
  }
}

bool _isRealtimeEvent(CodexEvent event) {
  return switch (event.kind) {
    CodexEventKind.threadRealtimeStarted ||
    CodexEventKind.threadRealtimeItemAdded ||
    CodexEventKind.threadRealtimeTranscriptDelta ||
    CodexEventKind.threadRealtimeTranscriptDone ||
    CodexEventKind.threadRealtimeOutputAudioDelta ||
    CodexEventKind.threadRealtimeSdp ||
    CodexEventKind.threadRealtimeError ||
    CodexEventKind.threadRealtimeClosed => true,
    _ => false,
  };
}

ThreadRealtimeEvent _mapRealtimeEvent(CodexEvent event) {
  final payload = event.payload ?? const <String, Object?>{};
  final threadId = event.threadId ?? _string(payload['threadId']) ?? '';
  final kind = switch (event.kind) {
    CodexEventKind.threadRealtimeStarted => ThreadRealtimeEventKind.started,
    CodexEventKind.threadRealtimeItemAdded => ThreadRealtimeEventKind.itemAdded,
    CodexEventKind.threadRealtimeTranscriptDelta =>
      ThreadRealtimeEventKind.transcriptDelta,
    CodexEventKind.threadRealtimeTranscriptDone =>
      ThreadRealtimeEventKind.transcriptDone,
    CodexEventKind.threadRealtimeOutputAudioDelta =>
      ThreadRealtimeEventKind.outputAudioDelta,
    CodexEventKind.threadRealtimeSdp => ThreadRealtimeEventKind.sdp,
    CodexEventKind.threadRealtimeError => ThreadRealtimeEventKind.error,
    CodexEventKind.threadRealtimeClosed => ThreadRealtimeEventKind.closed,
    _ => throw StateError('Not a realtime event: ${event.kind}'),
  };
  return ThreadRealtimeEvent(
    kind: kind,
    threadId: threadId,
    method: event.method,
    raw: event.raw,
    realtimeSessionId: _string(payload['realtimeSessionId']),
    version: RealtimeConversationVersion.fromWire(payload['version']),
    role: _string(payload['role']),
    delta: event.delta ?? _string(payload['delta']),
    text: _string(payload['text']),
    item: _map(payload['item']),
    audio: _map(payload['audio']),
    audioFrame: _audioFrame(payload['audio']),
    sdp: _string(payload['sdp']),
    message: _string(payload['message']),
    reason: _string(payload['reason']),
  );
}

RealtimeAudioFrame? _audioFrame(Object? value) {
  final map = _map(value);
  return map == null ? null : RealtimeAudioFrame.fromJson(map);
}

Map<String, Object?>? _map(Object? value) {
  if (value is Map<String, Object?>) {
    return Map.unmodifiable(value);
  }
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value as Object?)),
    );
  }
  return null;
}

String _required(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, '$name must not be blank');
  }
  return normalized;
}

String? _optional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _string(Object? value) => value is String ? value : null;
