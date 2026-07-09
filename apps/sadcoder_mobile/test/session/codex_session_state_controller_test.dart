import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/agent/agent_snapshot.dart';
import 'package:sadcoder_mobile/src/agent/agent_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal_runner.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal_runner.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_reader.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_session.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review_runner.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/reconnect_policy.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/skills/skill_list_reader.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_proxy_connector.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_mutation_runner.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/turns/turn_runner.dart';
import 'package:sadcoder_mobile/src/usage/account_usage_snapshot_reader.dart';

void main() {
  test('connect opens a session and records state transitions', () async {
    final approvalController = ApprovalStateController();
    final connector = _FakeSessionStarter();
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);
    final statuses = <CodexSessionStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.connect(_profile);

    expect(statuses, [
      CodexSessionStatus.connecting,
      CodexSessionStatus.connected,
    ]);
    expect(controller.isConnected, true);
    expect(controller.profile, _profile);
    expect(controller.threadListReader, isNotNull);
    expect(controller.threadDetailReader, isNotNull);
    expect(controller.configSnapshotReader, isNotNull);
    expect(controller.accountSnapshotReader, isNotNull);
    expect(controller.modelListReader, isNotNull);
    expect(controller.permissionProfileListReader, isNotNull);
    expect(controller.skillListReader, isNotNull);
    expect(controller.pluginListReader, isNotNull);
    expect(controller.turnRunner, isNotNull);
    expect(controller.threadBackgroundTerminalRunner, isNotNull);
    expect(controller.threadReviewRunner, isNotNull);
    expect(connector.connectedProfiles, [_profile]);
    expect(approvalController.canRespond, true);
  });

  test('connect backfills pending approvals from agent snapshot', () async {
    final approvalController = ApprovalStateController();
    final snapshotReader = _FakeAgentSnapshotReader(
      outcomes: [
        _snapshotWithApproval(
          requestId: 'approval-from-snapshot',
          command: 'cargo test',
        ),
      ],
    );
    final controller = CodexSessionStateController(
      connector: _FakeSessionStarter(),
      approvalController: approvalController,
      snapshotReader: snapshotReader,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    await controller.connect(_profile);
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.connected);
    expect(snapshotReader.profiles, [_profile]);
    expect(
      approvalController.approvals.single.requestId,
      'approval-from-snapshot',
    );
    expect(approvalController.approvals.single.command, 'cargo test');
  });

  test('connect backfills recent events from agent snapshot', () async {
    final approvalController = ApprovalStateController();
    final snapshotReader = _FakeAgentSnapshotReader(
      outcomes: [_snapshotWithEvent(threadId: 'thr_snapshot')],
    );
    final controller = CodexSessionStateController(
      connector: _FakeSessionStarter(),
      approvalController: approvalController,
      snapshotReader: snapshotReader,
    );
    final events = <CodexEvent>[];
    final subscription = controller.events!.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    await controller.connect(_profile);
    await _flushMicrotasks();

    expect(events, hasLength(1));
    expect(events.single.kind, CodexEventKind.turnStarted);
    expect(events.single.threadId, 'thr_snapshot');
  });

  test('snapshot backfill failure does not fail connection', () async {
    final approvalController = ApprovalStateController();
    final snapshotReader = _FakeAgentSnapshotReader(
      outcomes: [StateError('snapshot failed')],
    );
    final controller = CodexSessionStateController(
      connector: _FakeSessionStarter(),
      approvalController: approvalController,
      snapshotReader: snapshotReader,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    await controller.connect(_profile);
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.connected);
    expect(controller.error, isNull);
    expect(snapshotReader.profiles, [_profile]);
    expect(approvalController.approvals, isEmpty);
    expect(approvalController.canRespond, true);
  });

  test(
    'disconnect closes connection without clearing pending approvals',
    () async {
      final approvalController = ApprovalStateController(
        initialApprovals: const [
          PendingApproval(
            requestId: 'approval-1',
            method: commandExecutionApprovalMethod,
            kind: PendingApprovalKind.commandExecution,
            rawParams: {},
          ),
        ],
      );
      final connector = _FakeSessionStarter();
      final controller = CodexSessionStateController(
        connector: connector,
        approvalController: approvalController,
      );
      addTearDown(controller.dispose);
      addTearDown(approvalController.dispose);
      final statuses = <CodexSessionStatus>[];
      controller.addListener(() => statuses.add(controller.status));

      await controller.connect(_profile);
      await controller.disconnect();

      expect(statuses, [
        CodexSessionStatus.connecting,
        CodexSessionStatus.connected,
        CodexSessionStatus.disconnecting,
        CodexSessionStatus.idle,
      ]);
      expect(connector.closeCount, 1);
      expect(approvalController.approvals.single.requestId, 'approval-1');
      expect(approvalController.canRespond, false);
    },
  );

  test('failed connect records failure and keeps approvals', () async {
    final approvalController = ApprovalStateController(
      initialApprovals: const [
        PendingApproval(
          requestId: 'approval-1',
          method: commandExecutionApprovalMethod,
          kind: PendingApprovalKind.commandExecution,
          rawParams: {},
        ),
      ],
    );
    final connector = _FakeSessionStarter(failConnect: true);
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);
    final statuses = <CodexSessionStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await expectLater(controller.connect(_profile), throwsA(isA<StateError>()));

    expect(statuses, [
      CodexSessionStatus.connecting,
      CodexSessionStatus.failed,
    ]);
    expect(controller.error, isA<StateError>());
    expect(approvalController.approvals.single.requestId, 'approval-1');
    expect(approvalController.canRespond, false);
  });

  test(
    'connection loss reconnects with backoff without clearing approvals',
    () async {
      final approvalController = ApprovalStateController(
        initialApprovals: const [
          PendingApproval(
            requestId: 'approval-1',
            method: commandExecutionApprovalMethod,
            kind: PendingApprovalKind.commandExecution,
            rawParams: {},
          ),
        ],
      );
      final connector = _FakeSessionStarter();
      final scheduler = _FakeReconnectDelayScheduler();
      final controller = CodexSessionStateController(
        connector: connector,
        approvalController: approvalController,
        reconnectPolicy: const ReconnectPolicy.fixed(
          delays: [Duration(milliseconds: 1)],
        ),
        reconnectDelayScheduler: scheduler,
      );
      addTearDown(controller.dispose);
      addTearDown(approvalController.dispose);
      final statuses = <CodexSessionStatus>[];
      controller.addListener(() => statuses.add(controller.status));

      await controller.connect(_profile);
      connector.connections.single.completeDone();
      await _flushMicrotasks();

      expect(controller.status, CodexSessionStatus.reconnecting);
      expect(controller.reconnectAttempt, 1);
      expect(controller.nextReconnectDelay, const Duration(milliseconds: 1));
      expect(scheduler.delays, [const Duration(milliseconds: 1)]);
      expect(approvalController.approvals.single.requestId, 'approval-1');
      expect(approvalController.canRespond, false);

      scheduler.completeNext();
      await _flushMicrotasks();

      expect(controller.status, CodexSessionStatus.connected);
      expect(connector.connectedProfiles, [_profile, _profile]);
      expect(connector.closeCount, 1);
      expect(approvalController.approvals.single.requestId, 'approval-1');
      expect(approvalController.canRespond, true);
      expect(statuses, contains(CodexSessionStatus.reconnecting));
      expect(statuses, isNot(contains(CodexSessionStatus.disconnecting)));
    },
  );

  test('reconnect backfills pending approvals from agent snapshot', () async {
    final approvalController = ApprovalStateController();
    final connector = _FakeSessionStarter();
    final scheduler = _FakeReconnectDelayScheduler();
    final snapshotReader = _FakeAgentSnapshotReader(
      outcomes: [
        _emptySnapshot,
        _snapshotWithApproval(
          requestId: 'approval-after-reconnect',
          command: 'dart test',
        ),
      ],
    );
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
      snapshotReader: snapshotReader,
      reconnectPolicy: const ReconnectPolicy.fixed(
        delays: [Duration(milliseconds: 1)],
      ),
      reconnectDelayScheduler: scheduler,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    await controller.connect(_profile);
    await _flushMicrotasks();
    expect(approvalController.approvals, isEmpty);

    connector.connections.single.completeDone();
    await _flushMicrotasks();
    scheduler.completeNext();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.connected);
    expect(snapshotReader.profiles, [_profile, _profile]);
    expect(
      approvalController.approvals.single.requestId,
      'approval-after-reconnect',
    );
    expect(approvalController.approvals.single.command, 'dart test');
  });

  test(
    'stale snapshot backfill from a dropped connection is ignored',
    () async {
      final approvalController = ApprovalStateController();
      final connector = _FakeSessionStarter();
      final scheduler = _FakeReconnectDelayScheduler();
      final snapshotReader = _PendingAgentSnapshotReader();
      final controller = CodexSessionStateController(
        connector: connector,
        approvalController: approvalController,
        snapshotReader: snapshotReader,
        reconnectPolicy: const ReconnectPolicy.fixed(
          delays: [Duration(milliseconds: 1)],
        ),
        reconnectDelayScheduler: scheduler,
      );
      final events = <CodexEvent>[];
      final subscription = controller.events!.listen(events.add);
      addTearDown(subscription.cancel);
      addTearDown(controller.dispose);
      addTearDown(approvalController.dispose);

      await controller.connect(_profile);
      await _flushMicrotasks();
      expect(snapshotReader.pendingCount, 1);

      connector.connections.single.completeDone();
      await _flushMicrotasks();
      scheduler.completeNext();
      await _flushMicrotasks();

      expect(controller.status, CodexSessionStatus.connected);
      expect(snapshotReader.pendingCount, 2);

      snapshotReader.completeAt(
        0,
        _snapshotWithApprovalAndEvent(
          requestId: 'stale',
          command: 'stale command',
          threadId: 'thr_stale',
        ),
      );
      await _flushMicrotasks();
      expect(approvalController.approvals, isEmpty);
      expect(events, isEmpty);

      snapshotReader.completeAt(
        1,
        _snapshotWithApprovalAndEvent(
          requestId: 'current',
          command: 'current command',
          threadId: 'thr_current',
        ),
      );
      await _flushMicrotasks();
      expect(approvalController.approvals.single.requestId, 'current');
      expect(approvalController.approvals.single.command, 'current command');
      expect(events.single.threadId, 'thr_current');
    },
  );

  test('failed reconnect attempts keep retrying with capped backoff', () async {
    final approvalController = ApprovalStateController();
    final connector = _FakeSessionStarter(
      connectOutcomes: [null, StateError('reconnect failed'), null],
    );
    final scheduler = _FakeReconnectDelayScheduler();
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
      reconnectPolicy: const ReconnectPolicy.fixed(
        delays: [Duration(milliseconds: 1), Duration(milliseconds: 2)],
      ),
      reconnectDelayScheduler: scheduler,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    await controller.connect(_profile);
    connector.connections.single.completeDone();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.reconnecting);
    expect(scheduler.delays, [const Duration(milliseconds: 1)]);

    scheduler.completeNext();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.reconnecting);
    expect(controller.error, isA<StateError>());
    expect(controller.reconnectAttempt, 2);
    expect(scheduler.delays, [
      const Duration(milliseconds: 1),
      const Duration(milliseconds: 2),
    ]);

    scheduler.completeNext();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.connected);
    expect(connector.connectedProfiles, [_profile, _profile]);
    expect(connector.connectCount, 3);
  });

  test('manual disconnect cancels a queued reconnect', () async {
    final approvalController = ApprovalStateController(
      initialApprovals: const [
        PendingApproval(
          requestId: 'approval-1',
          method: commandExecutionApprovalMethod,
          kind: PendingApprovalKind.commandExecution,
          rawParams: {},
        ),
      ],
    );
    final connector = _FakeSessionStarter();
    final scheduler = _FakeReconnectDelayScheduler();
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
      reconnectPolicy: const ReconnectPolicy.fixed(
        delays: [Duration(milliseconds: 1)],
      ),
      reconnectDelayScheduler: scheduler,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    await controller.connect(_profile);
    connector.connections.single.completeDone();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.reconnecting);

    await controller.disconnect();
    scheduler.completeNext();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.idle);
    expect(controller.threadListReader, isNull);
    expect(controller.threadDetailReader, isNull);
    expect(controller.configSnapshotReader, isNull);
    expect(controller.accountSnapshotReader, isNull);
    expect(controller.modelListReader, isNull);
    expect(controller.permissionProfileListReader, isNull);
    expect(controller.skillListReader, isNull);
    expect(controller.pluginListReader, isNull);
    expect(controller.turnRunner, isNull);
    expect(connector.connectCount, 1);
    expect(connector.closeCount, 1);
    expect(approvalController.approvals.single.requestId, 'approval-1');
    expect(approvalController.canRespond, false);
  });
}

