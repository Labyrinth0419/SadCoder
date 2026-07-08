import 'package:flutter/material.dart';

class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Approvals', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('No pending approvals'),
            subtitle: Text(
              'Command, file, and MCP requests will appear here with their thread and turn IDs.',
            ),
          ),
        ),
      ],
    );
  }
}
