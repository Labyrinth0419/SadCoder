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

enum AppComposerInputMode { standard, vim }

enum AppComposerSendShortcut {
  enter,
  ctrlEnter;

  static AppComposerSendShortcut? parseCommandValue(String value) {
    return switch (value.trim().toLowerCase()) {
      '' => null,
      'enter' ||
      'return' ||
      'default' ||
      'send' ||
      'enter-to-send' => AppComposerSendShortcut.enter,
      'ctrl-enter' ||
      'ctrl+enter' ||
      'control-enter' ||
      'control+enter' ||
      'cmd-enter' ||
      'cmd+enter' ||
      'meta-enter' ||
      'meta+enter' => AppComposerSendShortcut.ctrlEnter,
      _ => null,
    };
  }
}

enum AppTerminalPetPreference {
  tuiOnly,
  hidden;

  static AppTerminalPetPreference? parseCommandValue(String value) {
    return switch (value.trim().toLowerCase()) {
      '' => null,
      'show' ||
      'on' ||
      'visible' ||
      'default' ||
      'tui' ||
      'terminal' => AppTerminalPetPreference.tuiOnly,
      'hide' ||
      'hidden' ||
      'off' ||
      'none' ||
      'disable' ||
      'disabled' => AppTerminalPetPreference.hidden,
      _ => null,
    };
  }
}

class AppAppearanceController extends ChangeNotifier {
  AppAppearanceController({
    AppThemePreference theme = AppThemePreference.system,
    AppTitleDisplaySettings titleDisplay = AppTitleDisplaySettings.defaults,
    AppStatusLineDisplaySettings statusLineDisplay =
        AppStatusLineDisplaySettings.defaults,
    AppComposerInputMode composerInputMode = AppComposerInputMode.standard,
    AppComposerSendShortcut composerSendShortcut =
        AppComposerSendShortcut.enter,
    AppTerminalPetPreference terminalPetPreference =
        AppTerminalPetPreference.tuiOnly,
    bool showUnavailableSlashCommands = false,
  }) : _theme = theme,
       _titleDisplay = titleDisplay,
       _statusLineDisplay = statusLineDisplay,
       _composerInputMode = composerInputMode,
       _composerSendShortcut = composerSendShortcut,
       _terminalPetPreference = terminalPetPreference,
       _showUnavailableSlashCommands = showUnavailableSlashCommands;

  AppThemePreference _theme;
  AppTitleDisplaySettings _titleDisplay;
  AppStatusLineDisplaySettings _statusLineDisplay;
  AppComposerInputMode _composerInputMode;
  AppComposerSendShortcut _composerSendShortcut;
  AppTerminalPetPreference _terminalPetPreference;
  bool _showUnavailableSlashCommands;

  AppThemePreference get theme => _theme;

  ThemeMode get themeMode => _theme.themeMode;

  AppTitleDisplaySettings get titleDisplay => _titleDisplay;

  AppStatusLineDisplaySettings get statusLineDisplay => _statusLineDisplay;

  AppComposerInputMode get composerInputMode => _composerInputMode;

  AppComposerSendShortcut get composerSendShortcut => _composerSendShortcut;

  AppTerminalPetPreference get terminalPetPreference => _terminalPetPreference;

  bool get showUnavailableSlashCommands => _showUnavailableSlashCommands;

  void setTheme(AppThemePreference theme) {
    if (_theme == theme) {
      return;
    }
    _theme = theme;
    notifyListeners();
  }

  void setTitleDisplay(AppTitleDisplaySettings settings) {
    if (_titleDisplay == settings) {
      return;
    }
    _titleDisplay = settings;
    notifyListeners();
  }

  void setStatusLineDisplay(AppStatusLineDisplaySettings settings) {
    if (_statusLineDisplay == settings) {
      return;
    }
    _statusLineDisplay = settings;
    notifyListeners();
  }

  void setComposerInputMode(AppComposerInputMode mode) {
    if (_composerInputMode == mode) {
      return;
    }
    _composerInputMode = mode;
    notifyListeners();
  }

  void setComposerSendShortcut(AppComposerSendShortcut shortcut) {
    if (_composerSendShortcut == shortcut) {
      return;
    }
    _composerSendShortcut = shortcut;
    notifyListeners();
  }

  void setTerminalPetPreference(AppTerminalPetPreference preference) {
    if (_terminalPetPreference == preference) {
      return;
    }
    _terminalPetPreference = preference;
    notifyListeners();
  }

  void setShowUnavailableSlashCommands(bool value) {
    if (_showUnavailableSlashCommands == value) {
      return;
    }
    _showUnavailableSlashCommands = value;
    notifyListeners();
  }
}

class AppTitleDisplaySettings {
  const AppTitleDisplaySettings({
    this.showThreadTitle = false,
    this.showWorkingDirectory = false,
  });

  static const defaults = AppTitleDisplaySettings();

  final bool showThreadTitle;
  final bool showWorkingDirectory;

  AppTitleDisplaySettings copyWith({
    bool? showThreadTitle,
    bool? showWorkingDirectory,
  }) {
    return AppTitleDisplaySettings(
      showThreadTitle: showThreadTitle ?? this.showThreadTitle,
      showWorkingDirectory: showWorkingDirectory ?? this.showWorkingDirectory,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppTitleDisplaySettings &&
        other.showThreadTitle == showThreadTitle &&
        other.showWorkingDirectory == showWorkingDirectory;
  }

  @override
  int get hashCode => Object.hash(showThreadTitle, showWorkingDirectory);
}

class AppStatusLineDisplaySettings {
  const AppStatusLineDisplaySettings({
    this.showConnection = false,
    this.showThread = false,
    this.showWorkingDirectory = false,
    this.showModel = false,
    this.showEffort = false,
  });

  static const defaults = AppStatusLineDisplaySettings();

  final bool showConnection;
  final bool showThread;
  final bool showWorkingDirectory;
  final bool showModel;
  final bool showEffort;

  AppStatusLineDisplaySettings copyWith({
    bool? showConnection,
    bool? showThread,
    bool? showWorkingDirectory,
    bool? showModel,
    bool? showEffort,
  }) {
    return AppStatusLineDisplaySettings(
      showConnection: showConnection ?? this.showConnection,
      showThread: showThread ?? this.showThread,
      showWorkingDirectory: showWorkingDirectory ?? this.showWorkingDirectory,
      showModel: showModel ?? this.showModel,
      showEffort: showEffort ?? this.showEffort,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppStatusLineDisplaySettings &&
        other.showConnection == showConnection &&
        other.showThread == showThread &&
        other.showWorkingDirectory == showWorkingDirectory &&
        other.showModel == showModel &&
        other.showEffort == showEffort;
  }

  @override
  int get hashCode => Object.hash(
    showConnection,
    showThread,
    showWorkingDirectory,
    showModel,
    showEffort,
  );
}
