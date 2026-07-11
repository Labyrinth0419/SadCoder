import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';

void main() {
  test('maps thread and turn lifecycle notifications', () {
    final threadStarted = CodexEvent.fromNotification({
      'method': 'thread/started',
      'params': {
        'thread': {
          'id': 'thr_1',
          'sessionId': 'sess_1',
          'preview': 'Fix bug',
          'ephemeral': false,
          'status': 'running',
          'cwd': '/repo',
          'updatedAt': 1,
        },
      },
    });
    final turnCompleted = CodexEvent.fromNotification({
      'method': 'turn/completed',
      'params': {
        'threadId': 'thr_1',
        'turn': {
          'id': 'turn_1',
          'status': 'completed',
          'items': <Object?>[],
          'itemsView': 'full',
        },
      },
    });
    final threadNameUpdated = CodexEvent.fromNotification({
      'method': 'thread/name/updated',
      'params': {'threadId': 'thr_1', 'threadName': 'Renamed'},
    });
    final threadArchived = CodexEvent.fromNotification({
      'method': 'thread/archived',
      'params': {'threadId': 'thr_1'},
    });
    final threadUnarchived = CodexEvent.fromNotification({
      'method': 'thread/unarchived',
      'params': {'threadId': 'thr_1'},
    });
    final threadDeleted = CodexEvent.fromNotification({
      'method': 'thread/deleted',
      'params': {'threadId': 'thr_2'},
    });

    expect(threadStarted.kind, CodexEventKind.threadStarted);
    expect(threadStarted.threadId, 'thr_1');
    expect(threadStarted.thread?.title, 'Fix bug');
    expect(threadNameUpdated.kind, CodexEventKind.threadNameUpdated);
    expect(threadNameUpdated.threadId, 'thr_1');
    expect(threadNameUpdated.threadName, 'Renamed');
    expect(threadArchived.kind, CodexEventKind.threadArchived);
    expect(threadArchived.threadId, 'thr_1');
    expect(threadUnarchived.kind, CodexEventKind.threadUnarchived);
    expect(threadUnarchived.threadId, 'thr_1');
    expect(threadDeleted.kind, CodexEventKind.threadDeleted);
    expect(threadDeleted.threadId, 'thr_2');
    expect(turnCompleted.kind, CodexEventKind.turnCompleted);
    expect(turnCompleted.threadId, 'thr_1');
    expect(turnCompleted.turnId, 'turn_1');
    expect(turnCompleted.turn?.status, 'completed');
  });

  test('maps item lifecycle and delta notifications', () {
    final itemStarted = CodexEvent.fromNotification({
      'method': 'item/started',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'item': {'id': 'item_1', 'type': 'agentMessage', 'text': ''},
      },
    });
    final delta = CodexEvent.fromNotification({
      'method': 'item/agentMessage/delta',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'itemId': 'item_1',
        'delta': 'hello',
      },
    });

    expect(itemStarted.kind, CodexEventKind.itemStarted);
    expect(itemStarted.itemId, 'item_1');
    expect(itemStarted.itemType, 'agentMessage');
    expect(delta.kind, CodexEventKind.agentMessageDelta);
    expect(delta.threadId, 'thr_1');
    expect(delta.turnId, 'turn_1');
    expect(delta.itemId, 'item_1');
    expect(delta.delta, 'hello');
  });

  test('maps reasoning file change and MCP progress notifications', () {
    final reasoning = CodexEvent.fromNotification({
      'method': 'item/reasoning/summaryTextDelta',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'itemId': 'reason_1',
        'delta': 'thinking',
        'summaryIndex': 0,
      },
    });
    final patch = CodexEvent.fromNotification({
      'method': 'item/fileChange/patchUpdated',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'itemId': 'file_1',
        'changes': [
          {'path': 'lib/main.dart', 'kind': 'modify', 'diff': '@@'},
        ],
      },
    });
    final progress = CodexEvent.fromNotification({
      'method': 'item/mcpToolCall/progress',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'itemId': 'mcp_1',
        'message': 'searching',
      },
    });

    expect(reasoning.kind, CodexEventKind.reasoningDelta);
    expect(reasoning.itemId, 'reason_1');
    expect(reasoning.delta, 'thinking');
    expect(patch.kind, CodexEventKind.fileChangePatchUpdated);
    expect(patch.fileChanges?.single.path, 'lib/main.dart');
    expect(progress.kind, CodexEventKind.mcpToolCallProgress);
    expect(progress.delta, 'searching');
  });

  test('maps auto-review completed notifications to guardian assessments', () {
    final event = CodexEvent.fromNotification({
      'method': 'item/autoApprovalReview/completed',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'startedAtMs': 1000,
        'completedAtMs': 1042,
        'reviewId': 'review_1',
        'targetItemId': 'item_1',
        'decisionSource': 'agent',
        'review': {
          'status': 'denied',
          'riskLevel': 'high',
          'userAuthorization': 'low',
          'rationale': 'too risky',
        },
        'action': {
          'type': 'mcpToolCall',
          'server': 'github',
          'toolName': 'create_issue',
          'connectorId': 'conn_1',
          'connectorName': 'GitHub',
          'toolTitle': 'Create issue',
        },
      },
    });

    expect(event.kind, CodexEventKind.autoApprovalReviewCompleted);
    expect(event.threadId, 'thr_1');
    expect(event.turnId, 'turn_1');
    expect(event.itemId, 'item_1');
    expect(event.guardianAssessment?.toJson(), {
      'id': 'review_1',
      'target_item_id': 'item_1',
      'turn_id': 'turn_1',
      'started_at_ms': 1000,
      'completed_at_ms': 1042,
      'status': 'denied',
      'risk_level': 'high',
      'user_authorization': 'low',
      'rationale': 'too risky',
      'decision_source': 'agent',
      'action': {
        'type': 'mcp_tool_call',
        'server': 'github',
        'tool_name': 'create_issue',
        'connector_id': 'conn_1',
        'connector_name': 'GitHub',
        'tool_title': 'Create issue',
      },
    });
  });

  test('preserves unknown notifications without throwing', () {
    final event = CodexEvent.fromNotification({
      'method': 'future/event',
      'params': {'value': true},
    });

    expect(event.kind, CodexEventKind.unknown);
    expect(event.method, 'future/event');
    expect(event.raw['params'], {'value': true});
  });
}
