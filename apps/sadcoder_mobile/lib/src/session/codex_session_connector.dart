import '../agent/agent_remote_service.dart';
import '../agent/agent_snapshot_reader.dart';
import '../agent/agent_status.dart';
import '../agent/codex_agent_snapshot_reader.dart';
import '../accounts/account_logout_runner.dart';
import '../background_terminals/codex_thread_background_terminal_runner.dart';
import '../background_terminals/thread_background_terminal_runner.dart';
import '../accounts/account_snapshot_reader.dart';
import '../accounts/codex_account_logout_runner.dart';
import '../accounts/codex_account_snapshot_reader.dart';
import '../apps/app_list_reader.dart';
import '../apps/codex_app_list_reader.dart';
import '../approvals/approval_state_controller.dart';
import '../commands/codex_slash_command_manifest_reader.dart';
import '../commands/slash_command_manifest_reader.dart';
import '../collaboration_modes/codex_collaboration_mode_list_reader.dart';
import '../collaboration_modes/collaboration_mode_list_reader.dart';
import '../command_exec/codex_command_exec_runner.dart';
import '../command_exec/command_exec_runner.dart';
import '../config/codex_config_snapshot_reader.dart';
import '../config/codex_config_snapshot_remote_reader.dart';
import '../diffs/codex_git_diff_reader.dart';
import '../diffs/git_diff_reader.dart';
import '../environments/codex_environment_runner.dart';
import '../environments/environment_runner.dart';
import '../events/codex_event.dart';
import '../experimental_features/codex_experimental_feature_runner.dart';
import '../experimental_features/experimental_feature_runner.dart';
import '../external_agents/codex_external_agent_config_runner.dart';
import '../external_agents/external_agent_config_runner.dart';
import '../feedback/codex_feedback_upload_runner.dart';
import '../feedback/feedback_upload_runner.dart';
import '../files/codex_file_search_reader.dart';
import '../files/codex_workspace_directory_reader.dart';
import '../files/codex_workspace_file_reader.dart';
import '../files/workspace_file_mutation_runner.dart';
import '../files/file_search_reader.dart';
import '../files/workspace_directory_reader.dart';
import '../files/workspace_file_reader.dart';
import '../goals/codex_thread_goal_runner.dart';
import '../goals/thread_goal_runner.dart';
import '../hooks/codex_hook_list_reader.dart';
import '../hooks/codex_hook_mutation_runner.dart';
import '../hooks/hook_list_reader.dart';
import '../hooks/hook_mutation_runner.dart';
import '../mcp/codex_mcp_server_config_runner.dart';
import '../mcp/codex_mcp_server_oauth_runner.dart';
import '../mcp/codex_mcp_server_status_reader.dart';
import '../mcp/mcp_server_config_runner.dart';
import '../mcp/mcp_server_oauth_runner.dart';
import '../mcp/mcp_server_status_reader.dart';
import '../memories/codex_memory_runner.dart';
import '../memories/memory_runner.dart';
import '../models/codex_model_list_reader.dart';
import '../models/model_list_reader.dart';
import '../permissions/codex_permission_profile_list_reader.dart';
import '../permissions/permission_profile_list_reader.dart';
import '../plugins/codex_marketplace_mutation_runner.dart';
import '../plugins/codex_plugin_list_reader.dart';
import '../plugins/codex_plugin_detail_reader.dart';
import '../plugins/codex_plugin_mutation_runner.dart';
import '../plugins/plugin_detail_reader.dart';
import '../plugins/plugin_list_reader.dart';
import '../plugins/marketplace_mutation_runner.dart';
import '../plugins/plugin_mutation_runner.dart';
import '../processes/codex_process_runner.dart';
import '../processes/process_runner.dart';
import '../protocol/codex_app_session.dart';
import '../protocol/codex_client_info.dart';
import '../protocol/json_rpc_diagnostic_log.dart';
import '../reviews/codex_thread_review_runner.dart';
import '../reviews/thread_review_runner.dart';
import '../realtime/codex_realtime_runner.dart';
import '../realtime/realtime_runner.dart';
import '../skills/codex_skill_list_reader.dart';
import '../skills/codex_skill_mutation_runner.dart';
import '../skills/skill_list_reader.dart';
import '../skills/skill_mutation_runner.dart';
import '../ssh/ssh_profile.dart';
import '../ssh/ssh_proxy_connector.dart';
import '../threads/codex_thread_mutation_runner.dart';
import '../threads/codex_thread_shell_command_runner.dart';
import '../threads/codex_thread_detail_reader.dart';
import '../threads/codex_thread_item_list_reader.dart';
import '../threads/codex_thread_list_reader.dart';
import '../threads/codex_thread_turn_list_reader.dart';
import '../threads/thread_detail_reader.dart';
import '../threads/thread_item_list_reader.dart';
import '../threads/thread_list_reader.dart';
import '../threads/thread_mutation_runner.dart';
import '../threads/thread_shell_command_runner.dart';
import '../threads/thread_turn_list_reader.dart';
import '../turns/codex_turn_runner.dart';
import '../turns/turn_runner.dart';
import '../usage/account_usage_snapshot_reader.dart';
import '../usage/codex_account_usage_snapshot_reader.dart';
import '../workspace/codex_workspace_command_runner.dart';
import '../windows_sandbox/codex_windows_sandbox_runner.dart';
import '../windows_sandbox/windows_sandbox_runner.dart';

