import 'package:flutter/material.dart';

class HostsPage extends StatelessWidget {
  const HostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hosts', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        _StatusTile(
          title: 'No server profile',
          subtitle: 'Add an SSH host to run sadcoder-agent status --json.',
          icon: Icons.cloud_off_outlined,
          trailing: FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ),
        const SizedBox(height: 12),
        _StatusTile(
          title: 'M0 probe',
          subtitle:
              'SSH transport will connect this UI to sadcoder-agent proxy.',
          icon: Icons.terminal,
          trailing: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Test'),
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }
}
