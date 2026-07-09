import '../threads/thread_summary.dart';

enum CodexEventKind {
  threadStarted,
  threadArchived,
  threadDeleted,
  threadNameUpdated,
  turnStarted,
  turnCompleted,
  itemStarted,
  itemCompleted,
  agentMessageDelta,
  commandExecutionOutputDelta,
  reasoningDelta,
  fileChangeOutputDelta,
  fileChangePatchUpdated,
  mcpToolCallProgress,
  planDelta,
  unknown,
}

class CodexEvent {
  const CodexEvent({
    required this.kind,
    required this.method,
    required this.raw,
    this.threadId,
    this.turnId,
    this.itemId,
    this.itemType,
    this.delta,
    this.threadName,
    this.thread,
    this.turn,
    this.item,
    this.fileChanges,
  });

  factory CodexEvent.fromNotification(Map<String, Object?> notification) {
    final method = _stringValue(notification['method']) ?? '';
    final params = _stringKeyedMap(notification['params']);
    return switch (method) {
      'thread/started' => _threadStarted(method, notification, params),
      'thread/archived' => _threadLifecycleEvent(
        CodexEventKind.threadArchived,
        method,
        notification,
        params,
      ),
      'thread/deleted' => _threadLifecycleEvent(
        CodexEventKind.threadDeleted,
        method,
        notification,
        params,
      ),
      'thread/name/updated' => _threadLifecycleEvent(
        CodexEventKind.threadNameUpdated,
        method,
        notification,
        params,
      ),
      'turn/started' => _turnEvent(
        CodexEventKind.turnStarted,
        method,
        notification,
        params,
      ),
      'turn/completed' => _turnEvent(
        CodexEventKind.turnCompleted,
        method,
        notification,
        params,
      ),
      'item/started' => _itemEvent(
        CodexEventKind.itemStarted,
        method,
        notification,
        params,
      ),
      'item/completed' => _itemEvent(
        CodexEventKind.itemCompleted,
        method,
        notification,
        params,
      ),
      'item/agentMessage/delta' => _deltaEvent(
        CodexEventKind.agentMessageDelta,
        method,
        notification,
        params,
      ),
      'item/commandExecution/outputDelta' => _deltaEvent(
        CodexEventKind.commandExecutionOutputDelta,
        method,
        notification,
        params,
      ),
      'item/reasoning/summaryTextDelta' ||
      'item/reasoning/textDelta' => _deltaEvent(
        CodexEventKind.reasoningDelta,
        method,
        notification,
        params,
      ),
      'item/fileChange/outputDelta' => _deltaEvent(
        CodexEventKind.fileChangeOutputDelta,
        method,
        notification,
        params,
      ),
      'item/fileChange/patchUpdated' => _fileChangePatchUpdated(
        method,
        notification,
        params,
      ),
      'item/mcpToolCall/progress' => _messageEvent(
        CodexEventKind.mcpToolCallProgress,
        method,
        notification,
        params,
      ),
      'item/plan/delta' => _deltaEvent(
        CodexEventKind.planDelta,
        method,
        notification,
        params,
      ),
      _ => CodexEvent(
        kind: CodexEventKind.unknown,
        method: method,
        raw: Map.unmodifiable(notification),
      ),
    };
  }

  final CodexEventKind kind;
  final String method;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String? itemType;
  final String? delta;
  final String? threadName;
  final ThreadSummary? thread;
  final TurnSummary? turn;
  final Map<String, Object?>? item;
  final List<ThreadFileChangeSummary>? fileChanges;
  final Map<String, Object?> raw;

  static CodexEvent _threadStarted(
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    final thread = ThreadSummary.fromJson(_stringKeyedMap(params['thread']));
    return CodexEvent(
      kind: CodexEventKind.threadStarted,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: thread.id,
      thread: thread,
    );
  }

  static CodexEvent _threadLifecycleEvent(
    CodexEventKind kind,
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    return CodexEvent(
      kind: kind,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: _stringValue(params['threadId']),
      threadName: _stringValue(params['threadName']),
    );
  }

  static CodexEvent _turnEvent(
    CodexEventKind kind,
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    final turn = TurnSummary.fromJson(_stringKeyedMap(params['turn']));
    return CodexEvent(
      kind: kind,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: _stringValue(params['threadId']),
      turnId: turn.id,
      turn: turn,
    );
  }

  static CodexEvent _itemEvent(
    CodexEventKind kind,
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    final item = _stringKeyedMap(params['item']);
    return CodexEvent(
      kind: kind,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: _stringValue(params['threadId']),
      turnId: _stringValue(params['turnId']),
      itemId: _stringValue(item['id']),
      itemType: _stringValue(item['type']),
      item: Map.unmodifiable(item),
    );
  }

  static CodexEvent _deltaEvent(
    CodexEventKind kind,
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    return CodexEvent(
      kind: kind,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: _stringValue(params['threadId']),
      turnId: _stringValue(params['turnId']),
      itemId: _stringValue(params['itemId']),
      delta: _stringValue(params['delta']),
    );
  }

  static CodexEvent _messageEvent(
    CodexEventKind kind,
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    return CodexEvent(
      kind: kind,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: _stringValue(params['threadId']),
      turnId: _stringValue(params['turnId']),
      itemId: _stringValue(params['itemId']),
      delta: _stringValue(params['message']),
    );
  }

  static CodexEvent _fileChangePatchUpdated(
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    return CodexEvent(
      kind: CodexEventKind.fileChangePatchUpdated,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: _stringValue(params['threadId']),
      turnId: _stringValue(params['turnId']),
      itemId: _stringValue(params['itemId']),
      fileChanges: _listOfMaps(
        params['changes'],
      ).map(ThreadFileChangeSummary.fromJson).toList(growable: false),
    );
  }
}

Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }
  return const {};
}

String? _stringValue(Object? value) => value is String ? value : null;

List<Map<String, Object?>> _listOfMaps(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((entry) => Map<String, Object?>.from(entry))
      .toList(growable: false);
}
