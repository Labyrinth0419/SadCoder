import 'package:flutter/material.dart';

import '../../commands/slash_command_action_dispatcher.dart';
import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../i18n/app_localizations.dart';
import '../../models/model_list_controller.dart';
import '../../permissions/permission_profile_list_controller.dart';
import '../../turns/turn_controller.dart';
import 'chat_model_override_sheet.dart';
import 'chat_permissions_override_sheet.dart';
import 'chat_personality_override_sheet.dart';
import 'chat_override_scope.dart';

typedef ChatPlanModeResolver =
    Future<CodexCollaborationModeOverride?> Function();
typedef ChatTimelineSync = void Function({String? submittedText});

class ChatOverrideCommandHandler {
  const ChatOverrideCommandHandler({
    required this.context,
    required this.mounted,
    required this.configOverrideController,
    required this.modelListController,
    required this.permissionProfileListController,
    required this.turnController,
    required this.resolvePlanMode,
    required this.syncActiveTurnToTimeline,
  });

  final BuildContext context;
  final bool Function() mounted;
  final CodexConfigOverrideController? configOverrideController;
  final ModelListController? modelListController;
  final PermissionProfileListController? permissionProfileListController;
  final TurnController? turnController;
  final ChatPlanModeResolver resolvePlanMode;
  final ChatTimelineSync syncActiveTurnToTimeline;

  Future<SlashCommandCallbackResult> configureModel() async {
    final controller = configOverrideController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    final result = await showModalBottomSheet<ChatModelOverrideResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChatModelOverrideSheet(
        controller: controller,
        modelListController: modelListController,
      ),
    );
    if (!mounted() || result == null) {
      return SlashCommandCallbackResult.cancelled;
    }
    switch (result.scope) {
      case ChatOverrideScope.turn:
        controller.setTurnModelEffort(
          model: result.model,
          effort: result.effort,
        );
      case ChatOverrideScope.session:
        controller.setSessionModelEffort(
          model: result.model,
          effort: result.effort,
        );
    }
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> configurePermissions() async {
    final controller = configOverrideController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    final result = await showModalBottomSheet<ChatPermissionsOverrideResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChatPermissionsOverrideSheet(
        controller: controller,
        permissionProfileListController: permissionProfileListController,
      ),
    );
    if (!mounted() || result == null) {
      return SlashCommandCallbackResult.cancelled;
    }
    if (result.isHighRisk) {
      final confirmed = await _confirmHighRiskPermissionsOverride();
      if (!mounted() || !confirmed) {
        return SlashCommandCallbackResult.cancelled;
      }
    }
    switch (result.scope) {
      case ChatOverrideScope.turn:
        controller.setTurnPermissions(
          approvalPolicy: result.approvalPolicy,
          sandboxPolicy: result.sandboxPolicy,
          permissionProfile: result.permissionProfile,
        );
      case ChatOverrideScope.session:
        controller.setSessionPermissions(
          approvalPolicy: result.approvalPolicy,
          sandboxPolicy: result.sandboxPolicy,
          permissionProfile: result.permissionProfile,
        );
    }
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> configurePersonality() async {
    final controller = configOverrideController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    final result = await showModalBottomSheet<ChatPersonalityOverrideResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          ChatPersonalityOverrideSheet(controller: controller),
    );
    if (!mounted() || result == null) {
      return SlashCommandCallbackResult.cancelled;
    }
    switch (result.scope) {
      case ChatOverrideScope.turn:
        controller.setTurnPersonality(result.personality);
      case ChatOverrideScope.session:
        controller.setSessionPersonality(result.personality);
    }
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> configurePlanMode(String arguments) async {
    final controller = configOverrideController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    final prompt = arguments.trim();
    final turnController = this.turnController;
    if (prompt.isNotEmpty &&
        (turnController == null || !turnController.canSubmit)) {
      return SlashCommandCallbackResult.unavailable;
    }

    final collaborationMode = await resolvePlanMode();
    if (!mounted() || collaborationMode == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    controller.setTurnCollaborationMode(collaborationMode);
    if (prompt.isEmpty) {
      return SlashCommandCallbackResult.executed;
    }

    await turnController!.submitText(prompt);
    if (turnController.status == TurnControllerStatus.failed) {
      return SlashCommandCallbackResult.unavailable;
    }
    syncActiveTurnToTimeline(submittedText: prompt);
    controller.clearTurn();
    return SlashCommandCallbackResult.executed;
  }

  Future<bool> _confirmHighRiskPermissionsOverride() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.permissionsHighRiskConfirmTitle),
        content: Text(l10n.permissionsHighRiskConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.permissionsHighRiskConfirmProceed),
          ),
        ],
      ),
    );
    return mounted() && confirmed == true;
  }
}