const _emptySnapshot = AgentSnapshot(
  schemaVersion: 1,
  pendingApprovals: [],
  recentEvents: [],
);

AgentSnapshot _snapshotWithApproval({
  required Object requestId,
  required String command,
}) {
  return AgentSnapshot(
    schemaVersion: 1,
    pendingApprovals: [
      JsonRpcServerRequest(
        id: requestId,
        method: commandExecutionApprovalMethod,
        params: {'command': command},
      ),
    ],
    recentEvents: const [],
  );
}

AgentSnapshot _snapshotWithEvent({required String threadId}) {
  return AgentSnapshot(
    schemaVersion: 1,
    pendingApprovals: const [],
    recentEvents: [_turnStartedCachedEvent(threadId)],
  );
}

AgentSnapshot _snapshotWithApprovalAndEvent({
  required Object requestId,
  required String command,
  required String threadId,
}) {
  return AgentSnapshot(
    schemaVersion: 1,
    pendingApprovals: [
      JsonRpcServerRequest(
        id: requestId,
        method: commandExecutionApprovalMethod,
        params: {'command': command},
      ),
    ],
    recentEvents: [_turnStartedCachedEvent(threadId)],
  );
}

AgentCachedEvent _turnStartedCachedEvent(String threadId) {
  return AgentCachedEvent(
    method: 'turn/started',
    params: {
      'threadId': threadId,
      'turn': {
        'id': 'turn_1',
        'status': 'inProgress',
        'items': <Object?>[],
        'itemsView': 'notLoaded',
      },
    },
  );
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

class _FakeSessionStarter implements CodexSessionConnectionStarter {
  _FakeSessionStarter({
    this.failConnect = false,
    List<Object?>? connectOutcomes,
  }) : connectOutcomes = connectOutcomes ?? const [];

  final bool failConnect;
  final List<Object?> connectOutcomes;
  final connectedProfiles = <SshProfile>[];
  final connections = <_FakeConnectionRecord>[];
  int connectCount = 0;
  int closeCount = 0;

  @override
  Future<CodexSessionConnection> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    final outcome = connectCount < connectOutcomes.length
        ? connectOutcomes[connectCount]
        : null;
    connectCount++;
    if (failConnect) {
      throw StateError('connect failed');
    }
    if (outcome != null) {
      throw outcome;
    }
    connectedProfiles.add(profile);
    final record = _FakeConnectionRecord();
    connections.add(record);
    final session = CodexAppSession(
      MemoryJsonRpcTransport((_) async => {}),
      approvalController: approvalController,
    );
    return CodexSessionConnection(
      profile: profile,
      session: session,
      threadListReader: const _FakeThreadListReader(),
      threadDetailReader: const _FakeThreadDetailReader(),
      configSnapshotReader: const _FakeConfigSnapshotReader(),
      accountSnapshotReader: const _FakeAccountSnapshotReader(),
      accountUsageSnapshotReader: const _FakeAccountUsageSnapshotReader(),
      mcpServerStatusReader: const _FakeMcpServerStatusReader(),
      modelListReader: const _FakeModelListReader(),
      permissionProfileListReader: const _FakePermissionProfileListReader(),
      skillListReader: const _FakeSkillListReader(),
      pluginListReader: const _FakePluginListReader(),
      threadMutationRunner: const _FakeThreadMutationRunner(),
      threadBackgroundTerminalRunner:
          const _FakeThreadBackgroundTerminalRunner(),
      threadGoalRunner: const _FakeThreadGoalRunner(),
      threadReviewRunner: const _FakeThreadReviewRunner(),
      turnRunner: const _FakeTurnRunner(),
      proxyConnection: AgentProxyConnection(
        input: const Stream<Uint8List>.empty(),
        output: StreamController<Uint8List>().sink,
        done: record.done,
        close: () async {
          record.closed = true;
          closeCount++;
        },
      ),
    );
  }
}

