import '../agent/agent_remote_service.dart';
import '../agent/agent_status.dart';
import '../accounts/account_snapshot_reader.dart';
import '../accounts/codex_account_snapshot_reader.dart';
import '../approvals/approval_state_controller.dart';
import '../config/codex_config_snapshot_reader.dart';
import '../config/codex_config_snapshot_remote_reader.dart';
import '../events/codex_event.dart';
import '../goals/codex_thread_goal_runner.dart';
import '../goals/thread_goal_runner.dart';
import '../mcp/codex_mcp_server_status_reader.dart';
import '../mcp/mcp_server_status_reader.dart';
import '../models/codex_model_list_reader.dart';
import '../models/model_list_reader.dart';
import '../permissions/codex_permission_profile_list_reader.dart';
import '../permissions/permission_profile_list_reader.dart';
import '../protocol/codex_app_session.dart';
import '../ssh/ssh_profile.dart';
import '../ssh/ssh_proxy_connector.dart';
import '../threads/codex_thread_mutation_runner.dart';
import '../threads/codex_thread_detail_reader.dart';
import '../threads/codex_thread_list_reader.dart';
import '../threads/thread_detail_reader.dart';
import '../threads/thread_list_reader.dart';
import '../threads/thread_mutation_runner.dart';
import '../turns/codex_turn_runner.dart';
import '../turns/turn_runner.dart';
import '../usage/account_usage_snapshot_reader.dart';
import '../usage/codex_account_usage_snapshot_reader.dart';

abstract interface class CodexSessionConnectionHandle {
  SshProfile get profile;

  ThreadListReader get threadListReader;

  ThreadDetailReader get threadDetailReader;

  CodexConfigSnapshotReader get configSnapshotReader;

  AccountSnapshotReader get accountSnapshotReader;

  AccountUsageSnapshotReader get accountUsageSnapshotReader;

  McpServerStatusReader get mcpServerStatusReader;

  ModelListReader get modelListReader;

  PermissionProfileListReader get permissionProfileListReader;

  ThreadMutationRunner get threadMutationRunner;

  ThreadGoalRunner get threadGoalRunner;

  TurnRunner get turnRunner;

  Stream<CodexEvent> get events;

  Future<void> get done;

  Future<void> close({bool notifyApprovalController = true});
}

abstract interface class CodexSessionConnectionStarter {
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  });
}

class CodexSessionConnector implements CodexSessionConnectionStarter {
  const CodexSessionConnector({
    required AgentProxyConnector proxyConnector,
    AgentStatusReader? statusReader,
    AgentStartRunner? startRunner,
    this.clientName = 'sadcoder-mobile',
    this.experimentalApi = true,
  }) : _proxyConnector = proxyConnector,
       _statusReader = statusReader,
       _startRunner = startRunner;

  final AgentProxyConnector _proxyConnector;
  final AgentStatusReader? _statusReader;
  final AgentStartRunner? _startRunner;
  final String clientName;
  final bool experimentalApi;

  @override
  Future<CodexSessionConnection> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    await _ensureBackendReady(profile);
    final proxyConnection = await _proxyConnector.connect(profile);
    CodexAppSession? session;
    try {
      session = CodexAppSession(
        proxyConnection.asJsonRpcTransport(),
        approvalController: approvalController,
      );
      await session.initialize(
        clientName: clientName,
        experimentalApi: experimentalApi,
      );
      return CodexSessionConnection(
        profile: profile,
        session: session,
        proxyConnection: proxyConnection,
        threadListReader: CodexThreadListReader(session.client),
        threadDetailReader: CodexThreadDetailReader(session.client),
        configSnapshotReader: CodexConfigSnapshotRemoteReader(session.client),
        accountSnapshotReader: CodexAccountSnapshotReader(session.client),
        accountUsageSnapshotReader: CodexAccountUsageSnapshotReader(
          session.client,
        ),
        mcpServerStatusReader: CodexMcpServerStatusReader(session.client),
        modelListReader: CodexModelListReader(session.client),
        permissionProfileListReader: CodexPermissionProfileListReader(
          session.client,
        ),
        threadMutationRunner: CodexThreadMutationRunner(session.client),
        threadGoalRunner: CodexThreadGoalRunner(session.client),
        turnRunner: CodexTurnRunner(session.client),
      );
    } catch (_) {
      await session?.close();
      await proxyConnection.close();
      rethrow;
    }
  }

  Future<void> _ensureBackendReady(SshProfile profile) async {
    final statusReader = _statusReader;
    if (statusReader == null) {
      return;
    }

    final status = await statusReader.readStatus(profile);
    if (status.backendState == BackendState.ready) {
      return;
    }

    final startRunner = _startRunner;
    if (status.backendState == BackendState.notStarted && startRunner != null) {
      final started = await startRunner.start(profile);
      if (started.backendState == BackendState.ready) {
        return;
      }
      throw StateError(_backendNotReadyMessage(started));
    }

    throw StateError(_backendNotReadyMessage(status));
  }

  String _backendNotReadyMessage(AgentStatus status) {
    final detail = status.backendDetail;
    if (detail == null || detail.trim().isEmpty) {
      return 'Codex backend is ${status.backendState.name}';
    }
    return 'Codex backend is ${status.backendState.name}: $detail';
  }
}

class CodexSessionConnection implements CodexSessionConnectionHandle {
  CodexSessionConnection({
    required this.profile,
    required this.session,
    required this.threadListReader,
    required this.threadDetailReader,
    required this.configSnapshotReader,
    required this.accountSnapshotReader,
    required this.accountUsageSnapshotReader,
    required this.mcpServerStatusReader,
    required this.modelListReader,
    required this.permissionProfileListReader,
    required this.threadMutationRunner,
    required this.threadGoalRunner,
    required this.turnRunner,
    required AgentProxyConnection proxyConnection,
  }) : _proxyConnection = proxyConnection,
       done = proxyConnection.done;

  @override
  final SshProfile profile;
  @override
  final Future<void> done;
  @override
  final ThreadListReader threadListReader;
  @override
  final ThreadDetailReader threadDetailReader;
  @override
  final CodexConfigSnapshotReader configSnapshotReader;
  @override
  final AccountSnapshotReader accountSnapshotReader;
  @override
  final AccountUsageSnapshotReader accountUsageSnapshotReader;
  @override
  final McpServerStatusReader mcpServerStatusReader;
  @override
  final ModelListReader modelListReader;
  @override
  final PermissionProfileListReader permissionProfileListReader;
  @override
  final ThreadMutationRunner threadMutationRunner;
  @override
  final ThreadGoalRunner threadGoalRunner;
  @override
  final TurnRunner turnRunner;
  @override
  Stream<CodexEvent> get events => session.events;
  final CodexAppSession session;
  final AgentProxyConnection _proxyConnection;
  bool _closed = false;

  @override
  Future<void> close({bool notifyApprovalController = true}) async {
    if (_closed) {
      return;
    }
    _closed = true;
    await session.close(notifyApprovalController: notifyApprovalController);
    await _proxyConnection.close();
  }
}
