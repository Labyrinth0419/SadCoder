import 'package:flutter/material.dart';

import '../features/approvals/approvals_page.dart';
import '../features/chat/chat_page.dart';
import '../features/hosts/hosts_page.dart';
import '../features/settings/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dns_outlined),
      selectedIcon: Icon(Icons.dns),
      label: 'Hosts',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label: 'Chat',
    ),
    NavigationDestination(
      icon: Icon(Icons.verified_user_outlined),
      selectedIcon: Icon(Icons.verified_user),
      label: 'Approvals',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  static const _pages = [
    HostsPage(),
    ChatPage(),
    ApprovalsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: _destinations,
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}
