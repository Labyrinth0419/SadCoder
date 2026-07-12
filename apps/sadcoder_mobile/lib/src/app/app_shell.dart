import 'dart:async';

import 'package:flutter/material.dart';

import '../accounts/account_snapshot_controller.dart';
import '../agent/agent_codex_configure_controller.dart';
import '../agent/agent_doctor_controller.dart';
import '../agent/agent_logs_controller.dart';
import '../agent/agent_remote_service.dart';
import '../agent/agent_schema_controller.dart';
import '../appearance/app_appearance_controller.dart';
import '../approvals/approval_state_controller.dart';
import '../background/background_connection_policy.dart';
import '../background/background_notification_router.dart';
import '../commands/slash_command_manifest_reader.dart';
import '../config/codex_config_override_controller.dart';
import '../config/codex_config_snapshot_controller.dart';
import '../diagnostics/diagnostic_log_export_controller.dart';
import '../features/approvals/approvals_page.dart';
import '../features/chat/chat_page.dart';
import '../features/chat/chat_timeline_controller.dart';
import '../features/files/workspace_files_page.dart';
import '../features/hosts/hosts_page.dart';
import '../features/settings/settings_page.dart';
import '../i18n/app_localizations.dart';
import '../mcp/mcp_server_status_controller.dart';
import '../models/model_list_controller.dart';
import '../permissions/permission_profile_list_controller.dart';
import '../session/codex_session_connector.dart';
import '../session/codex_session_state_controller.dart';
import '../session/host_session_manager.dart';
import '../session/host_session_summary.dart';
import '../session/session_heartbeat.dart';
import '../ssh/dart_ssh_proxy_connector.dart';
import '../ssh/dart_ssh_remote_command_runner.dart';
import '../ssh/ssh_profile.dart';
import '../ssh/ssh_profile_store.dart';
import '../threads/thread_cache_store.dart';
import '../threads/thread_detail_controller.dart';
import '../threads/thread_item_cache_store.dart';
import '../threads/thread_list_controller.dart';
import '../threads/thread_timeline_cursor_store.dart';
import '../turns/turn_controller.dart';
import '../usage/account_usage_snapshot_controller.dart';
import 'agent_snapshot_cursor_provider.dart';
import 'app_background_notification_coordinator.dart';
import 'app_host_session_ui_state.dart';

const _defaultSessionConnector = CodexSessionConnector(
  proxyConnector: DartSshProxyConnector(),
  statusReader: _defaultAgentRemoteService,
  startRunner: _defaultAgentRemoteService,
);
const _defaultAgentRemoteService = AgentRemoteService(
  DartSshRemoteCommandRunner(),
);

