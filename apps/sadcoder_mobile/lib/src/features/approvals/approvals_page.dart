import 'dart:async';

import 'package:flutter/material.dart';

import '../../approvals/pending_approval.dart';
import '../../i18n/app_localizations.dart';
import '../../security/approval_risk.dart';
import '../../ssh/ssh_profile.dart';
import 'tool_user_input_form.dart';

typedef CommandOrFileApprovalCallback =
    FutureOr<void> Function(
      PendingApproval approval,
      CodexApprovalDecision decision,
    );
typedef PermissionsApprovalCallback =
    FutureOr<void> Function(
      PendingApproval approval,
      Map<String, Object?> permissions,
      PermissionApprovalScope scope,
    );
typedef McpElicitationApprovalCallback =
    FutureOr<void> Function(
      PendingApproval approval,
      McpElicitationAction action,
    );
typedef ToolUserInputApprovalCallback =
    FutureOr<void> Function(
      PendingApproval approval,
      Map<String, List<String>> answers,
    );

class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({
    super.key,
    this.approvals = const [],
    this.onCommandOrFileDecision,
    this.onPermissionsResponse,
    this.onMcpElicitationResponse,
    this.onToolUserInputResponse,
    this.activeProfile,
  });

  final List<PendingApproval> approvals;
  final CommandOrFileApprovalCallback? onCommandOrFileDecision;
  final PermissionsApprovalCallback? onPermissionsResponse;
  final McpElicitationApprovalCallback? onMcpElicitationResponse;
  final ToolUserInputApprovalCallback? onToolUserInputResponse;
  final SshProfile? activeProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.approvals, style: Theme.of(context).textTheme.headlineMedium),
        if (activeProfile != null) ...[
          const SizedBox(height: 8),
          _ActiveApprovalHostBanner(profile: activeProfile!),
        ],
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
          for (final approval in approvals)
            _ApprovalCard(
              approval: approval,
              onCommandOrFileDecision: onCommandOrFileDecision,
              onPermissionsResponse: onPermissionsResponse,
              onMcpElicitationResponse: onMcpElicitationResponse,
              onToolUserInputResponse: onToolUserInputResponse,
            ),
      ],
    );
  }
}

class _ActiveApprovalHostBanner extends StatelessWidget {
  const _ActiveApprovalHostBanner({required this.profile});

