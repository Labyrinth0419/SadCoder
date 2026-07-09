import 'package:flutter/material.dart';

enum AppThemePreference {
  system,
  light,
  dark;

  static AppThemePreference? parse(String value) {
    return switch (value.trim().toLowerCase()) {
      '' => null,
      'system' || 'auto' => AppThemePreference.system,
      'light' => AppThemePreference.light,
      'dark' => AppThemePreference.dark,
      _ => null,
    };
  }
}

extension AppThemePreferenceMode on AppThemePreference {
  ThemeMode get themeMode {
    return switch (this) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }

  String get commandValue {
    return switch (this) {
      AppThemePreference.system => 'system',
      AppThemePreference.light => 'light',
      AppThemePreference.dark => 'dark',
    };
  }
}

class AppAppearanceController extends ChangeNotifier {
  AppAppearanceController({
    AppThemePreference theme = AppThemePreference.system,
  }) : _theme = theme;

  AppThemePreference _theme;

  AppThemePreference get theme => _theme;

  ThemeMode get themeMode => _theme.themeMode;

  void setTheme(AppThemePreference theme) {
    if (_theme == theme) {
      return;
    }
    _theme = theme;
    notifyListeners();
  }
}