abstract interface class CodexSessionConnectionHandle {
  SshProfile get profile;

  ThreadListReader get threadListReader;

  ThreadDetailReader get threadDetailReader;

  ThreadTurnListReader get threadTurnListReader;

  ThreadItemListReader get threadItemListReader;

  CodexConfigSnapshotReader get configSnapshotReader;

  AccountSnapshotReader get accountSnapshotReader;

  AccountLogoutRunner get accountLogoutRunner;

  AccountUsageSnapshotReader get accountUsageSnapshotReader;

  FeedbackUploadRunner get feedbackUploadRunner;

  GitDiffReader get gitDiffReader;

  FileSearchReader get fileSearchReader;

  WorkspaceDirectoryReader get workspaceDirectoryReader;

  WorkspaceFileReader get workspaceFileReader;

  McpServerConfigRunner get mcpServerConfigRunner;

  McpServerOAuthRunner get mcpServerOAuthRunner;

  McpServerStatusReader get mcpServerStatusReader;

  ModelListReader get modelListReader;

  PermissionProfileListReader get permissionProfileListReader;

  SkillListReader get skillListReader;

  PluginListReader get pluginListReader;

  PluginDetailReader get pluginDetailReader;

  PluginMutationRunner get pluginMutationRunner;

  HookListReader get hookListReader;

  AppListReader get appListReader;

  SlashCommandManifestReader get slashCommandManifestReader;

  ThreadMutationRunner get threadMutationRunner;

  ThreadBackgroundTerminalRunner get threadBackgroundTerminalRunner;

  ThreadGoalRunner get threadGoalRunner;

  ThreadReviewRunner get threadReviewRunner;

  TurnRunner get turnRunner;

  List<JsonRpcDiagnosticLogEntry> get diagnosticLogs;

  Stream<CodexEvent> get events;

  Future<void> get done;

  Future<Map<String, Object?>> agentPing();

  Future<Map<String, Object?>> requestRaw({
    required String method,
    Map<String, Object?>? params,
  });

  Future<Map<String, Object?>> restartBackend();

  Future<Map<String, Object?>> stopBackend();

  Future<void> close({bool notifyApprovalController = true});
}

abstract interface class AgentSnapshotConnectionHandle {
  AgentSnapshotReader? get agentSnapshotReader;
}

abstract interface class ThreadShellCommandConnectionHandle {
  ThreadShellCommandRunner get threadShellCommandRunner;
}

abstract interface class CommandExecConnectionHandle {
  CommandExecRunner get commandExecRunner;
}

abstract interface class ProcessConnectionHandle {
  ProcessRunner get processRunner;
}

abstract interface class ExternalAgentConfigConnectionHandle {
  ExternalAgentConfigRunner get externalAgentConfigRunner;
}

abstract interface class ExperimentalFeatureConnectionHandle {
  ExperimentalFeatureRunner get experimentalFeatureRunner;
}

abstract interface class CollaborationModeConnectionHandle {
  CollaborationModeListReader? get collaborationModeListReader;
}

abstract interface class MemoryConnectionHandle {
  MemoryRunner get memoryRunner;
}

abstract interface class WindowsSandboxConnectionHandle {
  WindowsSandboxRunner get windowsSandboxRunner;
}

abstract interface class MarketplaceMutationConnectionHandle {
  MarketplaceMutationRunner get marketplaceMutationRunner;
}

abstract interface class EnvironmentConnectionHandle {
  EnvironmentRunner get environmentRunner;
}

