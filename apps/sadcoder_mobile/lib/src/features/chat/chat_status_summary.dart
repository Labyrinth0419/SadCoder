import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../i18n/app_localizations.dart';
import '../../session/codex_session_state_controller.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_list_controller.dart';
import '../../turns/turn_controller.dart';
import 'chat_timeline_controller.dart';
import 'config_override_labels.dart';

String buildChatStatusSummary({
  required AppLocalizations l10n,
  CodexSessionStateController? sessionController,
  ThreadListController? threadListController,
  ThreadDetailController? threadDetailController,
  TurnController? turnController,
  ChatTimelineController? timelineController,
  CodexConfigOverrideController? configOverrideController,
}) {
  final lines = <String>[
    '${l10n.connectionStatus}: ${sessionStatusLabel(l10n, sessionController?.status)}',
  ];

  final profile = sessionController?.profile;
  if (profile != null) {
    lines.add('${l10n.host}: ${profile.endpoint}');
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
  yield '${l10n.approvalPolicy}: ${_overrideStatusValue(l10n, _objectStatusValue(resolved.approvalPolicy), controller.sourceFor('approvalPolicy'))}';
  yield '${l10n.sandboxMode}: ${_overrideStatusValue(l10n, _objectStatusValue(resolved.sandboxPolicy), controller.sourceFor('sandboxPolicy'))}';
  yield '${l10n.cwdOverride}: ${_overrideStatusValue(l10n, resolved.cwd, controller.sourceFor('cwd'))}';
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

String? _objectStatusValue(Object? value) {
  return switch (value) {
    null => null,
    String text => text,
    Map<String, Object?> map when map['type'] is String =>
      map['type']! as String,
    Map map when map['type'] is String => map['type']! as String,
    Map map when map.isEmpty => null,
    Map map =>
      map.entries.map((entry) => '${entry.key}: ${entry.value}').join(', '),
    _ => value.toString(),
  };
}
