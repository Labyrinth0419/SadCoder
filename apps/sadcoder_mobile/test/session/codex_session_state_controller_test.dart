import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/account_logout_runner.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/agent/agent_snapshot.dart';
import 'package:sadcoder_mobile/src/agent/agent_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/apps/app_list_reader.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal_runner.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_manifest_reader.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_registry.dart';
import 'package:sadcoder_mobile/src/command_exec/codex_command_exec_runner.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/diffs/git_diff_reader.dart';
import 'package:sadcoder_mobile/src/environments/codex_environment_runner.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/events/guardian_assessment_event.dart';
import 'package:sadcoder_mobile/src/experimental_features/codex_experimental_feature_runner.dart';
import 'package:sadcoder_mobile/src/external_agents/codex_external_agent_config_runner.dart';
import 'package:sadcoder_mobile/src/feedback/feedback_upload_runner.dart';
import 'package:sadcoder_mobile/src/files/file_search_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_directory_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_kind.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_mutation_runner.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal_runner.dart';
import 'package:sadcoder_mobile/src/hooks/hook_list_reader.dart';
import 'package:sadcoder_mobile/src/hooks/codex_hook_mutation_runner.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_config_runner.dart';
import 'package:sadcoder_mobile/src/mcp/codex_mcp_resource_reader.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_oauth_runner.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_reader.dart';
import 'package:sadcoder_mobile/src/memories/codex_memory_runner.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_reader.dart';
import 'package:sadcoder_mobile/src/plugins/codex_marketplace_mutation_runner.dart';
import 'package:sadcoder_mobile/src/plugins/codex_plugin_skill_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_detail_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_list_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_mutation_runner.dart';
import 'package:sadcoder_mobile/src/processes/codex_process_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_session.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/realtime/codex_realtime_runner.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review_runner.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/reconnect_policy.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/session/session_heartbeat.dart';
import 'package:sadcoder_mobile/src/skills/skill_list_reader.dart';
import 'package:sadcoder_mobile/src/skills/codex_skill_mutation_runner.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_proxy_connector.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_item_cache_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_item_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_mutation_runner.dart';
import 'package:sadcoder_mobile/src/threads/codex_thread_shell_command_runner.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/threads/thread_turn_list_reader.dart';
import 'package:sadcoder_mobile/src/turns/turn_runner.dart';
import 'package:sadcoder_mobile/src/turns/turn_text_element.dart';
import 'package:sadcoder_mobile/src/usage/account_usage_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/windows_sandbox/codex_windows_sandbox_runner.dart';

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
    expect(controller.threadTurnListReader, isNotNull);
    expect(controller.threadItemListReader, isNotNull);
    expect(controller.configSnapshotReader, isNotNull);
    expect(controller.accountSnapshotReader, isNotNull);
    expect(controller.accountLogoutRunner, isNotNull);
    expect(controller.feedbackUploadRunner, isNotNull);
    expect(controller.gitDiffReader, isNotNull);
    expect(controller.fileSearchReader, isNotNull);
    expect(controller.workspaceDirectoryReader, isNotNull);
    expect(controller.workspaceFileReader, isNotNull);
    expect(controller.environmentRunner, isNotNull);
    expect(controller.mcpServerConfigRunner, isNotNull);
    expect(controller.mcpServerOAuthRunner, isNotNull);
    expect(controller.mcpResourceReader, isNotNull);
    expect(controller.modelListReader, isNotNull);
    expect(controller.permissionProfileListReader, isNotNull);
    expect(controller.skillListReader, isNotNull);
    expect(controller.skillMutationRunner, isNotNull);
    expect(controller.pluginListReader, isNotNull);
    expect(controller.pluginDetailReader, isNotNull);
    expect(controller.pluginSkillReader, isNotNull);
    expect(controller.pluginMutationRunner, isNotNull);
    expect(controller.hookListReader, isNotNull);
    expect(controller.hookMutationRunner, isNotNull);
    expect(controller.appListReader, isNotNull);
    expect(controller.slashCommandManifestReader, isNotNull);
    expect(controller.turnRunner, isNotNull);
    expect(controller.threadBackgroundTerminalRunner, isNotNull);
    expect(controller.threadReviewRunner, isNotNull);
    expect(connector.connectedProfiles, [_profile]);
    expect(approvalController.canRespond, true);
  });

  test('thread item reader caches pages per connected profile', () async {
    final approvalController = ApprovalStateController();
    final store = _RecordingThreadItemCacheStore();
    final connector = _FakeSessionStarter(
      threadItemListReaders: [
        _FakeThreadItemListReader(
          page: ThreadItemsPage(
            items: [_item('item_1')],
            nextCursor: 'older',
            backwardsCursor: 'newer',
          ),
        ),
      ],
    );
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
      threadItemCacheStore: store,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    await controller.connect(_profile);
    final page = await controller.threadItemListReader!.listItems(
      threadId: 'thr_1',
    );

    expect(page.items.single.id, 'item_1');
    final snapshot = store.snapshots['local::thr_1'];
    expect(snapshot, isNotNull);
    expect(snapshot!.items.single.id, 'item_1');
    expect(snapshot.nextCursor, 'older');
    expect(snapshot.backwardsCursor, 'newer');
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

  test('snapshot backfill prunes stale pending approvals', () async {
    final approvalController = ApprovalStateController(
      initialApprovals: const [
        PendingApproval(
          requestId: 'stale-approval',
          method: commandExecutionApprovalMethod,
          kind: PendingApprovalKind.commandExecution,
          rawParams: {},
        ),
      ],
    );
    final snapshotReader = _FakeAgentSnapshotReader(
      outcomes: [
        _snapshotWithApproval(
          requestId: 'current-approval',
          command: 'dart test',
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

    expect(approvalController.approvals.map((approval) => approval.requestId), [
      'current-approval',
    ]);
    expect(approvalController.approvals.single.command, 'dart test');
  });

  test(
    'snapshot backfill preserves approvals created while snapshot is pending',
    () async {
      final approvalController = ApprovalStateController(
        initialApprovals: const [
          PendingApproval(
            requestId: 'stale-before-snapshot',
            method: commandExecutionApprovalMethod,
            kind: PendingApprovalKind.commandExecution,
            rawParams: {},
          ),
        ],
      );
      final snapshotReader = _PendingAgentSnapshotReader();
      final controller = CodexSessionStateController(
        connector: _FakeSessionStarter(),
        approvalController: approvalController,
        snapshotReader: snapshotReader,
      );
      addTearDown(controller.dispose);
      addTearDown(approvalController.dispose);

      await controller.connect(_profile);
      await _flushMicrotasks();
      expect(snapshotReader.pendingCount, 1);

      approvalController.ingestServerRequests(const [
        JsonRpcServerRequest(
          id: 'live-during-snapshot',
          method: commandExecutionApprovalMethod,
          params: {'command': 'keep me'},
        ),
      ]);
      snapshotReader.completeAt(0, _emptySnapshot);
      await _flushMicrotasks();

      expect(
        approvalController.approvals.map((approval) => approval.requestId),
        ['live-during-snapshot'],
      );
      expect(approvalController.approvals.single.command, 'keep me');
    },
  );

  test(
    'connect prefers proxy agent snapshot over ssh snapshot command',
    () async {
      final approvalController = ApprovalStateController();
      final proxySnapshotReader = _FakeAgentSnapshotReader(
        outcomes: [
          _snapshotWithApproval(
            requestId: 'approval-from-proxy-snapshot',
            command: 'cargo test',
          ),
        ],
      );
      final sshSnapshotReader = _FakeAgentSnapshotReader(
        outcomes: [
          _snapshotWithApproval(
            requestId: 'approval-from-ssh-snapshot',
            command: 'dart test',
          ),
        ],
      );
      final controller = CodexSessionStateController(
        connector: _FakeSessionStarter(
          agentSnapshotReaders: [proxySnapshotReader],
        ),
        approvalController: approvalController,
        snapshotReader: sshSnapshotReader,
      );
      addTearDown(controller.dispose);
      addTearDown(approvalController.dispose);

      await controller.connect(_profile);
      await _flushMicrotasks();

      expect(proxySnapshotReader.profiles, [_profile]);
      expect(sshSnapshotReader.profiles, isEmpty);
      expect(
        approvalController.approvals.single.requestId,
        'approval-from-proxy-snapshot',
      );
      expect(approvalController.approvals.single.command, 'cargo test');
    },
  );

  test(
    'connect falls back to ssh agent snapshot when proxy snapshot fails',
    () async {
      final approvalController = ApprovalStateController();
      final proxySnapshotReader = _FakeAgentSnapshotReader(
        outcomes: [StateError('agent/snapshot failed')],
      );
      final sshSnapshotReader = _FakeAgentSnapshotReader(
        outcomes: [
          _snapshotWithApproval(
            requestId: 'approval-from-ssh-snapshot',
            command: 'dart test',
          ),
        ],
      );
      final controller = CodexSessionStateController(
        connector: _FakeSessionStarter(
          agentSnapshotReaders: [proxySnapshotReader],
        ),
        approvalController: approvalController,
        snapshotReader: sshSnapshotReader,
      );
      addTearDown(controller.dispose);
      addTearDown(approvalController.dispose);

      await controller.connect(_profile);
      await _flushMicrotasks();

      expect(proxySnapshotReader.profiles, [_profile]);
      expect(sshSnapshotReader.profiles, [_profile]);
      expect(
        approvalController.approvals.single.requestId,
        'approval-from-ssh-snapshot',
      );
      expect(approvalController.approvals.single.command, 'dart test');
    },
  );

  test('connect backfills tool user input from agent snapshot', () async {
    final approvalController = ApprovalStateController();
    final snapshotReader = _FakeAgentSnapshotReader(
      outcomes: [_snapshotWithToolUserInput()],
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

    final approval = approvalController.approvals.single;
    expect(approval.requestId, 'input-from-snapshot');
    expect(approval.kind, PendingApprovalKind.toolUserInput);
    expect(approval.threadId, 'thr_snapshot');
    expect(approval.toolUserInputAutoResolutionMs, 60000);
    expect(approval.toolUserInputQuestions.single.id, 'confirm_path');
    expect(
      approval.toolUserInputQuestions.single.options?.first.label,
      'Yes (Recommended)',
    );
    expect(approvalController.canRespond, true);
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

  test('connect publishes accepted agent snapshots', () async {
    final approvalController = ApprovalStateController();
    final snapshotReader = _FakeAgentSnapshotReader(
      outcomes: [
        _snapshotWithEvent(
          threadId: 'thr_snapshot',
          deliveredCursor: 'event-1',
        ),
      ],
    );
    final controller = CodexSessionStateController(
      connector: _FakeSessionStarter(),
      approvalController: approvalController,
      snapshotReader: snapshotReader,
    );
    final snapshots = <AgentSnapshot>[];
    final subscription = controller.agentSnapshots.listen(snapshots.add);
    addTearDown(subscription.cancel);
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    await controller.connect(_profile);
    await _flushMicrotasks();

    expect(snapshots, hasLength(1));
    expect(snapshots.single.deliveredCursor, 'event-1');
    expect(snapshots.single.recentEvents.single.cursor, 'event-1');
  });

  test(
    'connect passes snapshot cursor to connection snapshot reader',
    () async {
      final approvalController = ApprovalStateController();
      final snapshotReader = _FakeAgentSnapshotReader(
        outcomes: [
          _snapshotWithEvent(
            threadId: 'thr_snapshot',
            deliveredCursor: 'event-8',
          ),
        ],
      );
      final controller = CodexSessionStateController(
        connector: _FakeSessionStarter(agentSnapshotReaders: [snapshotReader]),
        approvalController: approvalController,
        snapshotCursorProvider: (_) => ' event-7 ',
      );
      addTearDown(controller.dispose);
      addTearDown(approvalController.dispose);

      await controller.connect(_profile);
      await _flushMicrotasks();

      expect(snapshotReader.sinceCursors, ['event-7']);
    },
  );

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

  test('restart backend reconnects the active profile', () async {
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
    await controller.restartBackend();

    expect(connector.connectedProfiles, [_profile, _profile]);
    expect(connector.connections.first.restartBackendCount, 1);
    expect(connector.closeCount, 1);
    expect(controller.status, CodexSessionStatus.connected);
    expect(controller.profile, _profile);
    expect(approvalController.approvals.single.requestId, 'approval-1');
    expect(approvalController.canRespond, true);
    expect(statuses, contains(CodexSessionStatus.reconnecting));
    expect(statuses, isNot(contains(CodexSessionStatus.disconnecting)));
  });

  test('stop backend closes the active profile without reconnecting', () async {
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
    await controller.stopBackend();
    connector.connections.first.completeDone();
    await _flushMicrotasks();

    expect(connector.connectedProfiles, [_profile]);
    expect(connector.connections.first.stopBackendCount, 1);
    expect(connector.closeCount, 1);
    expect(controller.status, CodexSessionStatus.idle);
    expect(controller.profile, _profile);
    expect(approvalController.approvals.single.requestId, 'approval-1');
    expect(approvalController.canRespond, false);
    expect(statuses, [
      CodexSessionStatus.connecting,
      CodexSessionStatus.connected,
      CodexSessionStatus.disconnecting,
      CodexSessionStatus.idle,
    ]);
  });

  test('requestRaw forwards through the active connection only', () async {
    final approvalController = ApprovalStateController();
    final connector = _FakeSessionStarter();
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    expect(
      () => controller.requestRaw(method: 'thread/custom'),
      throwsA(isA<StateError>()),
    );

    await controller.connect(_profile);
    final result = await controller.requestRaw(
      method: ' thread/custom ',
      params: {'threadId': 'thr_1'},
    );

    expect(result, {'method': 'thread/custom'});
    expect(connector.connections.single.requestMethods, ['thread/custom']);
  });

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
    'connection loss reconnects without clearing approvals or interrupting turns',
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
      expect(
        connector.connections.first.requestMethods,
        isNot(contains('turn/interrupt')),
      );

      scheduler.completeNext();
      await _flushMicrotasks();

      expect(controller.status, CodexSessionStatus.connected);
      expect(connector.connectedProfiles, [_profile, _profile]);
      expect(connector.closeCount, 1);
      expect(approvalController.approvals.single.requestId, 'approval-1');
      expect(approvalController.canRespond, true);
      expect(
        connector.connections
            .expand((connection) => connection.requestMethods)
            .toList(),
        isNot(contains('turn/interrupt')),
      );
      expect(statuses, contains(CodexSessionStatus.reconnecting));
      expect(statuses, isNot(contains(CodexSessionStatus.disconnecting)));

      await controller.turnRunner!.interruptTurn(
        threadId: 'thr_1',
        turnId: 'turn_1',
      );

      expect(
        connector.connections.last.requestMethods,
        contains('turn/interrupt'),
      );
    },
  );

  test(
    'layered heartbeats use independent intervals while connected',
    () async {
      final approvalController = ApprovalStateController();
      final threadListReader = _RecordingThreadListReader();
      final connector = _FakeSessionStarter(
        threadListReaders: [threadListReader],
      );
      final heartbeatScheduler = _ManualSessionHeartbeatScheduler();
      final controller = CodexSessionStateController(
        connector: connector,
        approvalController: approvalController,
        heartbeatChannels: _layeredHeartbeatChannels,
        heartbeatScheduler: heartbeatScheduler,
      );
      addTearDown(controller.dispose);
      addTearDown(approvalController.dispose);

      await controller.connect(_profile);
      await heartbeatScheduler.tick(index: 0);

      expect(heartbeatScheduler.handles, hasLength(2));
      expect(
        heartbeatScheduler.handles[0].interval,
        const Duration(seconds: 20),
      );
      expect(
        heartbeatScheduler.handles[1].interval,
        const Duration(seconds: 60),
      );
      expect(connector.connections.single.agentPingCount, 1);
      expect(threadListReader.limits, isEmpty);

      await heartbeatScheduler.tick(index: 1);

      expect(threadListReader.limits, [1]);
      expect(controller.status, CodexSessionStatus.connected);
    },
  );

  test(
    'heartbeat failure reconnects without clearing pending approvals',
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
      final connector = _FakeSessionStarter(
        pingOutcomes: [StateError('heartbeat failed')],
      );
      final heartbeatScheduler = _ManualSessionHeartbeatScheduler();
      final reconnectScheduler = _FakeReconnectDelayScheduler();
      final controller = CodexSessionStateController(
        connector: connector,
        approvalController: approvalController,
        heartbeatChannels: _layeredHeartbeatChannels,
        heartbeatScheduler: heartbeatScheduler,
        reconnectPolicy: const ReconnectPolicy.fixed(
          delays: [Duration(milliseconds: 1)],
        ),
        reconnectDelayScheduler: reconnectScheduler,
      );
      addTearDown(controller.dispose);
      addTearDown(approvalController.dispose);

      await controller.connect(_profile);
      await heartbeatScheduler.tick(index: 0);
      await _flushMicrotasks();

      expect(controller.status, CodexSessionStatus.reconnecting);
      expect(controller.error, isA<StateError>());
      expect(connector.closeCount, 1);
      expect(
        heartbeatScheduler.handles.take(2).every((handle) => handle.stopped),
        true,
      );
      expect(reconnectScheduler.delays, [const Duration(milliseconds: 1)]);
      expect(approvalController.approvals.single.requestId, 'approval-1');
      expect(approvalController.canRespond, false);

      reconnectScheduler.completeNext();
      await _flushMicrotasks();

      expect(controller.status, CodexSessionStatus.connected);
      expect(connector.connectedProfiles, [_profile, _profile]);
      expect(heartbeatScheduler.handles, hasLength(4));
      expect(
        heartbeatScheduler.handles.skip(2).every((handle) => !handle.stopped),
        true,
      );
      expect(approvalController.approvals.single.requestId, 'approval-1');
      expect(approvalController.canRespond, true);
    },
  );

  test('manual disconnect stops heartbeat ticks', () async {
    final approvalController = ApprovalStateController();
    final threadListReader = _RecordingThreadListReader();
    final connector = _FakeSessionStarter(
      threadListReaders: [threadListReader],
    );
    final heartbeatScheduler = _ManualSessionHeartbeatScheduler();
    final controller = CodexSessionStateController(
      connector: connector,
      approvalController: approvalController,
      heartbeatChannels: _layeredHeartbeatChannels,
      heartbeatScheduler: heartbeatScheduler,
    );
    addTearDown(controller.dispose);
    addTearDown(approvalController.dispose);

    await controller.connect(_profile);
    await controller.disconnect();
    await heartbeatScheduler.tick(index: 0);
    await heartbeatScheduler.tick(index: 1);

    expect(heartbeatScheduler.handles.every((handle) => handle.stopped), true);
    expect(connector.connections.single.agentPingCount, 0);
    expect(threadListReader.limits, isEmpty);
    expect(controller.status, CodexSessionStatus.idle);
  });

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
    final firstConnectionGeneration = controller.activeConnectionGeneration;
    connector.connections.single.completeDone();
    await _flushMicrotasks();

    expect(controller.status, CodexSessionStatus.reconnecting);
    expect(controller.activeConnectionGeneration, isNull);
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
    expect(
      controller.activeConnectionGeneration,
      greaterThan(firstConnectionGeneration!),
    );
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
    expect(controller.pluginDetailReader, isNull);
    expect(controller.pluginMutationRunner, isNull);
    expect(controller.hookListReader, isNull);
    expect(controller.appListReader, isNull);
    expect(controller.turnRunner, isNull);
    expect(connector.connectCount, 1);
    expect(connector.closeCount, 1);
    expect(approvalController.approvals.single.requestId, 'approval-1');
    expect(approvalController.canRespond, false);
  });

  test(
    'resumeConnection reconnects the preserved profile with backoff',
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

      await controller.connect(_profile);
      await controller.disconnect();

      expect(controller.status, CodexSessionStatus.idle);
      expect(controller.profile, _profile);

      await controller.resumeConnection();

      expect(controller.status, CodexSessionStatus.reconnecting);
      expect(controller.reconnectAttempt, 1);
      expect(scheduler.delays, [const Duration(milliseconds: 1)]);

      scheduler.completeNext();
      await _flushMicrotasks();

      expect(controller.status, CodexSessionStatus.connected);
      expect(controller.profile, _profile);
      expect(connector.connectedProfiles, [_profile, _profile]);
      expect(approvalController.approvals.single.requestId, 'approval-1');
      expect(approvalController.canRespond, true);
    },
  );
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

AgentSnapshot _snapshotWithToolUserInput() {
  return const AgentSnapshot(
    schemaVersion: 1,
    pendingApprovals: [
      JsonRpcServerRequest(
        id: 'input-from-snapshot',
        method: toolRequestUserInputMethod,
        params: {
          'threadId': 'thr_snapshot',
          'turnId': 'turn_snapshot',
          'itemId': 'item_snapshot',
          'autoResolutionMs': 60000,
          'questions': [
            {
              'id': 'confirm_path',
              'header': 'Confirm',
              'question': 'Proceed with the plan?',
              'isOther': true,
              'isSecret': false,
              'options': [
                {
                  'label': 'Yes (Recommended)',
                  'description': 'Continue the current plan.',
                },
                {
                  'label': 'No',
                  'description': 'Stop and revisit the approach.',
                },
              ],
            },
          ],
        },
      ),
    ],
    recentEvents: [],
  );
}

AgentSnapshot _snapshotWithEvent({
  required String threadId,
  String? deliveredCursor,
}) {
  return AgentSnapshot(
    schemaVersion: 1,
    pendingApprovals: const [],
    recentEvents: [_turnStartedCachedEvent(threadId, cursor: deliveredCursor)],
    deliveredCursor: deliveredCursor,
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

AgentCachedEvent _turnStartedCachedEvent(String threadId, {String? cursor}) {
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
    cursor: cursor,
  );
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

const _layeredHeartbeatChannels = [
  SessionHeartbeatChannel(
    runner: AgentPingSessionHeartbeatRunner(),
    interval: Duration(seconds: 20),
  ),
  SessionHeartbeatChannel(
    runner: ThreadListSessionHeartbeatRunner(),
    interval: Duration(seconds: 60),
  ),
];

class _FakeSessionStarter implements CodexSessionConnectionStarter {
  _FakeSessionStarter({
    this.failConnect = false,
    List<Object?>? connectOutcomes,
    List<Object?>? pingOutcomes,
    List<ThreadListReader>? threadListReaders,
    List<ThreadItemListReader>? threadItemListReaders,
    List<AgentSnapshotReader?>? agentSnapshotReaders,
  }) : connectOutcomes = connectOutcomes ?? const [],
       pingOutcomes = pingOutcomes ?? const [],
       threadListReaders = threadListReaders ?? const [],
       threadItemListReaders = threadItemListReaders ?? const [],
       agentSnapshotReaders = agentSnapshotReaders ?? const [];

  final bool failConnect;
  final List<Object?> connectOutcomes;
  final List<Object?> pingOutcomes;
  final List<ThreadListReader> threadListReaders;
  final List<ThreadItemListReader> threadItemListReaders;
  final List<AgentSnapshotReader?> agentSnapshotReaders;
  final connectedProfiles = <SshProfile>[];
  final connections = <_FakeConnectionRecord>[];
  int connectCount = 0;
  int closeCount = 0;

  @override
  Future<CodexSessionConnection> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    final connectionIndex = connectCount;
    final outcome = connectionIndex < connectOutcomes.length
        ? connectOutcomes[connectionIndex]
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
      MemoryJsonRpcTransport((request) async {
        record.requestMethods.add(request.method);
        if (request.method == 'agent/restartBackend') {
          record.restartBackendCount++;
          return {'reconnectRequired': true};
        }
        if (request.method == 'agent/stopBackend') {
          record.stopBackendCount++;
          return {'stopped': true};
        }
        if (request.method == 'agent/ping') {
          record.agentPingCount++;
          final pingOutcome = connectionIndex < pingOutcomes.length
              ? pingOutcomes[connectionIndex]
              : null;
          if (pingOutcome != null) {
            throw pingOutcome;
          }
          return {'ok': true};
        }
        return {'method': request.method};
      }),
      approvalController: approvalController,
    );
    return CodexSessionConnection(
      profile: profile,
      session: session,
      threadListReader: connectionIndex < threadListReaders.length
          ? threadListReaders[connectionIndex]
          : const _FakeThreadListReader(),
      threadDetailReader: const _FakeThreadDetailReader(),
      threadTurnListReader: const _NoopThreadTurnListReader(),
      threadItemListReader: connectionIndex < threadItemListReaders.length
          ? threadItemListReaders[connectionIndex]
          : const _NoopThreadItemListReader(),
      configSnapshotReader: const _FakeConfigSnapshotReader(),
      accountSnapshotReader: const _FakeAccountSnapshotReader(),
      accountLogoutRunner: const _FakeAccountLogoutRunner(),
      accountUsageSnapshotReader: const _FakeAccountUsageSnapshotReader(),
      feedbackUploadRunner: const _FakeFeedbackUploadRunner(),
      experimentalFeatureRunner: CodexExperimentalFeatureRunner(session.client),
      memoryRunner: CodexMemoryRunner(session.client),
      windowsSandboxRunner: CodexWindowsSandboxRunner(session.client),
      environmentRunner: CodexEnvironmentRunner(session.client),
      externalAgentConfigRunner: CodexExternalAgentConfigRunner(session.client),
      fileSearchReader: const _FakeFileSearchReader(),
      workspaceDirectoryReader: const _FakeWorkspaceDirectoryReader(),
      workspaceFileReader: const _FakeWorkspaceFileReader(),
      gitDiffReader: const _FakeGitDiffReader(),
      mcpServerConfigRunner: const _FakeMcpServerConfigRunner(),
      mcpServerOAuthRunner: const _FakeMcpServerOAuthRunner(),
      mcpServerStatusReader: const _FakeMcpServerStatusReader(),
      mcpResourceReader: CodexMcpResourceReader(session.client),
      modelListReader: const _FakeModelListReader(),
      permissionProfileListReader: const _FakePermissionProfileListReader(),
      skillListReader: const _FakeSkillListReader(),
      skillMutationRunner: CodexSkillMutationRunner(session.client),
      pluginListReader: const _FakePluginListReader(),
      pluginDetailReader: const _FakePluginDetailReader(),
      pluginSkillReader: CodexPluginSkillReader(session.client),
      pluginMutationRunner: const _FakePluginMutationRunner(),
      marketplaceMutationRunner: CodexMarketplaceMutationRunner(session.client),
      hookListReader: const _FakeHookListReader(),
      hookMutationRunner: CodexHookMutationRunner(session.client),
      realtimeRunner: CodexRealtimeRunner(
        client: session.client,
        events: session.events,
      ),
      workspaceFileMutationRunner: CodexWorkspaceFileMutationRunner(
        client: session.client,
        fileReader: const _FakeWorkspaceFileReader(),
        events: session.events,
      ),
      appListReader: const _FakeAppListReader(),
      slashCommandManifestReader: const _FakeSlashCommandManifestReader(),
      threadMutationRunner: const _FakeThreadMutationRunner(),
      threadShellCommandRunner: CodexThreadShellCommandRunner(session.client),
      commandExecRunner: CodexCommandExecRunner(session.client),
      processRunner: CodexProcessRunner(session.client),
      threadBackgroundTerminalRunner:
          const _FakeThreadBackgroundTerminalRunner(),
      threadGoalRunner: const _FakeThreadGoalRunner(),
      threadReviewRunner: const _FakeThreadReviewRunner(),
      turnRunner: _FakeTurnRunner(record),
      agentSnapshotReader: connectionIndex < agentSnapshotReaders.length
          ? agentSnapshotReaders[connectionIndex]
          : null,
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

class _FakeAccountLogoutRunner implements AccountLogoutRunner {
  const _FakeAccountLogoutRunner();

  @override
  Future<void> logout() async {}
}

class _FakeFeedbackUploadRunner implements FeedbackUploadRunner {
  const _FakeFeedbackUploadRunner();

  @override
  Future<FeedbackUploadResult> uploadFeedback({
    required String classification,
    String? reason,
    String? threadId,
    String? turnId,
    bool includeLogs = false,
  }) async {
    return const FeedbackUploadResult(threadId: 'feedback_thread');
  }
}

class _FakeGitDiffReader implements GitDiffReader {
  const _FakeGitDiffReader();

  @override
  Future<GitDiffResult> readDiff({String? cwd}) async {
    return const GitDiffResult(isGitRepository: true, stat: '', diff: '');
  }
}

class _FakeFileSearchReader implements FileSearchReader {
  const _FakeFileSearchReader();

  @override
  Future<FileSearchResultPage> searchFiles({
    required String query,
    List<String> roots = const [],
    String? cancellationToken,
  }) async {
    return const FileSearchResultPage(files: []);
  }
}

class _FakeWorkspaceDirectoryReader implements WorkspaceDirectoryReader {
  const _FakeWorkspaceDirectoryReader();

  @override
  Future<WorkspaceDirectoryPage> listDirectory({
    required String root,
    String path = '',
    int limit = 100,
    String? cursor,
    bool includeHidden = false,
  }) async {
    return WorkspaceDirectoryPage(root: root, path: path, entries: const []);
  }
}

class _FakeWorkspaceFileReader implements WorkspaceFileReader {
  const _FakeWorkspaceFileReader();

  @override
  Future<WorkspaceFileStat> statFile({
    required String root,
    required String path,
  }) async {
    return WorkspaceFileStat(
      root: root,
      path: path,
      kind: WorkspaceFileKind.file,
    );
  }

  @override
  Future<WorkspaceFileReadChunk> readFile({
    required String root,
    required String path,
    int offset = 0,
    int limitBytes = 64 * 1024,
    String encoding = 'utf-8',
  }) async {
    return WorkspaceFileReadChunk(
      root: root,
      path: path,
      sizeBytes: 0,
      offset: offset,
      bytesRead: 0,
      nextOffset: null,
      hasMore: false,
      encoding: encoding,
      isBinary: false,
      content: '',
    );
  }
}

class _FakeMcpServerConfigRunner implements McpServerConfigRunner {
  const _FakeMcpServerConfigRunner();

  @override
  Future<void> reloadMcpServers() async {}
}

class _FakeMcpServerOAuthRunner implements McpServerOAuthRunner {
  const _FakeMcpServerOAuthRunner();

  @override
  Future<McpServerOAuthLoginResult> startOAuthLogin({
    required String serverName,
  }) async {
    return McpServerOAuthLoginResult(
      serverName: serverName,
      raw: const <String, Object?>{},
    );
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
  Future<ModelListPage> listModels({
    String? cursor,
    int? limit,
    bool includeHidden = false,
  }) async {
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

class _FakePluginDetailReader implements PluginDetailReader {
  const _FakePluginDetailReader();

  @override
  Future<PluginDetail> readPlugin({required PluginCatalogTarget target}) async {
    return PluginDetail.fromJson(
      pluginId: target.plugin.id,
      json: {
        'plugin': {
          'summary': target.plugin.raw,
          'marketplaceName': target.marketplace.name,
        },
      },
    );
  }
}

class _FakePluginMutationRunner implements PluginMutationRunner {
  const _FakePluginMutationRunner();

  @override
  Future<PluginMutationResult> installPlugin({
    required PluginCatalogTarget target,
  }) async {
    return PluginMutationResult(
      operation: PluginMutationOperation.install,
      pluginId: target.plugin.id,
      raw: const <String, Object?>{},
    );
  }

  @override
  Future<PluginMutationResult> uninstallPlugin({
    required String pluginId,
  }) async {
    return PluginMutationResult(
      operation: PluginMutationOperation.uninstall,
      pluginId: pluginId,
      raw: const <String, Object?>{},
    );
  }
}

class _FakeHookListReader implements HookListReader {
  const _FakeHookListReader();

  @override
  Future<HookListPage> listHooks({List<String> cwds = const []}) async {
    return const HookListPage(entries: []);
  }
}

class _FakeAppListReader implements AppListReader {
  const _FakeAppListReader();

  @override
  Future<AppListPage> listApps({
    String? cursor,
    int? limit,
    String? threadId,
    bool forceRefetch = false,
  }) async {
    return const AppListPage(apps: []);
  }
}

class _FakeSlashCommandManifestReader implements SlashCommandManifestReader {
  const _FakeSlashCommandManifestReader();

  @override
  Future<SlashCommandManifest> readSlashCommands(SshProfile profile) async {
    return const SlashCommandManifest(
      schemaVersion: 1,
      source: 'test',
      commands: [],
    );
  }
}

class _FakeThreadListReader implements ThreadListReader {
  const _FakeThreadListReader();

  @override
  Future<ThreadListPage> listThreads({
    int limit = 20,
    bool archived = false,
  }) async {
    return const ThreadListPage(threads: []);
  }
}

class _RecordingThreadListReader implements ThreadListReader {
  final limits = <int>[];

  @override
  Future<ThreadListPage> listThreads({
    int limit = 20,
    bool archived = false,
  }) async {
    limits.add(limit);
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

class _NoopThreadTurnListReader implements ThreadTurnListReader {
  const _NoopThreadTurnListReader();

  @override
  Future<ThreadTurnsPage> listTurns({
    required String threadId,
    String? cursor,
    int? limit,
    String? sortDirection,
    String? itemsView,
  }) async {
    return const ThreadTurnsPage(turns: []);
  }
}

class _NoopThreadItemListReader implements ThreadItemListReader {
  const _NoopThreadItemListReader();

  @override
  Future<ThreadItemsPage> listItems({
    required String threadId,
    String? turnId,
    String? cursor,
    int? limit,
    String? sortDirection,
  }) async {
    return const ThreadItemsPage(items: []);
  }
}

class _FakeThreadItemListReader implements ThreadItemListReader {
  const _FakeThreadItemListReader({required this.page});

  final ThreadItemsPage page;

  @override
  Future<ThreadItemsPage> listItems({
    required String threadId,
    String? turnId,
    String? cursor,
    int? limit,
    String? sortDirection,
  }) async {
    return page;
  }
}

class _RecordingThreadItemCacheStore implements ThreadItemCacheStore {
  final snapshots = <String, ThreadItemCacheSnapshot>{};

  @override
  Future<ThreadItemCacheSnapshot?> loadThreadItems({
    required String profileId,
    required String threadId,
  }) async {
    return snapshots['$profileId::$threadId'];
  }

  @override
  Future<void> saveThreadItems({
    required String profileId,
    required String threadId,
    required ThreadItemCacheSnapshot snapshot,
  }) async {
    snapshots['$profileId::$threadId'] = snapshot;
  }
}

ThreadItemSummary _item(String id) {
  return ThreadItemSummary.fromJson({
    'id': id,
    'type': 'agentMessage',
    'text': 'Item $id',
  });
}

class _FakeTurnRunner implements TurnRunner {
  const _FakeTurnRunner([this.record]);

  final _FakeConnectionRecord? record;

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
    List<TurnTextElement> textElements = const [],
  }) async => TurnSummary.fromJson({
    'id': 'turn_1',
    'status': 'inProgress',
    'items': <Object?>[],
    'itemsView': 'notLoaded',
  });

  @override
  Future<String> steerTurn({
    required String threadId,
    required String turnId,
    required String text,
    List<TurnTextElement> textElements = const [],
  }) async => turnId;

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    record?.requestMethods.add('turn/interrupt');
  }
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
  Future<ThreadSummary> duplicateThread({required String threadId}) async {
    return ThreadSummary.fromJson({
      'id': 'thr_duplicate',
      'sessionId': 'sess_1',
      'preview': 'Duplicated thread',
      'ephemeral': false,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'forkedFromId': threadId,
    });
  }

  @override
  Future<ThreadSummary> rewindThread({
    required String threadId,
    required String lastTurnId,
  }) async {
    return ThreadSummary.fromJson({
      'id': 'thr_rewind',
      'sessionId': 'sess_1',
      'preview': 'Rewound thread',
      'ephemeral': false,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'forkedFromId': threadId,
    });
  }

  @override
  Future<ThreadSummary> startSideConversation({
    required String threadId,
  }) async {
    return ThreadSummary.fromJson({
      'id': 'thr_side',
      'sessionId': 'sess_1',
      'preview': 'Side thread',
      'ephemeral': true,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'forkedFromId': threadId,
    });
  }

  @override
  Future<void> compactThread({required String threadId}) async {}

  @override
  Future<void> updateThreadSettings({
    required String threadId,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
  }) async {}

  @override
  Future<void> approveGuardianDeniedAction({
    required String threadId,
    required GuardianAssessmentEvent event,
  }) async {}

  @override
  Future<void> setThreadName({
    required String threadId,
    required String name,
  }) async {}

  @override
  Future<void> archiveThread({required String threadId}) async {}

  @override
  Future<ThreadSummary> unarchiveThread({required String threadId}) async {
    return ThreadSummary.fromJson({
      'id': threadId,
      'sessionId': 'sess_1',
      'preview': 'Unarchived thread',
      'ephemeral': false,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
    });
  }

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
  final sinceCursors = <String?>[];
  int _readCount = 0;

  @override
  Future<AgentSnapshot> readSnapshot(
    SshProfile profile, {
    String? sinceCursor,
  }) async {
    profiles.add(profile);
    sinceCursors.add(sinceCursor);
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
  final sinceCursors = <String?>[];
  final _completers = <Completer<AgentSnapshot>>[];

  int get pendingCount => _completers.length;

  @override
  Future<AgentSnapshot> readSnapshot(
    SshProfile profile, {
    String? sinceCursor,
  }) {
    profiles.add(profile);
    sinceCursors.add(sinceCursor);
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
  final requestMethods = <String>[];
  bool closed = false;
  int agentPingCount = 0;
  int restartBackendCount = 0;
  int stopBackendCount = 0;

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

class _ManualSessionHeartbeatScheduler implements SessionHeartbeatScheduler {
  final handles = <_ManualSessionHeartbeatHandle>[];

  @override
  SessionHeartbeatHandle start({
    required Duration interval,
    required Future<void> Function() tick,
  }) {
    final handle = _ManualSessionHeartbeatHandle(
      interval: interval,
      tick: tick,
    );
    handles.add(handle);
    return handle;
  }

  Future<void> tick({int? index}) async {
    final handle = index == null ? handles.last : handles[index];
    await handle.tick();
  }
}

class _ManualSessionHeartbeatHandle implements SessionHeartbeatHandle {
  _ManualSessionHeartbeatHandle({
    required this.interval,
    required Future<void> Function() tick,
  }) : _tick = tick;

  final Duration interval;
  final Future<void> Function() _tick;
  bool stopped = false;

  Future<void> tick() async {
    if (stopped) {
      return;
    }
    await _tick();
  }

  @override
  void stop() {
    stopped = true;
  }
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