CodexSessionStateController _createDefaultSessionController(
  ApprovalStateController approvalController,
  ThreadItemCacheStore threadItemCacheStore, {
  AgentSnapshotCursorProvider? snapshotCursorProvider,
}) {
  return CodexSessionStateController(
    connector: _defaultSessionConnector,
    approvalController: approvalController,
    snapshotReader: _defaultAgentRemoteService,
    snapshotCursorProvider: snapshotCursorProvider,
    threadItemCacheStore: threadItemCacheStore,
    heartbeatChannels: const [
      SessionHeartbeatChannel(
        runner: AgentPingSessionHeartbeatRunner(),
        interval: Duration(seconds: 20),
      ),
      SessionHeartbeatChannel(
        runner: ThreadListSessionHeartbeatRunner(),
        interval: Duration(seconds: 60),
      ),
    ],
  );
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.appearanceController,
    this.approvalController,
    this.sessionController,
    this.hostSessionManager,
    this.configOverrideController,
    this.backgroundConnectionPreferences,
    this.backgroundConnectionKeeper,
    this.backgroundNotificationRouter,
    this.profileStore,
    this.slashCommandManifestReader,
    this.threadCacheStore,
    this.threadItemCacheStore,
    this.threadTimelineCursorStore,
  });

  final AppAppearanceController? appearanceController;
  final ApprovalStateController? approvalController;
  final CodexSessionStateController? sessionController;
  final HostSessionManager? hostSessionManager;
  final CodexConfigOverrideController? configOverrideController;
  final BackgroundConnectionPreferences? backgroundConnectionPreferences;
  final BackgroundConnectionKeeper? backgroundConnectionKeeper;
  final BackgroundNotificationRouter? backgroundNotificationRouter;
  final SshProfileStore? profileStore;
  final SlashCommandManifestReader? slashCommandManifestReader;
  final ThreadCacheStore? threadCacheStore;
  final ThreadItemCacheStore? threadItemCacheStore;
  final ThreadTimelineCursorStore? threadTimelineCursorStore;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  late ApprovalStateController _approvalController;
  late CodexSessionStateController _sessionController;
  late AppHostSessionUiState _activeUiState;
  final Map<String, AppHostSessionUiState> _hostUiStates = {};
  late CodexConfigOverrideController _configOverrideController;
  late CodexConfigSnapshotController _configSnapshotController;
  late AccountSnapshotController _accountSnapshotController;
  late AccountUsageSnapshotController _accountUsageSnapshotController;
  late AgentCodexConfigureController _agentCodexConfigureController;
  late AgentDoctorController _agentDoctorController;
  late AgentLogsController _agentLogsController;
  late AgentSchemaController _agentSchemaController;
  late McpServerStatusController _mcpServerStatusController;
  late ModelListController _modelListController;
  late PermissionProfileListController _permissionProfileListController;
  late BackgroundConnectionPreferences _backgroundConnectionPreferences;
  late DiagnosticLogExportController _diagnosticLogExportController;
  HostSessionManager? _hostSessionManager;
  AppLifecycleConnectionCoordinator? _lifecycleConnectionCoordinator;
  AppBackgroundNotificationCoordinator? _backgroundNotificationCoordinator;
  late bool _ownsHostSessionManager;
  late bool _ownsApprovalController;
  late bool _ownsSessionController;
  late bool _ownsConfigOverrideController;
  late bool _ownsBackgroundConnectionPreferences;

  ThreadListController get _threadListController =>
      _activeUiState.threadListController;
  ThreadDetailController get _threadDetailController =>
      _activeUiState.threadDetailController;
  TurnController get _turnController => _activeUiState.turnController;
  ChatTimelineController get _timelineController =>
      _activeUiState.timelineController;
  SlashCommandManifestReader? get _resolvedSlashCommandManifestReader {
    final injectedReader = widget.slashCommandManifestReader;
    if (injectedReader != null) {
      return injectedReader;
    }
    if (widget.sessionController != null || widget.hostSessionManager != null) {
      return null;
    }
    return _defaultAgentRemoteService;
  }

  ThreadCacheStore get _resolvedThreadCacheStore {
    return widget.threadCacheStore ?? const SharedPreferencesThreadCacheStore();
  }

  ThreadItemCacheStore get _resolvedThreadItemCacheStore {
    return widget.threadItemCacheStore ??
        const SharedPreferencesThreadItemCacheStore();
  }

  ThreadTimelineCursorStore get _resolvedThreadTimelineCursorStore {
    return widget.threadTimelineCursorStore ??
        const SharedPreferencesThreadTimelineCursorStore();
  }

  bool get _usesHostApprovalGroups =>
      _hostSessionManager != null && _hostSessionManager!.sessions.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setControllers(
      approvalController: widget.approvalController,
      sessionController: widget.sessionController,
      hostSessionManager: widget.hostSessionManager,
      configOverrideController: widget.configOverrideController,
      backgroundConnectionPreferences: widget.backgroundConnectionPreferences,
    );
    _startBackgroundNotificationCoordinator(
      widget.backgroundNotificationRouter,
    );
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.approvalController != widget.approvalController ||
        oldWidget.sessionController != widget.sessionController ||
        oldWidget.hostSessionManager != widget.hostSessionManager ||
        oldWidget.configOverrideController != widget.configOverrideController ||
        oldWidget.backgroundConnectionPreferences !=
            widget.backgroundConnectionPreferences ||
        oldWidget.backgroundConnectionKeeper !=
            widget.backgroundConnectionKeeper ||
        oldWidget.slashCommandManifestReader !=
            widget.slashCommandManifestReader ||
        oldWidget.threadCacheStore != widget.threadCacheStore ||
        oldWidget.threadItemCacheStore != widget.threadItemCacheStore ||
        oldWidget.threadTimelineCursorStore !=
            widget.threadTimelineCursorStore) {
      _disposeOwnedControllers();
      _setControllers(
        approvalController: widget.approvalController,
        sessionController: widget.sessionController,
        hostSessionManager: widget.hostSessionManager,
        configOverrideController: widget.configOverrideController,
        backgroundConnectionPreferences: widget.backgroundConnectionPreferences,
      );
    }
    if (oldWidget.backgroundNotificationRouter !=
        widget.backgroundNotificationRouter) {
      unawaited(
        _replaceBackgroundNotificationRouter(
          widget.backgroundNotificationRouter,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_backgroundNotificationCoordinator?.dispose());
    _disposeOwnedControllers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_lifecycleConnectionCoordinator?.handleLifecycleState(state));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _approvalController,
          builder: (context, _) => _pageForIndex(_index),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dns_outlined),
            selectedIcon: const Icon(Icons.dns),
            label: l10n.hosts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: l10n.chat,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_copy_outlined),
            selectedIcon: const Icon(Icons.folder_copy),
            label: l10n.files,
          ),
          NavigationDestination(
            icon: const Icon(Icons.verified_user_outlined),
            selectedIcon: const Icon(Icons.verified_user),
            label: l10n.approvals,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }

  void _setControllers({
    required ApprovalStateController? approvalController,
    required CodexSessionStateController? sessionController,
    required HostSessionManager? hostSessionManager,
    required CodexConfigOverrideController? configOverrideController,
    required BackgroundConnectionPreferences? backgroundConnectionPreferences,
  }) {
    if (approvalController != null &&
        sessionController != null &&
        !identical(approvalController, sessionController.approvalController)) {
      throw ArgumentError(
        'Injected sessionController and approvalController must share state.',
      );
    }
    final resolvedApprovalController =
        approvalController ?? sessionController?.approvalController;
    _ownsApprovalController = resolvedApprovalController == null;
    _approvalController =
        resolvedApprovalController ?? ApprovalStateController();
    _ownsSessionController = sessionController == null;
    _sessionController =
        sessionController ??
        _createDefaultSessionController(
          _approvalController,
          _resolvedThreadItemCacheStore,
          snapshotCursorProvider: _loadActiveAgentSnapshotCursor,
        );
    _ownsHostSessionManager =
        sessionController == null && hostSessionManager == null;
    _hostSessionManager = sessionController == null
        ? hostSessionManager ??
              HostSessionManager(
                controllerFactory: (approvalController) =>
                    _createDefaultSessionController(
                      approvalController,
                      _resolvedThreadItemCacheStore,
                      snapshotCursorProvider: _loadManagedAgentSnapshotCursor,
                    ),
              )
        : null;
    _hostSessionManager?.addListener(_handleHostSessionManagerChanged);
    _ownsBackgroundConnectionPreferences =
        backgroundConnectionPreferences == null;
    _backgroundConnectionPreferences =
        backgroundConnectionPreferences ?? BackgroundConnectionPreferences();
    _ownsConfigOverrideController = configOverrideController == null;
    _configOverrideController =
        configOverrideController ?? CodexConfigOverrideController();
    _activeUiState = AppHostSessionUiState(
      sessionController: _sessionController,
      configOverrideController: _configOverrideController,
      threadCacheProfileId: _threadCacheProfileIdForSession(_sessionController),
      threadCacheStore: _resolvedThreadCacheStore,
      threadItemCacheStore: _resolvedThreadItemCacheStore,
      threadTimelineCursorStore: _resolvedThreadTimelineCursorStore,
      fallbackSlashCommandManifestReader: _resolvedSlashCommandManifestReader,
    );
    _configSnapshotController = CodexConfigSnapshotController(
      readerProvider: () => _sessionController.configSnapshotReader,
    );
    _accountSnapshotController = AccountSnapshotController(
      readerProvider: () => _sessionController.accountSnapshotReader,
    );
    _accountUsageSnapshotController = AccountUsageSnapshotController(
      readerProvider: () => _sessionController.accountUsageSnapshotReader,
    );
    _agentCodexConfigureController = AgentCodexConfigureController(
      runnerProvider: () => _defaultAgentRemoteService,
      profileProvider: () => _sessionController.profile,
    );
    _agentDoctorController = AgentDoctorController(
      readerProvider: () => _defaultAgentRemoteService,
      profileProvider: () => _sessionController.profile,
    );
    _agentLogsController = AgentLogsController(
      readerProvider: () => _defaultAgentRemoteService,
      profileProvider: () => _sessionController.profile,
    );
    _agentSchemaController = AgentSchemaController(
      readerProvider: () => _defaultAgentRemoteService,
      profileProvider: () => _sessionController.profile,
    );
    _mcpServerStatusController = McpServerStatusController(
      readerProvider: () => _sessionController.mcpServerStatusReader,
    );
    _modelListController = ModelListController(
      readerProvider: () => _sessionController.modelListReader,
    );
    _permissionProfileListController = PermissionProfileListController(
      readerProvider: () => _sessionController.permissionProfileListReader,
    );
    _diagnosticLogExportController = DiagnosticLogExportController(
      entriesProvider: () => _sessionController.diagnosticLogs,
    );
    _attachActiveSessionBindings();
  }

  void _disposeOwnedControllers() {
    _hostSessionManager?.removeListener(_handleHostSessionManagerChanged);
    _detachActiveSessionBindings();
    if (_ownsConfigOverrideController) {
      _configOverrideController.dispose();
    }
    _configSnapshotController.dispose();
    _accountSnapshotController.dispose();
    _accountUsageSnapshotController.dispose();
    _agentCodexConfigureController.dispose();
    _agentDoctorController.dispose();
    _agentLogsController.dispose();
    _agentSchemaController.dispose();
    _mcpServerStatusController.dispose();
    _modelListController.dispose();
    _permissionProfileListController.dispose();
    for (final state in {_activeUiState, ..._hostUiStates.values}) {
      state.dispose();
    }
    _hostUiStates.clear();
    if (_ownsSessionController) {
      _sessionController.dispose();
    }
    if (_ownsHostSessionManager) {
      _hostSessionManager?.dispose();
    }
    if (_ownsBackgroundConnectionPreferences) {
      _backgroundConnectionPreferences.dispose();
    }
    if (_ownsApprovalController) {
      _approvalController.dispose();
    }
  }

  void _attachActiveSessionBindings() {
    _sessionController.addListener(_handleSessionChanged);
    _activeUiState.attachEvents();
    _startLifecycleConnectionCoordinator();
    _activeUiState.handleSessionStatus(_sessionController.status);
  }

  void _detachActiveSessionBindings() {
    unawaited(_lifecycleConnectionCoordinator?.dispose());
    _lifecycleConnectionCoordinator = null;
    _sessionController.removeListener(_handleSessionChanged);
    _activeUiState.detachEvents();
  }

  void _startLifecycleConnectionCoordinator() {
    _lifecycleConnectionCoordinator = AppLifecycleConnectionCoordinator(
      sessionListenable: _sessionController,
      turnListenable: _turnController,
      preferences: _backgroundConnectionPreferences,
      keeper:
          widget.backgroundConnectionKeeper ??
          const NoopBackgroundConnectionKeeper(),
      isConnected: () => _sessionController.isConnected,
      hasActiveTurn: () => _turnController.activeTurnId != null,
      profileIdProvider: () {
        final profile = _sessionController.profile;
        return profile == null ? null : hostSessionProfileId(profile);
      },
      endpointProvider: () => _sessionController.profile?.endpoint,
      activeThreadIdProvider: () => _turnController.activeThreadId,
      activeTurnIdProvider: () => _turnController.activeTurnId,
      disconnect: _sessionController.disconnect,
      resume: _sessionController.resumeConnection,
    )..start();
  }

  Widget _pageForIndex(int index) {
    return switch (index) {
      0 => HostsPage(
        sessionController: _sessionController,
        hostSessionManager: widget.hostSessionManager ?? _hostSessionManager,
        profileStore: widget.profileStore,
        hostSessions: _hostSessions(),
        profileConnector: _connectProfile,
      ),
      1 => AnimatedBuilder(
        animation: _activeUiState.slashCommandRegistryController,
        builder: (context, _) => ChatPage(
          sessionController: _sessionController,
          threadListController: _threadListController,
          threadDetailController: _threadDetailController,
          turnController: _turnController,
          timelineController: _timelineController,
          appearanceController: widget.appearanceController,
          configOverrideController: _configOverrideController,
          configSnapshotController: _configSnapshotController,
          accountSnapshotController: _accountSnapshotController,
          accountUsageSnapshotController: _accountUsageSnapshotController,
          mcpServerStatusController: _mcpServerStatusController,
          modelListController: _modelListController,
          permissionProfileListController: _permissionProfileListController,
          registry: _activeUiState.slashCommandRegistryController.registry,
          profileStore: widget.profileStore,
          hostSessions: _hostSessions(),
          profileConnector: _connectProfile,
        ),
      ),
      2 => WorkspaceFilesPage(
        sessionController: _sessionController,
        threadDetailController: _threadDetailController,
        configOverrideController: _configOverrideController,
      ),
      3 => ApprovalsPage(
        approvals: _usesHostApprovalGroups
            ? const []
            : _approvalController.approvals,
        approvalGroups: _usesHostApprovalGroups ? _approvalGroups() : const [],
        activeProfile: _sessionController.profile,
        onCommandOrFileDecision: _approvalController.canRespond
            ? _approvalController.sendCommandOrFileDecision
            : null,
        onPermissionsResponse: _approvalController.canRespond
            ? _approvalController.sendPermissionsResponse
            : null,
        onMcpElicitationResponse: _approvalController.canRespond
            ? _approvalController.sendMcpElicitationResponse
            : null,
        onToolUserInputResponse: _approvalController.canRespond
            ? _approvalController.sendToolUserInputResponse
            : null,
      ),
      4 => SettingsPage(
        appearanceController: widget.appearanceController,
        configOverrideController: _configOverrideController,
        configSnapshotController: _configSnapshotController,
        accountSnapshotController: _accountSnapshotController,
        modelListController: _modelListController,
        backgroundConnectionPreferences: _backgroundConnectionPreferences,
        agentCodexConfigureController: _agentCodexConfigureController,
        agentDoctorController: _agentDoctorController,
        agentLogsController: _agentLogsController,
        agentSchemaController: _agentSchemaController,
        diagnosticLogExportController: _diagnosticLogExportController,
      ),
      _ => HostsPage(
        sessionController: _sessionController,
        hostSessionManager: widget.hostSessionManager ?? _hostSessionManager,
        profileStore: widget.profileStore,
        hostSessions: _hostSessions(),
        profileConnector: _connectProfile,
      ),
    };
  }

  Future<void> _connectProfile(SshProfile profile) async {
    final manager = _hostSessionManager;
    if (manager == null) {
      await _sessionController.connect(profile);
      return;
    }

    final controller = await manager.connectOrSelect(profile);
    final entry = manager.activeSession;
    if (entry != null && identical(entry.sessionController, controller)) {
      _activateHostSession(entry);
    }
  }

  Future<void> _replaceBackgroundNotificationRouter(
    BackgroundNotificationRouter? router,
  ) async {
    await _backgroundNotificationCoordinator?.dispose();
    if (!mounted) {
      return;
    }
    _startBackgroundNotificationCoordinator(router);
  }

  void _startBackgroundNotificationCoordinator(
    BackgroundNotificationRouter? router,
  ) {
    final coordinator = AppBackgroundNotificationCoordinator(
      router: router ?? const NoopBackgroundNotificationRouter(),
      hostSessionManagerProvider: () => _hostSessionManager,
      sessionControllerProvider: () => _sessionController,
      approvalControllerProvider: () => _approvalController,
      threadDetailControllerProvider: () => _threadDetailController,
      profileStoreProvider: () => widget.profileStore,
      connectProfile: _connectProfile,
      navigate: (destination) {
        if (!mounted) {
          return;
        }
        setState(() {
          _index = switch (destination) {
            AppBackgroundNotificationDestination.chat => 1,
            AppBackgroundNotificationDestination.approvals => 3,
          };
        });
      },
    );
    _backgroundNotificationCoordinator = coordinator;
    unawaited(coordinator.start());
  }

  List<HostSessionSummary> _hostSessions() {
    final manager = _hostSessionManager;
    if (manager == null) {
      return const [];
    }
    return [
      for (final session in manager.sessions)
        HostSessionSummary(profile: session.profile, status: session.status),
    ];
  }

  void _handleHostSessionManagerChanged() {
    final entry = _hostSessionManager?.activeSession;
    if (entry == null) {
      return;
    }
    _activateHostSession(entry);
  }

  void _activateHostSession(HostSessionEntry entry) {
    final nextUiState = _uiStateForHost(entry);
    if (identical(_sessionController, entry.sessionController) &&
        identical(_approvalController, entry.approvalController) &&
        identical(_activeUiState, nextUiState)) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final previousSessionController = _sessionController;
    final previousApprovalController = _approvalController;
    final previousUiState = _activeUiState;
    final disposePreviousSessionController = _ownsSessionController;
    final disposePreviousApprovalController = _ownsApprovalController;
    final disposePreviousUiState = !_hostUiStates.containsValue(
      previousUiState,
    );

    _detachActiveSessionBindings();
    _sessionController = entry.sessionController;
    _approvalController = entry.approvalController;
    _activeUiState = nextUiState;
    _ownsSessionController = false;
    _ownsApprovalController = false;
    _attachActiveSessionBindings();

    if (disposePreviousSessionController) {
      previousSessionController.dispose();
    }
    if (disposePreviousApprovalController) {
      previousApprovalController.dispose();
    }
    if (disposePreviousUiState) {
      previousUiState.dispose();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<String?> _loadActiveAgentSnapshotCursor(SshProfile profile) {
    return _activeUiState.loadAgentSnapshotCursor(profile);
  }

  Future<String?> _loadManagedAgentSnapshotCursor(SshProfile profile) {
    final profileId = hostSessionProfileId(profile);
    final uiState = _hostUiStates[profileId];
    if (uiState != null) {
      return uiState.loadAgentSnapshotCursor(profile);
    }
    return AppAgentSnapshotCursorProvider(
      profileId: profileId,
      threadCacheStore: _resolvedThreadCacheStore,
      threadTimelineCursorStore: _resolvedThreadTimelineCursorStore,
    ).load(profile);
  }

  AppHostSessionUiState _uiStateForHost(HostSessionEntry entry) {
    return _hostUiStates.putIfAbsent(
      entry.profileId,
      () => AppHostSessionUiState(
        sessionController: entry.sessionController,
        configOverrideController: _configOverrideController,
        threadCacheProfileId: entry.profileId,
        threadCacheStore: _resolvedThreadCacheStore,
        threadItemCacheStore: _resolvedThreadItemCacheStore,
        threadTimelineCursorStore: _resolvedThreadTimelineCursorStore,
        fallbackSlashCommandManifestReader: _resolvedSlashCommandManifestReader,
      ),
    );
  }

  void _handleSessionChanged() {
    _activeUiState.attachEvents();
    _activeUiState.handleSessionStatus(_sessionController.status);
    if (_sessionController.isConnected) {
      unawaited(_configSnapshotController.refresh());
      unawaited(_accountSnapshotController.refresh());
      unawaited(
        _permissionProfileListController.refresh(
          cwd: _configOverrideController.resolved.cwd,
        ),
      );
    }
  }

  List<ApprovalHostGroup> _approvalGroups() {
    final manager = _hostSessionManager;
    if (manager == null) {
      return const [];
    }
    return [
      for (final session in manager.sessions)
        ApprovalHostGroup(
          profile: session.profile,
          approvals: session.approvalController.approvals,
          onCommandOrFileDecision: session.approvalController.canRespond
              ? session.approvalController.sendCommandOrFileDecision
              : null,
          onPermissionsResponse: session.approvalController.canRespond
              ? session.approvalController.sendPermissionsResponse
              : null,
          onMcpElicitationResponse: session.approvalController.canRespond
              ? session.approvalController.sendMcpElicitationResponse
              : null,
          onToolUserInputResponse: session.approvalController.canRespond
              ? session.approvalController.sendToolUserInputResponse
              : null,
        ),
    ];
  }
}

String? _threadCacheProfileIdForSession(
  CodexSessionStateController sessionController,
) {
  final profile = sessionController.profile;
  return profile == null ? null : hostSessionProfileId(profile);
}
