import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';

void main() {
  test('maps realtime notification family with thread identity', () {
    final cases =
        <({String method, CodexEventKind kind, Map<String, Object?> params})>[
          (
            method: 'thread/realtime/started',
            kind: CodexEventKind.threadRealtimeStarted,
            params: {'threadId': 'thr_1', 'version': 'v2'},
          ),
          (
            method: 'thread/realtime/itemAdded',
            kind: CodexEventKind.threadRealtimeItemAdded,
            params: {
              'threadId': 'thr_1',
              'item': {'type': 'message'},
            },
          ),
          (
            method: 'thread/realtime/transcript/delta',
            kind: CodexEventKind.threadRealtimeTranscriptDelta,
            params: {'threadId': 'thr_1', 'role': 'assistant', 'delta': 'hi'},
          ),
          (
            method: 'thread/realtime/transcript/done',
            kind: CodexEventKind.threadRealtimeTranscriptDone,
            params: {'threadId': 'thr_1', 'role': 'assistant', 'text': 'hi'},
          ),
          (
            method: 'thread/realtime/outputAudio/delta',
            kind: CodexEventKind.threadRealtimeOutputAudioDelta,
            params: {
              'threadId': 'thr_1',
              'audio': {'data': 'AA=='},
            },
          ),
          (
            method: 'thread/realtime/sdp',
            kind: CodexEventKind.threadRealtimeSdp,
            params: {'threadId': 'thr_1', 'sdp': 'offer'},
          ),
          (
            method: 'thread/realtime/error',
            kind: CodexEventKind.threadRealtimeError,
            params: {'threadId': 'thr_1', 'message': 'failed'},
          ),
          (
            method: 'thread/realtime/closed',
            kind: CodexEventKind.threadRealtimeClosed,
            params: {'threadId': 'thr_1', 'reason': 'user'},
          ),
        ];

    for (final testCase in cases) {
      final event = CodexEvent.fromNotification({
        'method': testCase.method,
        'params': testCase.params,
      });
      expect(event.kind, testCase.kind, reason: testCase.method);
      expect(event.threadId, 'thr_1', reason: testCase.method);
      expect(event.payload, testCase.params, reason: testCase.method);
    }
  });

  test('maps Windows sandbox setup completion notifications', () {
    final event = CodexEvent.fromNotification({
      'method': 'windowsSandbox/setupCompleted',
      'params': {
        'mode': 'elevated',
        'success': false,
        'error': 'administrator approval was cancelled',
      },
    });

    expect(event.kind, CodexEventKind.windowsSandboxSetupCompleted);
    expect(event.payload, {
      'mode': 'elevated',
      'success': false,
      'error': 'administrator approval was cancelled',
    });
  });

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
    final threadSettingsUpdated = CodexEvent.fromNotification({
      'method': 'thread/settings/updated',
      'params': {
        'threadId': 'thr_1',
        'threadSettings': {
          'model': 'gpt-5-codex',
          'cwd': '/repo',
          'effort': 'high',
        },
      },
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
    expect(threadSettingsUpdated.kind, CodexEventKind.threadSettingsUpdated);
    expect(threadSettingsUpdated.threadId, 'thr_1');
    expect(threadSettingsUpdated.threadSettings, {
      'model': 'gpt-5-codex',
      'cwd': '/repo',
      'effort': 'high',
    });
    expect(turnCompleted.kind, CodexEventKind.turnCompleted);
    expect(turnCompleted.threadId, 'thr_1');
    expect(turnCompleted.turnId, 'turn_1');
    expect(turnCompleted.turn?.status, 'completed');
  });

  test('maps authoritative thread goal updates', () {
    final event = CodexEvent.fromNotification({
      'method': 'thread/goal/updated',
      'params': {
        'threadId': 'thr_1',
        'turnId': null,
        'goal': {
          'threadId': 'thr_1',
          'objective': 'Ship stable goals',
          'status': 'active',
          'tokenBudget': 12000,
          'tokensUsed': 42,
          'timeUsedSeconds': 7,
          'createdAt': 100,
          'updatedAt': 101,
        },
      },
    });

    expect(event.kind, CodexEventKind.threadGoalUpdated);
    expect(event.threadId, 'thr_1');
    expect(event.turnId, isNull);
    expect(event.threadGoal?.objective, 'Ship stable goals');
    expect(event.threadGoal?.status, 'active');
    expect(event.threadGoal?.tokenBudget, 12000);
    expect(event.payload?['goal'], isA<Map>());
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
    final reasoningSectionBreak = CodexEvent.fromNotification({
      'method': 'item/reasoning/summaryPartAdded',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'itemId': 'reason_1',
        'summaryIndex': 1,
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
    expect(reasoningSectionBreak.kind, CodexEventKind.reasoningSectionBreak);
    expect(reasoningSectionBreak.itemId, 'reason_1');
    expect(reasoningSectionBreak.delta, isNull);
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

  test('maps status update notifications to typed payload events', () {
    final tokenUsage = CodexEvent.fromNotification({
      'method': 'thread/tokenUsage/updated',
      'params': {
        'threadId': 'thr_1',
        'turnId': 'turn_1',
        'tokenUsage': {
          'last': {
            'inputTokens': 10,
            'cachedInputTokens': 2,
            'outputTokens': 5,
            'reasoningOutputTokens': 1,
            'totalTokens': 16,
          },
          'total': {
            'inputTokens': 100,
            'cachedInputTokens': 20,
            'outputTokens': 50,
            'reasoningOutputTokens': 10,
            'totalTokens': 160,
          },
          'modelContextWindow': 200000,
        },
      },
    });
    final account = CodexEvent.fromNotification({
      'method': 'account/updated',
      'params': {'authMode': 'chatgpt', 'planType': 'pro'},
    });
    final rateLimits = CodexEvent.fromNotification({
      'method': 'account/rateLimits/updated',
      'params': {
        'rateLimits': {
          'limitId': 'codex',
          'primary': {'usedPercent': 42},
        },
      },
    });
    final mcpStartup = CodexEvent.fromNotification({
      'method': 'mcpServer/startupStatus/updated',
      'params': {
        'threadId': 'thr_1',
        'name': 'filesystem',
        'status': 'failed',
        'error': 'missing command',
        'failureReason': 'reauthenticationRequired',
      },
    });
    final importProgress = CodexEvent.fromNotification({
      'method': 'externalAgentConfig/import/progress',
      'params': {'importId': 'import_1', 'itemTypeResults': <Object?>[]},
    });
    final importCompleted = CodexEvent.fromNotification({
      'method': 'externalAgentConfig/import/completed',
      'params': {'importId': 'import_1', 'itemTypeResults': <Object?>[]},
    });

    expect(tokenUsage.kind, CodexEventKind.threadTokenUsageUpdated);
    expect(tokenUsage.threadId, 'thr_1');
    expect(tokenUsage.turnId, 'turn_1');
    expect(tokenUsage.payload?['tokenUsage'], isA<Map<String, Object?>>());
    expect(
      (tokenUsage.payload?['tokenUsage'] as Map<String, Object?>)['total'],
      isA<Map<String, Object?>>(),
    );

    expect(account.kind, CodexEventKind.accountUpdated);
    expect(account.payload, {'authMode': 'chatgpt', 'planType': 'pro'});

    expect(rateLimits.kind, CodexEventKind.accountRateLimitsUpdated);
    expect(rateLimits.payload?['rateLimits'], isA<Map<String, Object?>>());

    expect(mcpStartup.kind, CodexEventKind.mcpServerStartupStatusUpdated);
    expect(mcpStartup.threadId, 'thr_1');
    expect(mcpStartup.payload?['name'], 'filesystem');
    expect(mcpStartup.payload?['status'], 'failed');

    expect(
      importProgress.kind,
      CodexEventKind.externalAgentConfigImportProgress,
    );
    expect(importProgress.payload?['importId'], 'import_1');
    expect(
      importCompleted.kind,
      CodexEventKind.externalAgentConfigImportCompleted,
    );
    expect(importCompleted.payload?['importId'], 'import_1');
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

  test('maps process lifecycle notifications as typed payload events', () {
    final output = CodexEvent.fromNotification({
      'method': 'process/outputDelta',
      'params': {
        'processHandle': 'host_1',
        'stream': 'stdout',
        'deltaBase64': 'aGk=',
        'capReached': false,
      },
    });
    final exited = CodexEvent.fromNotification({
      'method': 'process/exited',
      'params': {
        'processHandle': 'host_1',
        'exitCode': 0,
        'stdout': '',
        'stderr': '',
      },
    });

    expect(output.kind, CodexEventKind.processOutputDelta);
    expect(output.payload?['processHandle'], 'host_1');
    expect(exited.kind, CodexEventKind.processExited);
    expect(exited.payload?['exitCode'], 0);
  });
}