abstract interface class HookMutationConnectionHandle {
  HookMutationRunner get hookMutationRunner;
}

abstract interface class SkillMutationConnectionHandle {
  SkillMutationRunner get skillMutationRunner;
}

abstract interface class RealtimeConnectionHandle {
  RealtimeRunner get realtimeRunner;
}

abstract interface class WorkspaceFileMutationConnectionHandle {
  WorkspaceFileMutationRunner get workspaceFileMutationRunner;
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
    this.clientName = sadcoderMobileClientName,
    this.clientVersion = sadcoderMobileClientVersion,
    this.experimentalApi = true,
  }) : _proxyConnector = proxyConnector,
       _statusReader = statusReader,
       _startRunner = startRunner;

  final AgentProxyConnector _proxyConnector;
  final AgentStatusReader? _statusReader;
  final AgentStartRunner? _startRunner;
  final String clientName;
  final String clientVersion;
  final bool experimentalApi;

  @override
  Future<CodexSessionConnection> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    await _ensureBackendReady(profile);
    final proxyConnection = await _proxyConnector.connect(profile);
    final diagnosticLogBuffer = RedactingJsonRpcDiagnosticLogBuffer();
    CodexAppSession? session;
    try {
      session = CodexAppSession(
        proxyConnection.asJsonRpcTransport(
          diagnosticLogSink: diagnosticLogBuffer,
        ),
        approvalController: approvalController,
      );
      await session.client.agentHello();
      await session.initialize(
        clientName: clientName,
        clientVersion: clientVersion,
        experimentalApi: experimentalApi,
      );
      final workspaceFileReader = CodexWorkspaceFileReader(session.client);
      final workspaceFileMutationRunner = CodexWorkspaceFileMutationRunner(
        client: session.client,
        fileReader: workspaceFileReader,
        events: session.events,
      );
      return CodexSessionConnection(
        profile: profile,
        session: session,
        proxyConnection: proxyConnection,
        threadListReader: CodexThreadListReader(session.client),
        threadDetailReader: CodexThreadDetailReader(session.client),
        threadTurnListReader: CodexThreadTurnListReader(session.client),
        threadItemListReader: CodexThreadItemListReader(session.client),
        configSnapshotReader: CodexConfigSnapshotRemoteReader(session.client),
        accountSnapshotReader: CodexAccountSnapshotReader(session.client),
        accountLogoutRunner: CodexAccountLogoutRunner(session.client),
        accountUsageSnapshotReader: CodexAccountUsageSnapshotReader(
          session.client,
        ),
        feedbackUploadRunner: CodexFeedbackUploadRunner(session.client),
        experimentalFeatureRunner: CodexExperimentalFeatureRunner(
          session.client,
        ),
        collaborationModeListReader: CodexCollaborationModeListReader(
          session.client,
        ),
        memoryRunner: CodexMemoryRunner(session.client),
        windowsSandboxRunner: CodexWindowsSandboxRunner(session.client),
        environmentRunner: CodexEnvironmentRunner(session.client),
        externalAgentConfigRunner: CodexExternalAgentConfigRunner(
          session.client,
        ),
        fileSearchReader: CodexFileSearchReader(session.client),
        workspaceDirectoryReader: CodexWorkspaceDirectoryReader(session.client),
        workspaceFileReader: workspaceFileReader,
        workspaceFileMutationRunner: workspaceFileMutationRunner,
        gitDiffReader: CodexGitDiffReader(
          CodexWorkspaceCommandRunner(session.client),
        ),
        mcpServerConfigRunner: CodexMcpServerConfigRunner(session.client),
        mcpServerOAuthRunner: CodexMcpServerOAuthRunner(session.client),
        mcpServerStatusReader: CodexMcpServerStatusReader(session.client),
        modelListReader: CodexModelListReader(session.client),
        permissionProfileListReader: CodexPermissionProfileListReader(
          session.client,
        ),
        skillListReader: CodexSkillListReader(session.client),
        skillMutationRunner: CodexSkillMutationRunner(session.client),
        pluginListReader: CodexPluginListReader(session.client),
        pluginDetailReader: CodexPluginDetailReader(session.client),
        pluginMutationRunner: CodexPluginMutationRunner(session.client),
        marketplaceMutationRunner: CodexMarketplaceMutationRunner(
          session.client,
        ),
        hookListReader: CodexHookListReader(session.client),
        hookMutationRunner: CodexHookMutationRunner(session.client),
        realtimeRunner: CodexRealtimeRunner(
          client: session.client,
          events: session.events,
        ),
        appListReader: CodexAppListReader(session.client),
        slashCommandManifestReader: CodexSlashCommandManifestReader(
          session.client,
        ),
        threadMutationRunner: CodexThreadMutationRunner(session.client),
        threadShellCommandRunner: CodexThreadShellCommandRunner(session.client),
        commandExecRunner: CodexCommandExecRunner(session.client),
        processRunner: CodexProcessRunner(session.client),
        threadBackgroundTerminalRunner: CodexThreadBackgroundTerminalRunner(
          session.client,
        ),
        threadGoalRunner: CodexThreadGoalRunner(session.client),
        threadReviewRunner: CodexThreadReviewRunner(session.client),
        turnRunner: CodexTurnRunner(session.client),
        agentSnapshotReader: CodexAgentSnapshotReader(session.client),
        diagnosticLogBuffer: diagnosticLogBuffer,
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
    if (!status.codexAvailable) {
      throw StateError(_backendNotReadyMessage(status));
    }
    if (status.backendState == BackendState.ready) {
      return;
    }

    final startRunner = _startRunner;
    if (status.backendState == BackendState.notStarted && startRunner != null) {
      final started = await startRunner.start(profile);
      if (!started.codexAvailable) {
        throw StateError(_backendNotReadyMessage(started));
      }
      if (started.backendState == BackendState.ready) {
        return;
      }
      throw StateError(_backendNotReadyMessage(started));
    }

    throw StateError(_backendNotReadyMessage(status));
  }

  String _backendNotReadyMessage(AgentStatus status) {
    if (!status.codexAvailable) {
      final failure = status.codexFailure?.message.trim();
      if (failure != null && failure.isNotEmpty) {
        return 'Codex is unavailable: $failure';
      }
      return 'Codex is unavailable: ${status.codexPath}';
    }
    final detail = status.backendDetail;
    if (detail == null || detail.trim().isEmpty) {
      return 'Codex backend is ${status.backendState.name}';
    }
    return 'Codex backend is ${status.backendState.name}: $detail';
  }
}

