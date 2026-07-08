import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';

class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.approvals, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(l10n.noPendingApprovals),
            subtitle: Text(l10n.approvalsBody),
          ),
        ),
      ],
    );
  }
}