  final SshProfile profile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('approvals-active-host'),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.dns_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${context.l10n.activeConnection}: ${profile.displayName}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.approval,
    required this.onCommandOrFileDecision,
    required this.onPermissionsResponse,
    required this.onMcpElicitationResponse,
    required this.onToolUserInputResponse,
  });

  final PendingApproval approval;
  final CommandOrFileApprovalCallback? onCommandOrFileDecision;
  final PermissionsApprovalCallback? onPermissionsResponse;
  final McpElicitationApprovalCallback? onMcpElicitationResponse;
  final ToolUserInputApprovalCallback? onToolUserInputResponse;

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
            const SizedBox(height: 12),
            _ApprovalActions(
              approval: approval,
              onCommandOrFileDecision: onCommandOrFileDecision,
              onPermissionsResponse: onPermissionsResponse,
              onMcpElicitationResponse: onMcpElicitationResponse,
              onToolUserInputResponse: onToolUserInputResponse,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalActions extends StatelessWidget {
  const _ApprovalActions({
    required this.approval,
    required this.onCommandOrFileDecision,
    required this.onPermissionsResponse,
    required this.onMcpElicitationResponse,
    required this.onToolUserInputResponse,
  });

  final PendingApproval approval;
  final CommandOrFileApprovalCallback? onCommandOrFileDecision;
  final PermissionsApprovalCallback? onPermissionsResponse;
  final McpElicitationApprovalCallback? onMcpElicitationResponse;
  final ToolUserInputApprovalCallback? onToolUserInputResponse;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (approval.kind == PendingApprovalKind.toolUserInput) {
      if (approval.toolUserInputQuestions.isEmpty) {
        return Text(l10n.approvalNoDirectActions);
      }
      return ToolUserInputForm(
        questions: approval.toolUserInputQuestions,
        autoResolutionMs: approval.toolUserInputAutoResolutionMs,
        onSubmit: onToolUserInputResponse == null
            ? null
            : (answers) => onToolUserInputResponse!(approval, answers),
      );
    }

    final buttons = switch (approval.kind) {
      PendingApprovalKind.commandExecution ||
      PendingApprovalKind.fileChange => _commandOrFileButtons(context, l10n),
      PendingApprovalKind.permissions => _permissionButtons(l10n),
      PendingApprovalKind.toolUserInput => const <Widget>[],
      PendingApprovalKind.mcpElicitation => _mcpButtons(l10n),
      PendingApprovalKind.unknown => const <Widget>[],
    };

    if (buttons.isEmpty) {
      return Text(l10n.approvalNoDirectActions);
    }

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  List<Widget> _commandOrFileButtons(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return [
      FilledButton.icon(
        onPressed: onCommandOrFileDecision == null
            ? null
            : () => _handleCommandOrFileDecision(
                context,
                CodexApprovalDecision.accept,
              ),
        icon: const Icon(Icons.check),
        label: Text(l10n.approvalApproveOnce),
      ),
      OutlinedButton.icon(
        onPressed: onCommandOrFileDecision == null
            ? null
            : () => _handleCommandOrFileDecision(
                context,
                CodexApprovalDecision.acceptForSession,
              ),
        icon: const Icon(Icons.done_all),
        label: Text(l10n.approvalApproveSession),
      ),
      OutlinedButton.icon(
        onPressed: onCommandOrFileDecision == null
            ? null
            : () => _handleCommandOrFileDecision(
                context,
                CodexApprovalDecision.decline,
              ),
        icon: const Icon(Icons.block),
        label: Text(l10n.approvalDeny),
      ),
      TextButton.icon(
        onPressed: onCommandOrFileDecision == null
            ? null
            : () => _handleCommandOrFileDecision(
                context,
                CodexApprovalDecision.cancel,
              ),
        icon: const Icon(Icons.cancel_outlined),
        label: Text(l10n.approvalCancel),
      ),
    ];
  }

  Future<void> _handleCommandOrFileDecision(
    BuildContext context,
    CodexApprovalDecision decision,
  ) async {
    final callback = onCommandOrFileDecision;
    if (callback == null) {
      return;
    }
    if (requiresApprovalSecondConfirmation(approval, decision)) {
      final confirmed = await _confirmHighRiskApproval(context);
      if (!confirmed) {
        return;
      }
    }
    await callback(approval, decision);
  }

  Future<bool> _confirmHighRiskApproval(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_outlined),
        title: Text(l10n.approvalSecondConfirmTitle),
        content: Text(l10n.approvalSecondConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.approvalSecondConfirmProceed),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  List<Widget> _permissionButtons(AppLocalizations l10n) {
    final permissions = _mapOrNull(approval.permissions);
    final canGrant = onPermissionsResponse != null && permissions != null;
    return [
      FilledButton.icon(
        onPressed: canGrant
            ? () => onPermissionsResponse!(
                approval,
                permissions,
                PermissionApprovalScope.turn,
              )
            : null,
        icon: const Icon(Icons.check),
        label: Text(l10n.approvalAllowTurn),
      ),
      OutlinedButton.icon(
        onPressed: canGrant
            ? () => onPermissionsResponse!(
                approval,
                permissions,
                PermissionApprovalScope.session,
              )
            : null,
        icon: const Icon(Icons.done_all),
        label: Text(l10n.approvalAllowSession),
      ),
      OutlinedButton.icon(
        onPressed: onPermissionsResponse == null
            ? null
            : () => onPermissionsResponse!(
                approval,
                const <String, Object?>{},
                PermissionApprovalScope.turn,
              ),
        icon: const Icon(Icons.block),
        label: Text(l10n.approvalDeny),
      ),
    ];
  }

  List<Widget> _mcpButtons(AppLocalizations l10n) {
    return [
      OutlinedButton.icon(
        onPressed: onMcpElicitationResponse == null
            ? null
            : () => onMcpElicitationResponse!(
                approval,
                McpElicitationAction.decline,
              ),
        icon: const Icon(Icons.block),
        label: Text(l10n.approvalDeny),
      ),
      TextButton.icon(
        onPressed: onMcpElicitationResponse == null
            ? null
            : () => onMcpElicitationResponse!(
                approval,
                McpElicitationAction.cancel,
              ),
        icon: const Icon(Icons.cancel_outlined),
        label: Text(l10n.approvalCancel),
      ),
    ];
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
    PendingApprovalKind.toolUserInput => l10n.approvalKindUserInput,
    PendingApprovalKind.mcpElicitation => l10n.approvalKindMcp,
    PendingApprovalKind.unknown => l10n.approvalKindUnknown,
  };
}

IconData _kindIcon(PendingApprovalKind kind) {
  return switch (kind) {
    PendingApprovalKind.commandExecution => Icons.terminal,
    PendingApprovalKind.fileChange => Icons.edit_document,
    PendingApprovalKind.permissions => Icons.admin_panel_settings_outlined,
    PendingApprovalKind.toolUserInput => Icons.question_answer_outlined,
    PendingApprovalKind.mcpElicitation => Icons.dynamic_form_outlined,
    PendingApprovalKind.unknown => Icons.help_outline,
  };
}

Map<String, Object?>? _mapOrNull(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }
  return null;
}
