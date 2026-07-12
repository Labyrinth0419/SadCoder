import '../../accounts/account_snapshot_controller.dart';
import '../../accounts/account_snapshot_reader.dart';
import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../config/codex_config_snapshot.dart';
import '../../config/codex_config_snapshot_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../security/permission_risk.dart';
import '../../session/codex_session_state_controller.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_list_controller.dart';
import '../../turns/turn_controller.dart';
import '../../usage/account_usage_snapshot_controller.dart';
import '../../usage/thread_token_usage_controller.dart';
import 'chat_timeline_controller.dart';
import 'chat_usage_summary.dart';
import 'config_override_labels.dart';

String buildChatStatusSummary({
  required AppLocalizations l10n,
  CodexSessionStateController? sessionController,
  ThreadListController? threadListController,
  ThreadDetailController? threadDetailController,
  TurnController? turnController,
  ChatTimelineController? timelineController,
  CodexConfigOverrideController? configOverrideController,
  CodexConfigSnapshotController? configSnapshotController,
  AccountSnapshotController? accountSnapshotController,
  AccountUsageSnapshotController? accountUsageSnapshotController,
  ThreadTokenUsageController? threadTokenUsageController,
}) {
  final lines = <String>[
    '${l10n.connectionStatus}: ${sessionStatusLabel(l10n, sessionController?.status)}',
  ];

  final profile = sessionController?.profile;
  if (profile != null) {
    lines.add('${l10n.host}: ${profile.displayName}');
    final defaultCwd = profile.defaultCwd?.trim();
    if (defaultCwd != null && defaultCwd.isNotEmpty) {
      lines.add('${l10n.approvalWorkingDirectory}: $defaultCwd');
    }
  }

  final selectedThreadId =
      threadDetailController?.selectedThreadId ??
      timelineController?.selectedThreadId ??
      turnController?.activeThreadId;
  if (selectedThreadId != null && selectedThreadId.isNotEmpty) {
    lines.add('${l10n.approvalThread}: $selectedThreadId');
  }

  if (threadListController != null &&
      threadListController.status == ThreadListStatus.loaded) {
    lines.add('${l10n.sessions}: ${threadListController.threads.length}');
  }

  if (turnController != null) {
    lines.add('${l10n.approvalTurn}: ${turnStatusLabel(l10n, turnController)}');
  }

  if (configOverrideController != null) {
    lines.addAll(_overrideStatusLines(l10n, configOverrideController));
  }

  if (configSnapshotController != null) {
    lines.addAll(_serverConfigStatusLines(l10n, configSnapshotController));
  }

  if (accountSnapshotController != null) {
    lines.addAll(_accountStatusLines(l10n, accountSnapshotController));
  }

  if (accountUsageSnapshotController != null) {
    lines.addAll(accountUsageStatusLines(l10n, accountUsageSnapshotController));
  }

  final threadUsage =
      threadTokenUsageController?.latestForThread(selectedThreadId) ??
      threadTokenUsageController?.latest;
  lines.addAll(threadTokenUsageStatusLines(l10n, threadUsage));

  return lines.join('\n');
}

String sessionStatusLabel(AppLocalizations l10n, CodexSessionStatus? status) {
  return switch (status) {
    CodexSessionStatus.connected => l10n.connected,
    CodexSessionStatus.connecting => l10n.connecting,
    CodexSessionStatus.reconnecting => l10n.reconnecting,
    CodexSessionStatus.disconnecting => l10n.disconnecting,
    CodexSessionStatus.failed => l10n.connectionFailed,
    CodexSessionStatus.idle || null => l10n.disconnected,
  };
}

String turnStatusLabel(AppLocalizations l10n, TurnController controller) {
  return switch (controller.status) {
    TurnControllerStatus.idle => l10n.statusIdle,
    TurnControllerStatus.startingThread => l10n.startingThread,
    TurnControllerStatus.resumingThread => l10n.resumingThread,
    TurnControllerStatus.sendingTurn => l10n.sendingTurn,
    TurnControllerStatus.submitted => l10n.turnSubmitted(
      controller.activeTurnId ?? '',
    ),
    TurnControllerStatus.completed => l10n.turnCompleted,
    TurnControllerStatus.interrupting => l10n.interruptingTurn,
    TurnControllerStatus.interrupted => l10n.turnInterrupted,
    TurnControllerStatus.failed =>
      controller.error?.toString() ?? l10n.turnFailed,
  };
}

