import 'package:flutter/material.dart';

import '../../approvals/pending_approval.dart';
import '../../i18n/app_localizations.dart';

class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({super.key, this.approvals = const []});

  final List<PendingApproval> approvals;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.approvals, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        if (approvals.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(l10n.noPendingApprovals),
              subtitle: Text(l10n.approvalsBody),
            ),
          )
        else
          for (final approval in approvals) _ApprovalCard(approval: approval),
      ],
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.approval});

  final PendingApproval approval;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kindLabel = _kindLabel(l10n, approval.kind);
    final detailRows = _detailRows(l10n, approval);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_kindIcon(approval.kind)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        approval.title ?? kindLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(kindLabel),
                    ],
                  ),
                ),
              ],
            ),
            if (detailRows.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...detailRows,
            ],
          ],
        ),
      ),
    );
  }
}

List<Widget> _detailRows(AppLocalizations l10n, PendingApproval approval) {
  final rows = <Widget>[];

  void add(String label, Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) {
      return;
    }
    rows.add(
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('$label: $text'),
      ),
    );
  }

  add(l10n.approvalRequestId, approval.requestId);
  add(l10n.approvalThread, approval.threadId);
  add(l10n.approvalTurn, approval.turnId);
  add(l10n.approvalCommand, approval.command);
  add(l10n.approvalWorkingDirectory, approval.cwd);
  add(l10n.approvalReason, approval.reason);
  add(l10n.approvalGrantRoot, approval.grantRoot);
  add(l10n.approvalServer, approval.serverName);
  add(l10n.approvalMessage, approval.mcpMessage);
  add(l10n.approvalUrl, approval.mcpUrl);
  return rows;
}

String _kindLabel(AppLocalizations l10n, PendingApprovalKind kind) {
  return switch (kind) {
    PendingApprovalKind.commandExecution => l10n.approvalKindCommand,
    PendingApprovalKind.fileChange => l10n.approvalKindFileChange,
    PendingApprovalKind.permissions => l10n.approvalKindPermissions,
    PendingApprovalKind.mcpElicitation => l10n.approvalKindMcp,
    PendingApprovalKind.unknown => l10n.approvalKindUnknown,
  };
}

IconData _kindIcon(PendingApprovalKind kind) {
  return switch (kind) {
    PendingApprovalKind.commandExecution => Icons.terminal,
    PendingApprovalKind.fileChange => Icons.edit_document,
    PendingApprovalKind.permissions => Icons.admin_panel_settings_outlined,
    PendingApprovalKind.mcpElicitation => Icons.dynamic_form_outlined,
    PendingApprovalKind.unknown => Icons.help_outline,
  };
}