class _FakeConfigSnapshotReader implements CodexConfigSnapshotReader {
  const _FakeConfigSnapshotReader();

  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    return const CodexConfigSnapshot(config: {}, origins: {}, layers: []);
  }
}

class _FakeAccountSnapshotReader implements AccountSnapshotReader {
  const _FakeAccountSnapshotReader();

  @override
  Future<AccountSnapshot> readAccount({bool refreshToken = false}) async {
    return const AccountSnapshot(account: null, requiresOpenaiAuth: false);
  }
}

class _FakeAccountUsageSnapshotReader implements AccountUsageSnapshotReader {
  const _FakeAccountUsageSnapshotReader();

  @override
  Future<AccountUsageSnapshot> readUsage() async {
    return const AccountUsageSnapshot(
      summary: AccountTokenUsageSummary(),
      dailyUsageBuckets: [],
      rateLimits: null,
      rateLimitsByLimitId: {},
      rateLimitResetCredits: null,
    );
  }
}

class _FakeMcpServerStatusReader implements McpServerStatusReader {
  const _FakeMcpServerStatusReader();

  @override
  Future<McpServerStatusPage> listMcpServers({
    String? threadId,
    String? cursor,
    int? limit,
    McpServerStatusDetail detail = McpServerStatusDetail.toolsAndAuthOnly,
  }) async {
    return const McpServerStatusPage(servers: []);
  }
}

