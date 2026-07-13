import 'package:flutter/material.dart';

import '../../commands/slash_command_registry.dart';
import '../../config/codex_config_override_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../session/codex_session_state_controller.dart';
import '../../turns/turn_controller.dart';
import '../../turns/turn_text_element.dart';

typedef ChatSlashCommandDispatcher =
    Future<void> Function(SlashCommandParseResult parsed);
typedef ChatComposerTextElementsProvider =
    List<TurnTextElement> Function(String text);
typedef ChatActiveTurnSync = void Function({String? submittedText});
typedef ChatComposerClearer = void Function();
typedef ChatComposerSnackBar = void Function(String message);

class ChatComposerSubmitHandler {
  const ChatComposerSubmitHandler({
    required this.context,
    required this.mounted,
    required this.registry,
    required this.sessionController,
    required this.turnController,
    required this.configOverrideController,
    required this.slashTextPromptProvider,
    required this.textElementsProvider,
    required this.dispatchSlashCommand,
    required this.syncActiveTurn,
    required this.clearComposer,
    required this.showSnackBar,
  });

  final BuildContext context;
  final bool Function() mounted;
  final SlashCommandRegistry registry;
  final CodexSessionStateController? sessionController;
  final TurnController? turnController;
  final CodexConfigOverrideController? configOverrideController;
  final String? Function() slashTextPromptProvider;
  final ChatComposerTextElementsProvider textElementsProvider;
  final ChatSlashCommandDispatcher dispatchSlashCommand;
  final ChatActiveTurnSync syncActiveTurn;
  final ChatComposerClearer clearComposer;
  final ChatComposerSnackBar showSnackBar;

  bool canSubmit(String text) {
    return canSubmitChatComposerText(
      text,
      isConnected: sessionController?.isConnected == true,
      turnController: turnController,
      registry: registry,
      slashTextPrompt: slashTextPromptProvider(),
      hasShellCommandRunner:
          sessionController?.threadShellCommandRunner != null,
    );
  }

  Future<void> submit(String text) async {
    final parsed = registry.parseComposerText(text);
    final sendSlashAsText = isSlashTextPrompt(
      text,
      parsed,
      slashTextPromptProvider(),
    );
    if (!canSubmit(text)) {
      return;
    }
    if (isShellCommandInput(text)) {
      await _sendShellCommand(text);
      return;
    }
    if (parsed.kind != SlashCommandParseKind.notSlash && !sendSlashAsText) {
      await dispatchSlashCommand(parsed);
      return;
    }

    final controller = turnController;
    if (controller == null) {
      return;
    }
    final textElements = textElementsProvider(text);
    final steeringActiveTurn = controller.canSteer && !controller.canSubmit;
    if (steeringActiveTurn) {
      await controller.steerActiveTurn(text, textElements: textElements);
    } else {
      await controller.submitText(text, textElements: textElements);
    }
    if (controller.status != TurnControllerStatus.failed) {
      syncActiveTurn(submittedText: text);
      if (!steeringActiveTurn) {
        configOverrideController?.clearTurn();
      }
      clearComposer();
    }
  }

  Future<void> _sendShellCommand(String text) async {
    final l10n = context.l10n;
    final command = shellCommandFromInput(text);
    final runner = sessionController?.threadShellCommandRunner;
    final threadId = _nonEmptyText(turnController?.activeThreadId);
    if (command == null || runner == null || threadId == null) {
      return;
    }

    try {
      await runner.runShellCommand(threadId: threadId, command: command);
      clearComposer();
    } on Object catch (error) {
      if (!mounted()) {
        return;
      }
      showSnackBar(l10n.messageWithDetail(l10n.shellCommandFailed, error));
    }
  }
}

bool canSubmitChatComposerText(
  String text, {
  required bool isConnected,
  required TurnController? turnController,
  required SlashCommandRegistry registry,
  required String? slashTextPrompt,
  required bool hasShellCommandRunner,
}) {
  if (text.trim().isEmpty) {
    return false;
  }
  if (isShellCommandInput(text)) {
    return shellCommandFromInput(text) != null &&
        isConnected &&
        hasShellCommandRunner &&
        turnController != null &&
        !turnController.isBusy &&
        _nonEmptyText(turnController.activeThreadId) != null;
  }
  final parsed = registry.parseComposerText(text);
  final canSubmitPrompt =
      isConnected &&
      turnController != null &&
      (turnController.canSubmit || turnController.canSteer);
  if (isSlashTextPrompt(text, parsed, slashTextPrompt)) {
    return canSubmitPrompt;
  }
  return switch (parsed.kind) {
    SlashCommandParseKind.notSlash => canSubmitPrompt,
    SlashCommandParseKind.empty || SlashCommandParseKind.unknown => false,
    SlashCommandParseKind.known => true,
  };
}

bool isSlashTextPrompt(
  String text,
  SlashCommandParseResult parsed,
  String? slashTextPrompt,
) {
  return slashTextPrompt == text &&
      parsed.kind != SlashCommandParseKind.notSlash &&
      parsed.kind != SlashCommandParseKind.empty;
}

bool isShellCommandInput(String text) => text.startsWith('!');

String? shellCommandFromInput(String text) {
  if (!isShellCommandInput(text)) {
    return null;
  }
  return _nonEmptyText(text.substring(1));
}

String? _nonEmptyText(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
