import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.tune),
            title: Text('Server defaults'),
            subtitle: Text(
              'Codex configuration is inherited from the server unless an override is explicitly set.',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.dark_mode_outlined),
            title: Text('Theme'),
            subtitle: Text('System, light, and dark modes are supported.'),
          ),
        ),
      ],
    );
  }
}