class _FakeModelListReader implements ModelListReader {
  const _FakeModelListReader();

  @override
  Future<ModelListPage> listModels() async {
    return const ModelListPage(models: []);
  }
}

class _FakePermissionProfileListReader implements PermissionProfileListReader {
  const _FakePermissionProfileListReader();

  @override
  Future<PermissionProfileListPage> listPermissionProfiles({
    String? cwd,
  }) async {
    return const PermissionProfileListPage(profiles: []);
  }
}

class _FakeSkillListReader implements SkillListReader {
  const _FakeSkillListReader();

  @override
  Future<SkillListPage> listSkills({
    List<String> cwds = const [],
    bool forceReload = false,
  }) async {
    return const SkillListPage(entries: []);
  }
}

class _FakePluginListReader implements PluginListReader {
  const _FakePluginListReader();

  @override
  Future<PluginListPage> listPlugins({
    List<String> cwds = const [],
    List<PluginMarketplaceKind> marketplaceKinds = const [],
  }) async {
    return const PluginListPage(marketplaces: []);
  }
}

class _FakeThreadListReader implements ThreadListReader {
  const _FakeThreadListReader();

  @override
  Future<ThreadListPage> listThreads({int limit = 20}) async {
    return const ThreadListPage(threads: []);
  }
}

