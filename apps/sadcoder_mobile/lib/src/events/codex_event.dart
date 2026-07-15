import '../threads/thread_summary.dart';
import '../goals/thread_goal.dart';
import 'guardian_assessment_event.dart';

enum CodexEventKind {
  threadStarted,
  threadArchived,
  threadUnarchived,
  threadDeleted,
  threadNameUpdated,
  threadGoalUpdated,
  threadSettingsUpdated,
  threadTokenUsageUpdated,
  turnStarted,
  turnCompleted,
  itemStarted,
  itemCompleted,
  agentMessageDelta,
  commandExecutionOutputDelta,
  reasoningDelta,
  reasoningSectionBreak,
  fileChangeOutputDelta,
  fileChangePatchUpdated,
  mcpToolCallProgress,
  planDelta,
  autoApprovalReviewStarted,
  autoApprovalReviewCompleted,
  accountUpdated,
  accountRateLimitsUpdated,
  mcpServerStartupStatusUpdated,
  externalAgentConfigImportProgress,
  externalAgentConfigImportCompleted,
  windowsSandboxSetupCompleted,
  processOutputDelta,
  processExited,
  threadRealtimeStarted,
  threadRealtimeItemAdded,
  threadRealtimeTranscriptDelta,
  threadRealtimeTranscriptDone,
  threadRealtimeOutputAudioDelta,
  threadRealtimeSdp,
  threadRealtimeError,
  threadRealtimeClosed,
  fsChanged,
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
    this.threadGoal,
    this.thread,
    this.turn,
    this.item,
    this.threadSettings,
    this.fileChanges,
    this.guardianAssessment,
    this.payload,
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
      'thread/unarchived' => _threadLifecycleEvent(
        CodexEventKind.threadUnarchived,
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
      'thread/goal/updated' => _threadGoalUpdated(method, notification, params),
      'thread/settings/updated' => _threadSettingsUpdated(
        method,
        notification,
        params,
      ),
      'thread/tokenUsage/updated' => _payloadEvent(
        CodexEventKind.threadTokenUsageUpdated,
        method,
        notification,
        params,
        threadId: _stringValue(params['threadId']),
        turnId: _stringValue(params['turnId']),
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
      'item/reasoning/summaryPartAdded' => _reasoningSectionBreakEvent(
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
      'item/autoApprovalReview/started' => _guardianAssessmentEvent(
        CodexEventKind.autoApprovalReviewStarted,
        method,
        notification,
        params,
      ),
      'item/autoApprovalReview/completed' => _guardianAssessmentEvent(
        CodexEventKind.autoApprovalReviewCompleted,
        method,
        notification,
        params,
      ),
      'account/updated' => _payloadEvent(
        CodexEventKind.accountUpdated,
        method,
        notification,
        params,
      ),
      'account/rateLimits/updated' => _payloadEvent(
        CodexEventKind.accountRateLimitsUpdated,
        method,
        notification,
        params,
      ),
      'mcpServer/startupStatus/updated' => _payloadEvent(
        CodexEventKind.mcpServerStartupStatusUpdated,
        method,
        notification,
        params,
        threadId: _stringValue(params['threadId']),
      ),
      'externalAgentConfig/import/progress' => _payloadEvent(
        CodexEventKind.externalAgentConfigImportProgress,
        method,
        notification,
        params,
      ),
      'externalAgentConfig/import/completed' => _payloadEvent(
        CodexEventKind.externalAgentConfigImportCompleted,
        method,
        notification,
        params,
      ),
      'windowsSandbox/setupCompleted' => _payloadEvent(
        CodexEventKind.windowsSandboxSetupCompleted,
        method,
        notification,
        params,
      ),
      'process/outputDelta' => _payloadEvent(
        CodexEventKind.processOutputDelta,
        method,
        notification,
        params,
      ),
      'process/exited' => _payloadEvent(
        CodexEventKind.processExited,
        method,
        notification,
        params,
      ),
      'thread/realtime/started' => _payloadEvent(
        CodexEventKind.threadRealtimeStarted,
        method,
        notification,
        params,
        threadId: _stringValue(params['threadId']),
      ),
      'thread/realtime/itemAdded' => _payloadEvent(
        CodexEventKind.threadRealtimeItemAdded,
        method,
        notification,
        params,
        threadId: _stringValue(params['threadId']),
      ),
      'thread/realtime/transcript/delta' => _realtimeTranscriptDeltaEvent(
        method,
        notification,
        params,
      ),
      'thread/realtime/transcript/done' => _payloadEvent(
        CodexEventKind.threadRealtimeTranscriptDone,
        method,
        notification,
        params,
        threadId: _stringValue(params['threadId']),
      ),
      'thread/realtime/outputAudio/delta' => _payloadEvent(
        CodexEventKind.threadRealtimeOutputAudioDelta,
        method,
        notification,
        params,
        threadId: _stringValue(params['threadId']),
      ),
      'thread/realtime/sdp' => _payloadEvent(
        CodexEventKind.threadRealtimeSdp,
        method,
        notification,
        params,
        threadId: _stringValue(params['threadId']),
      ),
      'thread/realtime/error' => _payloadEvent(
        CodexEventKind.threadRealtimeError,
        method,
        notification,
        params,
        threadId: _stringValue(params['threadId']),
      ),
      'thread/realtime/closed' => _payloadEvent(
        CodexEventKind.threadRealtimeClosed,
        method,
        notification,
        params,
        threadId: _stringValue(params['threadId']),
      ),
      'fs/changed' => _payloadEvent(
        CodexEventKind.fsChanged,
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
  final ThreadGoal? threadGoal;
  final ThreadSummary? thread;
  final TurnSummary? turn;
  final Map<String, Object?>? item;
  final Map<String, Object?>? threadSettings;
  final List<ThreadFileChangeSummary>? fileChanges;
  final GuardianAssessmentEvent? guardianAssessment;
  final Map<String, Object?>? payload;
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

  static CodexEvent _threadSettingsUpdated(
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    final settings = _stringKeyedMap(params['threadSettings']);
    return CodexEvent(
      kind: CodexEventKind.threadSettingsUpdated,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: _stringValue(params['threadId']),
      threadSettings: Map.unmodifiable(settings),
    );
  }

  static CodexEvent _threadGoalUpdated(
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    final goal = ThreadGoal.fromJson(params['goal']);
    return CodexEvent(
      kind: CodexEventKind.threadGoalUpdated,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: _stringValue(params['threadId']) ?? goal?.threadId,
      turnId: _stringValue(params['turnId']),
      threadGoal: goal,
      payload: Map.unmodifiable(params),
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

  static CodexEvent _reasoningSectionBreakEvent(
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    return CodexEvent(
      kind: CodexEventKind.reasoningSectionBreak,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: _stringValue(params['threadId']),
      turnId: _stringValue(params['turnId']),
      itemId: _stringValue(params['itemId']),
    );
  }

  static CodexEvent _realtimeTranscriptDeltaEvent(
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    return CodexEvent(
      kind: CodexEventKind.threadRealtimeTranscriptDelta,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: _stringValue(params['threadId']),
      delta: _stringValue(params['delta']),
      payload: Map.unmodifiable(params),
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

  static CodexEvent _guardianAssessmentEvent(
    CodexEventKind kind,
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params,
  ) {
    final assessment = GuardianAssessmentEvent.fromAutoReviewNotification(
      params,
    );
    return CodexEvent(
      kind: kind,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: assessment.threadId,
      turnId: assessment.turnId,
      itemId: assessment.targetItemId,
      guardianAssessment: assessment,
    );
  }

  static CodexEvent _payloadEvent(
    CodexEventKind kind,
    String method,
    Map<String, Object?> raw,
    Map<String, Object?> params, {
    String? threadId,
    String? turnId,
  }) {
    return CodexEvent(
      kind: kind,
      method: method,
      raw: Map.unmodifiable(raw),
      threadId: threadId,
      turnId: turnId,
      payload: Map.unmodifiable(params),
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
