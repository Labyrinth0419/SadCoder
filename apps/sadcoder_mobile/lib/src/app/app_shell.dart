import 'package:flutter/material.dart';

import '../agent/agent_remote_service.dart';
import '../approvals/approval_state_controller.dart';
import '../features/approvals/approvals_page.dart';
import '../features/chat/chat_page.dart';
import '../features/chat/chat_timeline_controller.dart';
import '../features/hosts/hosts_page.dart';
import '../features/settings/settings_page.dart';
import '../i18n/app_localizations.dart';
import '../session/codex_session_connector.dart';
import '../session/codex_session_state_controller.dart';
import '../ssh/dart_ssh_proxy_connector.dart';
import '../ssh/dart_ssh_remote_command_runner.dart';
import '../threads/thread_detail_controller.dart';
import '../threads/thread_list_controller.dart';
import '../turns/turn_controller.dart';

const _defaultSessionConnector = CodexSessionConnector(
  proxyConnector: DartSshProxyConnector(),
);
const _defaultAgentRemoteService = AgentRemoteService(
  DartSshRemoteCommandRunner(),
);

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.approvalController, this.sessionController});

  final ApprovalStateController? approvalController;
  final CodexSessionStateController? sessionController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late ApprovalStateController _approvalController;
  late CodexSessionStateController _sessionController;
  late ThreadListController _threadListController;
  late ThreadDetailController _threadDetailController;
  late TurnController _turnController;
  late ChatTimelineController _timelineController;
  late bool _ownsApprovalController;
  late bool _ownsSessionController;

  @override
  void initState() {
    super.initState();
    _setControllers(
      approvalController: widget.approvalController,
      sessionController: widget.sessionController,
    );
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.approvalController != widget.approvalController ||
        oldWidget.sessionController != widget.sessionController) {
      _disposeOwnedControllers();
      _setControllers(
        approvalController: widget.approvalController,
        sessionController: widget.sessionController,
      );
    }
  }

  @override
  void dispose() {
    _disposeOwnedControllers();
    super.dispose();
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
        CodexSessionStateController(
          connector: _defaultSessionConnector,
          approvalController: _approvalController,
          snapshotReader: _defaultAgentRemoteService,
        );
    _threadListController = ThreadListController(
      readerProvider: () => _sessionController.threadListReader,
    );
    _threadDetailController = ThreadDetailController(
      readerProvider: () => _sessionController.threadDetailReader,
    );
    _turnController = TurnController(
      runnerProvider: () => _sessionController.turnRunner,
      activeThreadIdProvider: () => _threadDetailController.selectedThreadId,
    );
    _timelineController = ChatTimelineController(
      onTurnCompleted: ({required threadId, required turn}) {
        _turnController.finishTurn(threadId: threadId, turn: turn);
      },
    );
    _threadDetailController.addListener(_handleThreadDetailChanged);
    _sessionController.addListener(_handleSessionChanged);
    _timelineController.attach(_sessionController.events);
  }

  void _disposeOwnedControllers() {
    _sessionController.removeListener(_handleSessionChanged);
    _threadDetailController.removeListener(_handleThreadDetailChanged);
    _timelineController.dispose();
    _turnController.dispose();
    _threadDetailController.dispose();
    _threadListController.dispose();
    if (_ownsSessionController) {
      _sessionController.dispose();
    }
    if (_ownsApprovalController) {
      _approvalController.dispose();
    }
  }

  Widget _pageForIndex(int index) {
    return switch (index) {
      0 => HostsPage(sessionController: _sessionController),
      1 => ChatPage(
        sessionController: _sessionController,
        threadListController: _threadListController,
        threadDetailController: _threadDetailController,
        turnController: _turnController,
        timelineController: _timelineController,
      ),
      2 => ApprovalsPage(
        approvals: _approvalController.approvals,
        onCommandOrFileDecision: _approvalController.canRespond
            ? _approvalController.sendCommandOrFileDecision
            : null,
        onPermissionsResponse: _approvalController.canRespond
            ? _approvalController.sendPermissionsResponse
            : null,
        onMcpElicitationResponse: _approvalController.canRespond
            ? _approvalController.sendMcpElicitationResponse
            : null,
      ),
      3 => const SettingsPage(),
      _ => HostsPage(sessionController: _sessionController),
    };
  }

  void _handleSessionChanged() {
    _timelineController.attach(_sessionController.events);
  }

  void _handleThreadDetailChanged() {
    switch (_threadDetailController.status) {
      case ThreadDetailStatus.loading:
        _timelineController.selectThread(
          _threadDetailController.selectedThreadId,
        );
      case ThreadDetailStatus.loaded:
        final detail = _threadDetailController.detail;
        if (detail != null) {
          _timelineController.showThread(detail.thread);
        }
      case ThreadDetailStatus.idle:
        _timelineController.clear();
      case ThreadDetailStatus.failed:
        break;
    }
  }
}
