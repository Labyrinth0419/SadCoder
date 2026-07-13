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

  test('color palette parses command values', () {
    expect(AppColorPalette.parse('sadcoder'), AppColorPalette.sadcoder);
    expect(AppColorPalette.parse('default'), AppColorPalette.sadcoder);
    expect(AppColorPalette.parse('candy'), AppColorPalette.candy);
    expect(AppColorPalette.parse('pastel-candy'), AppColorPalette.pastelCandy);
    expect(AppColorPalette.parse('sorbet'), AppColorPalette.pastelCandy);
    expect(AppColorPalette.parse('candy-tones'), AppColorPalette.candyTones);
    expect(AppColorPalette.parse('marshmallow'), AppColorPalette.candyTones);
    expect(AppColorPalette.parse('candy-pop'), AppColorPalette.candyPop);
    expect(AppColorPalette.parse('pop'), AppColorPalette.candyPop);
    expect(AppColorPalette.parse('sugar-rush'), AppColorPalette.sugarRush);
    expect(AppColorPalette.parse('gummy'), AppColorPalette.sugarRush);
    expect(AppColorPalette.parse('ocean'), AppColorPalette.lagoon);
    expect(AppColorPalette.parse('warm'), AppColorPalette.ember);
    expect(AppColorPalette.parse('unknown'), isNull);
  });

  test('candy palette exposes sourced cotton candy pastel swatches', () {
    expect(AppColorPalette.candy.seedColor, const Color(0xFFFFB3E6));
    expect(AppColorPalette.candy.swatchColors, const [
      Color(0xFFFFB3E6),
      Color(0xFFFFD1F3),
      Color(0xFFB8F2E6),
      Color(0xFFA0C4FF),
      Color(0xFFFFF1B6),
    ]);
  });

  test('pastel candy palette exposes sourced soft candy swatches', () {
    expect(AppColorPalette.pastelCandy.seedColor, const Color(0xFFF4BCC7));
    expect(AppColorPalette.pastelCandy.swatchColors, const [
      Color(0xFFF4BCC7),
      Color(0xFF9EDEF2),
      Color(0xFFF2E1B1),
      Color(0xFFC6F2AF),
      Color(0xFFD5CAF9),
    ]);
  });

  test('candy pop palette exposes sourced high saturation swatches', () {
    expect(AppColorPalette.candyPop.seedColor, const Color(0xFF9B5DE5));
    expect(AppColorPalette.candyPop.swatchColors, const [
      Color(0xFF9B5DE5),
      Color(0xFFF15BB5),
      Color(0xFFFEE440),
      Color(0xFF00BBF9),
      Color(0xFF00F5D4),
    ]);
  });

  test('candy tones palette exposes sourced soft multi-color swatches', () {
    expect(AppColorPalette.candyTones.seedColor, const Color(0xFFF694C1));
    expect(AppColorPalette.candyTones.swatchColors, const [
      Color(0xFFD3F8E2),
      Color(0xFFE4C1F9),
      Color(0xFFF694C1),
      Color(0xFFEDE7B1),
      Color(0xFFA9DEF9),
    ]);
  });

  test('sugar rush palette exposes bubblegum-inspired candy swatches', () {
    expect(AppColorPalette.sugarRush.seedColor, const Color(0xFFF56C78));
    expect(AppColorPalette.sugarRush.swatchColors, const [
      Color(0xFFF56C78),
      Color(0xFFECE482),
      Color(0xFF7CD6E4),
      Color(0xFFAAE48F),
      Color(0xFFC25DE9),
    ]);
  });

  test('appearance exposes five real candy palette variants', () {
    final candyPalettes = AppColorPalette.values
        .where(
          (palette) => switch (palette) {
            AppColorPalette.candy ||
            AppColorPalette.pastelCandy ||
            AppColorPalette.candyTones ||
            AppColorPalette.candyPop ||
            AppColorPalette.sugarRush => true,
            _ => false,
          },
        )
        .toList(growable: false);

    expect(candyPalettes, hasLength(5));
    for (final palette in candyPalettes) {
      expect(palette.swatchColors, hasLength(5));
      expect(palette.swatchColors.toSet(), hasLength(5));
    }
  });

  test('appearance exposes exactly five ordered font size preferences', () {
    expect(AppFontSizePreference.values, const [
      AppFontSizePreference.extraSmall,
      AppFontSizePreference.small,
      AppFontSizePreference.medium,
      AppFontSizePreference.large,
      AppFontSizePreference.extraLarge,
    ]);
    expect(
      AppFontSizePreference.values.map((size) => size.commandValue),
      const ['extra-small', 'small', 'medium', 'large', 'extra-large'],
    );
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

  test('controller notifies when color palette changes', () {
    final controller = AppAppearanceController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setColorPalette(AppColorPalette.candy);
    controller.setColorPalette(AppColorPalette.candy);

    expect(controller.colorPalette, AppColorPalette.candy);
    expect(notifications, 1);
  });

  test('font size preference parses command values', () {
    expect(
      AppFontSizePreference.parse('extra-small'),
      AppFontSizePreference.extraSmall,
    );
    expect(AppFontSizePreference.parse('xs'), AppFontSizePreference.extraSmall);
    expect(AppFontSizePreference.parse('small'), AppFontSizePreference.small);
    expect(
      AppFontSizePreference.parse('default'),
      AppFontSizePreference.medium,
    );
    expect(AppFontSizePreference.parse('large'), AppFontSizePreference.large);
    expect(
      AppFontSizePreference.parse('extra-large'),
      AppFontSizePreference.extraLarge,
    );
    expect(AppFontSizePreference.parse('unknown'), isNull);
  });

  test('controller notifies when font size changes', () {
    final controller = AppAppearanceController();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setFontSize(AppFontSizePreference.extraLarge);
    controller.setFontSize(AppFontSizePreference.extraLarge);

    expect(controller.fontSize, AppFontSizePreference.extraLarge);
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