Iterable<String> _overrideStatusLines(
  AppLocalizations l10n,
  CodexConfigOverrideController controller,
) sync* {
  final resolved = controller.resolved;
  yield '${l10n.modelOverride}: ${_overrideStatusValue(l10n, resolved.model, controller.sourceFor('model'))}';
  yield '${l10n.effortOverride}: ${_overrideStatusValue(l10n, resolved.effort, controller.sourceFor('effort'))}';
  yield '${l10n.collaborationModeOverride}: ${_overrideStatusValue(l10n, resolved.collaborationMode?.displayLabel, controller.sourceFor('collaborationMode'))}';
  yield '${l10n.approvalPolicy}: ${_overrideStatusValue(l10n, configOverrideValueLabel(resolved.approvalPolicy), controller.sourceFor('approvalPolicy'))}';
  yield '${l10n.permissionProfile}: ${_overrideStatusValue(l10n, resolved.permissionProfile, controller.sourceFor('permissionProfile'))}';
  yield '${l10n.sandboxMode}: ${_overrideStatusValue(l10n, configOverrideValueLabel(resolved.sandboxPolicy), controller.sourceFor('sandboxPolicy'))}';
  if (isHighRiskPermissionState(
    approvalPolicy: resolved.approvalPolicy,
    sandboxPolicy: resolved.sandboxPolicy,
    permissionProfile: resolved.permissionProfile,
  )) {
    yield l10n.permissionsHighRiskWarning;
  }
  yield '${l10n.cwdOverride}: ${_overrideStatusValue(l10n, resolved.cwd, controller.sourceFor('cwd'))}';
  yield '${l10n.personalityOverride}: ${_overrideStatusValue(l10n, resolved.personality, controller.sourceFor('personality'))}';
}

Iterable<String> _serverConfigStatusLines(
  AppLocalizations l10n,
  CodexConfigSnapshotController controller,
) sync* {
  final snapshot = controller.snapshot;
  if (controller.status == CodexConfigSnapshotStatus.failed) {
    final error = controller.error;
    yield '${l10n.serverConfigSnapshot}: ${l10n.serverConfigLoadFailed}${error == null ? '' : ': $error'}';
    return;
  }
  if (snapshot == null) {
    return;
  }
  yield '${l10n.serverConfigSnapshot}: ${l10n.modelOverride}=${_serverConfigValue(l10n, snapshot, 'model')}, ${l10n.effortOverride}=${_serverConfigValue(l10n, snapshot, 'model_reasoning_effort')}, ${l10n.approvalPolicy}=${_serverConfigValue(l10n, snapshot, 'approval_policy')}, ${l10n.permissionProfile}=${_serverConfigValue(l10n, snapshot, 'default_permissions')}, ${l10n.sandboxMode}=${_serverConfigValue(l10n, snapshot, 'sandbox_mode')}';
  if (isHighRiskPermissionState(
    approvalPolicy: snapshot.valueFor('approval_policy'),
    sandboxPolicy: snapshot.valueFor('sandbox_mode'),
    permissionProfile: snapshot.valueFor('default_permissions'),
  )) {
    yield l10n.permissionsHighRiskWarning;
  }
}

String _serverConfigValue(
  AppLocalizations l10n,
  CodexConfigSnapshot snapshot,
  String key,
) {
  return snapshot.displayValueFor(key) ?? l10n.serverValueUnset;
}

Iterable<String> _accountStatusLines(
  AppLocalizations l10n,
  AccountSnapshotController controller,
) sync* {
  final snapshot = controller.snapshot;
  if (controller.status == AccountSnapshotStatus.failed) {
    final error = controller.error;
    yield '${l10n.accountStatus}: ${l10n.accountLoadFailed}${error == null ? '' : ': $error'}';
    return;
  }
  if (snapshot == null) {
    return;
  }
  yield '${l10n.accountStatus}: ${_accountStatusValue(l10n, snapshot)}';
}

String _accountStatusValue(AppLocalizations l10n, AccountSnapshot snapshot) {
  final authRequirement = snapshot.requiresOpenaiAuth
      ? l10n.openaiAuthRequired
      : l10n.openaiAuthNotRequired;
  final account = snapshot.account;
  if (account == null) {
    return '${l10n.accountNotSignedIn} / $authRequirement';
  }
  return '${account.label} / $authRequirement';
}

String _overrideStatusValue(
  AppLocalizations l10n,
  String? value,
  CodexConfigOverrideSource source,
) {
  final sourceLabel = configOverrideSourceLabel(l10n, source);
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return sourceLabel;
  }
  return '$trimmed / $sourceLabel';
}