class _FakeThreadDetailReader implements ThreadDetailReader {
  const _FakeThreadDetailReader();

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    return ThreadDetail(
      thread: ThreadSummary.fromJson({
        'id': threadId,
        'sessionId': 'sess_1',
        'preview': 'Fake thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
        'turns': <Object?>[],
      }),
    );
  }
}

class _FakeTurnRunner implements TurnRunner {
  const _FakeTurnRunner();

  @override
  Future<ThreadSummary> startThread() async => ThreadSummary.fromJson({
    'id': 'thr_1',
    'sessionId': 'sess_1',
    'preview': 'Fake thread',
    'ephemeral': false,
    'status': 'idle',
    'cwd': '/repo',
    'updatedAt': 1,
  });

  @override
  Future<ThreadSummary> resumeThread({required String threadId}) async =>
      ThreadSummary.fromJson({
        'id': threadId,
        'sessionId': 'sess_1',
        'preview': 'Fake thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
      });

  @override
  Future<TurnSummary> startTurn({
    required String threadId,
    required String text,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
  }) async => TurnSummary.fromJson({
    'id': 'turn_1',
    'status': 'inProgress',
    'items': <Object?>[],
    'itemsView': 'notLoaded',
  });

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {}
}

class _FakeThreadMutationRunner implements ThreadMutationRunner {
  const _FakeThreadMutationRunner();

  @override
  Future<ThreadSummary> forkThread({
    required String threadId,
    String? lastTurnId,
    bool ephemeral = false,
  }) async {
    return ThreadSummary.fromJson({
      'id': 'thr_fork',
      'sessionId': 'sess_1',
      'preview': 'Forked thread',
      'ephemeral': ephemeral,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'forkedFromId': threadId,
    });
  }

