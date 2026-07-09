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
}