class CodexSessionConnection
    implements
        CodexSessionConnectionHandle,
        AgentSnapshotConnectionHandle,
        ThreadShellCommandConnectionHandle,
        CommandExecConnectionHandle,
        ProcessConnectionHandle,
        ExternalAgentConfigConnectionHandle,
        ExperimentalFeatureConnectionHandle,
        CollaborationModeConnectionHandle,
        MemoryConnectionHandle,
        WindowsSandboxConnectionHandle,
        MarketplaceMutationConnectionHandle,
        EnvironmentConnectionHandle,
        HookMutationConnectionHandle,
        SkillMutationConnectionHandle,
        RealtimeConnectionHandle,
        WorkspaceFileMutationConnectionHandle {
  CodexSessionConnection({
    required this.profile,
    required this.session,
    required this.threadListReader,
    required this.threadDetailReader,
    required this.threadTurnListReader,
    required this.threadItemListReader,
    required this.configSnapshotReader,
    required this.accountSnapshotReader,
    required this.accountLogoutRunner,
    required this.accountUsageSnapshotReader,
    required this.feedbackUploadRunner,
    required this.experimentalFeatureRunner,
    this.collaborationModeListReader,
    required this.memoryRunner,
    required this.windowsSandboxRunner,
    required this.environmentRunner,
    required this.hookMutationRunner,
    required this.skillMutationRunner,
    required this.realtimeRunner,
    required this.workspaceFileMutationRunner,
    required this.externalAgentConfigRunner,
    required this.fileSearchReader,
    required this.workspaceDirectoryReader,
    required this.workspaceFileReader,
    required this.gitDiffReader,
    required this.mcpServerConfigRunner,
    required this.mcpServerOAuthRunner,
    required this.mcpServerStatusReader,
    required this.modelListReader,
    required this.permissionProfileListReader,
    required this.skillListReader,
    required this.pluginListReader,
    required this.pluginDetailReader,
    required this.pluginMutationRunner,
    required this.marketplaceMutationRunner,
    required this.hookListReader,
    required this.appListReader,
    required this.slashCommandManifestReader,
    required this.threadMutationRunner,
    required this.threadShellCommandRunner,
    required this.commandExecRunner,
    required this.processRunner,
    required this.threadBackgroundTerminalRunner,
    required this.threadGoalRunner,
    required this.threadReviewRunner,
    required this.turnRunner,
    this.agentSnapshotReader,
    required AgentProxyConnection proxyConnection,
    RedactingJsonRpcDiagnosticLogBuffer? diagnosticLogBuffer,
  }) : _proxyConnection = proxyConnection,
       _diagnosticLogBuffer =
           diagnosticLogBuffer ??
           RedactingJsonRpcDiagnosticLogBuffer(maxEntries: 0),
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
  final ThreadTurnListReader threadTurnListReader;
  @override
  final ThreadItemListReader threadItemListReader;
  @override
  final CodexConfigSnapshotReader configSnapshotReader;
  @override
  final AccountSnapshotReader accountSnapshotReader;
  @override
  final AccountLogoutRunner accountLogoutRunner;
  @override
  final AccountUsageSnapshotReader accountUsageSnapshotReader;
  @override
  final FeedbackUploadRunner feedbackUploadRunner;
  @override
  final ExperimentalFeatureRunner experimentalFeatureRunner;
  @override
  final CollaborationModeListReader? collaborationModeListReader;
  @override
  final MemoryRunner memoryRunner;
  @override
  final WindowsSandboxRunner windowsSandboxRunner;
  @override
  final EnvironmentRunner environmentRunner;
  @override
  final ExternalAgentConfigRunner externalAgentConfigRunner;
  @override
  final FileSearchReader fileSearchReader;
  @override
  final WorkspaceDirectoryReader workspaceDirectoryReader;
  @override
  final WorkspaceFileReader workspaceFileReader;
  @override
  final GitDiffReader gitDiffReader;
  @override
  final McpServerConfigRunner mcpServerConfigRunner;
  @override
  final McpServerOAuthRunner mcpServerOAuthRunner;
  @override
  final McpServerStatusReader mcpServerStatusReader;
  @override
  final ModelListReader modelListReader;
  @override
  final PermissionProfileListReader permissionProfileListReader;
  @override
  final SkillListReader skillListReader;
  @override
  final PluginListReader pluginListReader;
  @override
  final PluginDetailReader pluginDetailReader;
  @override
  final PluginMutationRunner pluginMutationRunner;
  @override
  final MarketplaceMutationRunner marketplaceMutationRunner;
  @override
  final HookListReader hookListReader;
  @override
  final HookMutationRunner hookMutationRunner;
  @override
  final SkillMutationRunner skillMutationRunner;
  @override
  final RealtimeRunner realtimeRunner;
  @override
  final WorkspaceFileMutationRunner workspaceFileMutationRunner;
  @override
  final AppListReader appListReader;
  @override
  final SlashCommandManifestReader slashCommandManifestReader;
  @override
  final ThreadMutationRunner threadMutationRunner;
  @override
  final ThreadShellCommandRunner threadShellCommandRunner;
  @override
  final CommandExecRunner commandExecRunner;
  @override
  final ProcessRunner processRunner;
  @override
  final ThreadBackgroundTerminalRunner threadBackgroundTerminalRunner;
  @override
  final ThreadGoalRunner threadGoalRunner;
  @override
  final ThreadReviewRunner threadReviewRunner;
  @override
  final TurnRunner turnRunner;
  @override
  final AgentSnapshotReader? agentSnapshotReader;
  @override
  List<JsonRpcDiagnosticLogEntry> get diagnosticLogs {
    return _diagnosticLogBuffer.snapshot();
  }

  @override
  Stream<CodexEvent> get events => session.events;
  final CodexAppSession session;
  final AgentProxyConnection _proxyConnection;
  final RedactingJsonRpcDiagnosticLogBuffer _diagnosticLogBuffer;
  bool _closed = false;

  @override
  Future<Map<String, Object?>> agentPing() {
    return session.client.agentPing();
  }

  @override
  Future<Map<String, Object?>> requestRaw({
    required String method,
    Map<String, Object?>? params,
  }) {
    return session.client.requestRaw(method: method, params: params);
  }

  @override
  Future<Map<String, Object?>> restartBackend() {
    return session.client.agentRestartBackend();
  }

  @override
  Future<Map<String, Object?>> stopBackend() {
    return session.client.agentStopBackend();
  }

  @override
  Future<void> close({bool notifyApprovalController = true}) async {
    if (_closed) {
      return;
    }
    _closed = true;
    await workspaceFileMutationRunner.close();
    await session.close(notifyApprovalController: notifyApprovalController);
    await _proxyConnection.close();
  }
}
