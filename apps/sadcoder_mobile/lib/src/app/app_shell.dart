import 'package:flutter/material.dart';

import '../approvals/approval_state_controller.dart';
import '../features/approvals/approvals_page.dart';
import '../features/chat/chat_page.dart';
import '../features/hosts/hosts_page.dart';
import '../features/settings/settings_page.dart';
import '../i18n/app_localizations.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.approvalController});

  final ApprovalStateController? approvalController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late ApprovalStateController _approvalController;
  late bool _ownsApprovalController;

  @override
  void initState() {
    super.initState();
    _setApprovalController(widget.approvalController);
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.approvalController != widget.approvalController) {
      if (_ownsApprovalController) {
        _approvalController.dispose();
      }
      _setApprovalController(widget.approvalController);
    }
  }

  @override
  void dispose() {
    if (_ownsApprovalController) {
      _approvalController.dispose();
    }
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

  void _setApprovalController(ApprovalStateController? controller) {
    _ownsApprovalController = controller == null;
    _approvalController = controller ?? ApprovalStateController();
  }

  Widget _pageForIndex(int index) {
    return switch (index) {
      0 => const HostsPage(),
      1 => const ChatPage(),
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
      _ => const HostsPage(),
    };
  }
}