  @override
  Future<void> compactThread({required String threadId}) async {}

  @override
  Future<void> setThreadName({
    required String threadId,
    required String name,
  }) async {}

  @override
  Future<void> archiveThread({required String threadId}) async {}

  @override
  Future<void> deleteThread({required String threadId}) async {}
}

class _FakeThreadBackgroundTerminalRunner
    implements ThreadBackgroundTerminalRunner {
  const _FakeThreadBackgroundTerminalRunner();

  @override
  Future<ThreadBackgroundTerminalPage> listTerminals({
    required String threadId,
    String? cursor,
    int? limit,
  }) async {
    return const ThreadBackgroundTerminalPage(terminals: []);
  }

  @override
  Future<void> cleanTerminals({required String threadId}) async {}
}

class _FakeThreadGoalRunner implements ThreadGoalRunner {
  const _FakeThreadGoalRunner();

  @override
  Future<ThreadGoalGetResult> getGoal({required String threadId}) async {
    return const ThreadGoalGetResult();
  }

  @override
  Future<ThreadGoalSetResult> setGoal({
    required String threadId,
    String? objective,
    String? status,
    int? tokenBudget,
  }) async {
    return ThreadGoalSetResult(
      goal: ThreadGoal(
        threadId: threadId,
        objective: objective ?? 'Goal',
        status: status ?? 'active',
        tokenBudget: tokenBudget,
        tokensUsed: 0,
        timeUsedSeconds: 0,
        createdAtSeconds: 1,
        updatedAtSeconds: 1,
        raw: const {},
      ),
    );
  }

  @override
  Future<ThreadGoalClearResult> clearGoal({required String threadId}) async {
    return const ThreadGoalClearResult(cleared: false);
  }
}

class _FakeThreadReviewRunner implements ThreadReviewRunner {
  const _FakeThreadReviewRunner();

  @override
  Future<ThreadReviewStartResult> startReview({
    required String threadId,
    required ThreadReviewTarget target,
    ThreadReviewDelivery? delivery,
  }) async {
    return ThreadReviewStartResult(
      reviewThreadId: threadId,
      turn: TurnSummary.fromJson({
        'id': 'turn_review',
        'status': 'inProgress',
        'items': <Object?>[],
        'itemsView': 'notLoaded',
      }),
    );
  }
}

class _FakeAgentSnapshotReader implements AgentSnapshotReader {
  _FakeAgentSnapshotReader({required this.outcomes});

  final List<Object> outcomes;
  final profiles = <SshProfile>[];
  int _readCount = 0;

  @override
  Future<AgentSnapshot> readSnapshot(SshProfile profile) async {
    profiles.add(profile);
    final index = _readCount < outcomes.length
        ? _readCount
        : outcomes.length - 1;
    _readCount++;
    final outcome = outcomes[index];
    if (outcome is AgentSnapshot) {
      return outcome;
    }
    throw outcome;
  }
}

class _PendingAgentSnapshotReader implements AgentSnapshotReader {
  final profiles = <SshProfile>[];
  final _completers = <Completer<AgentSnapshot>>[];

  int get pendingCount => _completers.length;

  @override
  Future<AgentSnapshot> readSnapshot(SshProfile profile) {
    profiles.add(profile);
    final completer = Completer<AgentSnapshot>();
    _completers.add(completer);
    return completer.future;
  }

  void completeAt(int index, AgentSnapshot snapshot) {
    final completer = _completers[index];
    if (!completer.isCompleted) {
      completer.complete(snapshot);
    }
  }
}

class _FakeConnectionRecord {
  final _doneCompleter = Completer<void>();
  bool closed = false;

  Future<void> get done => _doneCompleter.future;

  void completeDone() {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }
}

class _FakeReconnectDelayScheduler implements ReconnectDelayScheduler {
  final delays = <Duration>[];
  final _waits = <Completer<void>>[];

  @override
  Future<void> wait(Duration delay) {
    delays.add(delay);
    final completer = Completer<void>();
    _waits.add(completer);
    return completer.future;
  }

  void completeNext() {
    if (_waits.isEmpty) {
      throw StateError('No reconnect wait is pending');
    }
    final completer = _waits.removeAt(0);
    if (!completer.isCompleted) {
      completer.complete();
    }
  }
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
