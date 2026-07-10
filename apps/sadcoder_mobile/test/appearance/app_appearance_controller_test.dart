import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';

void main() {
  test('theme preference maps to Flutter theme modes', () {
    expect(AppThemePreference.system.themeMode, ThemeMode.system);
    expect(AppThemePreference.light.themeMode, ThemeMode.light);
    expect(AppThemePreference.dark.themeMode, ThemeMode.dark);
  });

  test('theme preference parses command values', () {
    expect(AppThemePreference.parse('system'), AppThemePreference.system);
    expect(AppThemePreference.parse('auto'), AppThemePreference.system);
    expect(AppThemePreference.parse('light'), AppThemePreference.light);
    expect(AppThemePreference.parse('dark'), AppThemePreference.dark);
    expect(AppThemePreference.parse('unknown'), isNull);
  });

  test('controller notifies when theme changes', () {
    final controller = AppAppearanceController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setTheme(AppThemePreference.dark);
    controller.setTheme(AppThemePreference.dark);

    expect(controller.theme, AppThemePreference.dark);
    expect(controller.themeMode, ThemeMode.dark);
    expect(notifications, 1);
  });

  test('controller notifies when title display changes', () {
    final controller = AppAppearanceController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    const settings = AppTitleDisplaySettings(
      showThreadTitle: true,
      showWorkingDirectory: true,
    );
    controller.setTitleDisplay(settings);
    controller.setTitleDisplay(settings);

    expect(controller.titleDisplay, settings);
    expect(notifications, 1);
  });

  test('controller notifies when status line display changes', () {
    final controller = AppAppearanceController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    const settings = AppStatusLineDisplaySettings(
      showConnection: true,
      showThread: true,
      showModel: true,
    );
    controller.setStatusLineDisplay(settings);
    controller.setStatusLineDisplay(settings);

    expect(controller.statusLineDisplay, settings);
    expect(notifications, 1);
  });

  test('controller notifies when composer input mode changes', () {
    final controller = AppAppearanceController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setComposerInputMode(AppComposerInputMode.vim);
    controller.setComposerInputMode(AppComposerInputMode.vim);

    expect(controller.composerInputMode, AppComposerInputMode.vim);
    expect(notifications, 1);
  });

  test('composer send shortcut parses command values', () {
    expect(
      AppComposerSendShortcut.parseCommandValue('enter'),
      AppComposerSendShortcut.enter,
    );
    expect(
      AppComposerSendShortcut.parseCommandValue('default'),
      AppComposerSendShortcut.enter,
    );
    expect(
      AppComposerSendShortcut.parseCommandValue('ctrl-enter'),
      AppComposerSendShortcut.ctrlEnter,
    );
    expect(
      AppComposerSendShortcut.parseCommandValue('ctrl+enter'),
      AppComposerSendShortcut.ctrlEnter,
    );
    expect(AppComposerSendShortcut.parseCommandValue('space'), isNull);
  });

  test('controller notifies when composer send shortcut changes', () {
    final controller = AppAppearanceController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setComposerSendShortcut(AppComposerSendShortcut.ctrlEnter);
    controller.setComposerSendShortcut(AppComposerSendShortcut.ctrlEnter);

    expect(controller.composerSendShortcut, AppComposerSendShortcut.ctrlEnter);
    expect(notifications, 1);
  });

  test('terminal pet preference parses command values', () {
    expect(
      AppTerminalPetPreference.parseCommandValue('show'),
      AppTerminalPetPreference.tuiOnly,
    );
    expect(
      AppTerminalPetPreference.parseCommandValue('terminal'),
      AppTerminalPetPreference.tuiOnly,
    );
    expect(
      AppTerminalPetPreference.parseCommandValue('hide'),
      AppTerminalPetPreference.hidden,
    );
    expect(
      AppTerminalPetPreference.parseCommandValue('off'),
      AppTerminalPetPreference.hidden,
    );
    expect(AppTerminalPetPreference.parseCommandValue('dragon'), isNull);
  });

  test('controller notifies when terminal pet preference changes', () {
    final controller = AppAppearanceController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setTerminalPetPreference(AppTerminalPetPreference.hidden);
    controller.setTerminalPetPreference(AppTerminalPetPreference.hidden);

    expect(controller.terminalPetPreference, AppTerminalPetPreference.hidden);
    expect(notifications, 1);
  });

  test(
    'controller notifies when unavailable slash command display changes',
    () {
      final controller = AppAppearanceController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setShowUnavailableSlashCommands(true);
      controller.setShowUnavailableSlashCommands(true);

      expect(controller.showUnavailableSlashCommands, true);
      expect(notifications, 1);
    },
  );
}
