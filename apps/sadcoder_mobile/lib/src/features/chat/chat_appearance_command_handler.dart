import 'package:flutter/material.dart';

import '../../appearance/app_appearance_controller.dart';
import '../../commands/slash_command_action_dispatcher.dart';
import 'chat_display_settings_sheets.dart';
import 'chat_theme_sheet.dart';

class ChatAppearanceCommandHandler {
  const ChatAppearanceCommandHandler({
    required this.context,
    required this.mounted,
    required this.controller,
  });

  final BuildContext context;
  final bool Function() mounted;
  final AppAppearanceController? controller;

  Future<SlashCommandCallbackResult> configureTheme() async {
    final controller = this.controller;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final selection = await showModalBottomSheet<ChatThemeSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChatThemeSheet(
        initialTheme: controller.theme,
        initialColorPalette: controller.colorPalette,
      ),
    );
    if (!mounted() || selection == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    controller.setTheme(selection.theme);
    controller.setColorPalette(selection.colorPalette);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> configureTitleDisplay() async {
    final controller = this.controller;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final settings = await showModalBottomSheet<AppTitleDisplaySettings>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          TitleDisplaySheet(initialSettings: controller.titleDisplay),
    );
    if (!mounted() || settings == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    controller.setTitleDisplay(settings);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> configureStatusLineDisplay() async {
    final controller = this.controller;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final settings = await showModalBottomSheet<AppStatusLineDisplaySettings>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          StatusLineDisplaySheet(initialSettings: controller.statusLineDisplay),
    );
    if (!mounted() || settings == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    controller.setStatusLineDisplay(settings);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> toggleComposerVimMode() async {
    final controller = this.controller;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final nextMode = controller.composerInputMode == AppComposerInputMode.vim
        ? AppComposerInputMode.standard
        : AppComposerInputMode.vim;
    controller.setComposerInputMode(nextMode);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> configureKeymap(String arguments) async {
    final controller = this.controller;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final trimmed = arguments.trim();
    if (trimmed.isNotEmpty) {
      final shortcut = AppComposerSendShortcut.parseCommandValue(trimmed);
      if (shortcut == null) {
        return SlashCommandCallbackResult.unavailable;
      }
      controller.setComposerSendShortcut(shortcut);
      return SlashCommandCallbackResult.executed;
    }

    final shortcut = await showModalBottomSheet<AppComposerSendShortcut>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          ComposerKeymapSheet(initialShortcut: controller.composerSendShortcut),
    );
    if (!mounted() || shortcut == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    controller.setComposerSendShortcut(shortcut);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> configureTerminalPets(
    String arguments,
  ) async {
    final controller = this.controller;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final trimmed = arguments.trim();
    if (trimmed.isNotEmpty) {
      final preference = AppTerminalPetPreference.parseCommandValue(trimmed);
      if (preference == null) {
        return SlashCommandCallbackResult.unavailable;
      }
      controller.setTerminalPetPreference(preference);
      return SlashCommandCallbackResult.executed;
    }

    final preference = await showModalBottomSheet<AppTerminalPetPreference>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TerminalPetDisplaySheet(
        initialPreference: controller.terminalPetPreference,
      ),
    );
    if (!mounted() || preference == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    controller.setTerminalPetPreference(preference);
    return SlashCommandCallbackResult.executed;
  }
}
