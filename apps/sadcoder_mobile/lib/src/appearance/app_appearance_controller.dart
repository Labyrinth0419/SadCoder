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

enum AppColorPalette {
  sadcoder,
  candy,
  lagoon,
  ember;

  static AppColorPalette? parse(String value) {
    return switch (value.trim().toLowerCase()) {
      '' => null,
      'sadcoder' || 'default' => AppColorPalette.sadcoder,
      'candy' || 'sweet' => AppColorPalette.candy,
      'lagoon' || 'blue' || 'ocean' => AppColorPalette.lagoon,
      'ember' || 'warm' => AppColorPalette.ember,
      _ => null,
    };
  }
}

extension AppColorPaletteValues on AppColorPalette {
  String get commandValue {
    return switch (this) {
      AppColorPalette.sadcoder => 'sadcoder',
      AppColorPalette.candy => 'candy',
      AppColorPalette.lagoon => 'lagoon',
      AppColorPalette.ember => 'ember',
    };
  }

  Color get seedColor {
    return switch (this) {
      AppColorPalette.sadcoder => const Color(0xFF0F766E),
      AppColorPalette.candy => const Color(0xFFF26A8D),
      AppColorPalette.lagoon => const Color(0xFF2563EB),
      AppColorPalette.ember => const Color(0xFFC2410C),
    };
  }

  List<Color> get swatchColors {
    return switch (this) {
      AppColorPalette.sadcoder => const [
        Color(0xFF0F766E),
        Color(0xFF14B8A6),
        Color(0xFF334155),
      ],
      AppColorPalette.candy => const [
        Color(0xFFF26A8D),
        Color(0xFFFFA9C5),
        Color(0xFFCBEFF3),
        Color(0xFFFFF9C9),
        Color(0xFF81D4A5),
        Color(0xFF985DC0),
      ],
      AppColorPalette.lagoon => const [
        Color(0xFF2563EB),
        Color(0xFF06B6D4),
        Color(0xFF22C55E),
      ],
      AppColorPalette.ember => const [
        Color(0xFFC2410C),
        Color(0xFFF59E0B),
        Color(0xFF7C3AED),
      ],
    };
  }
}

enum AppFontSizePreference {
  extraSmall,
  small,
  medium,
  large,
  extraLarge;

  static AppFontSizePreference? parse(String value) {
    return switch (value.trim().toLowerCase()) {
      '' => null,
      'extra-small' ||
      'extrasmall' ||
      'xs' ||
      'tiny' => AppFontSizePreference.extraSmall,
      'small' || 's' => AppFontSizePreference.small,
      'medium' || 'm' || 'normal' || 'default' => AppFontSizePreference.medium,
      'large' || 'l' => AppFontSizePreference.large,
      'extra-large' ||
      'extralarge' ||
      'xl' ||
      'huge' => AppFontSizePreference.extraLarge,
      _ => null,
    };
  }
}

extension AppFontSizePreferenceValues on AppFontSizePreference {
  String get commandValue {
    return switch (this) {
      AppFontSizePreference.extraSmall => 'extra-small',
      AppFontSizePreference.small => 'small',
      AppFontSizePreference.medium => 'medium',
      AppFontSizePreference.large => 'large',
      AppFontSizePreference.extraLarge => 'extra-large',
    };
  }

  double get scale {
    return switch (this) {
      AppFontSizePreference.extraSmall => 0.86,
      AppFontSizePreference.small => 0.94,
      AppFontSizePreference.medium => 1.0,
      AppFontSizePreference.large => 1.12,
      AppFontSizePreference.extraLarge => 1.24,
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
    AppColorPalette colorPalette = AppColorPalette.sadcoder,
    AppFontSizePreference fontSize = AppFontSizePreference.medium,
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
       _colorPalette = colorPalette,
       _fontSize = fontSize,
       _titleDisplay = titleDisplay,
       _statusLineDisplay = statusLineDisplay,
       _composerInputMode = composerInputMode,
       _composerSendShortcut = composerSendShortcut,
       _terminalPetPreference = terminalPetPreference,
       _showUnavailableSlashCommands = showUnavailableSlashCommands;

  AppThemePreference _theme;
  AppColorPalette _colorPalette;
  AppFontSizePreference _fontSize;
  AppTitleDisplaySettings _titleDisplay;
  AppStatusLineDisplaySettings _statusLineDisplay;
  AppComposerInputMode _composerInputMode;
  AppComposerSendShortcut _composerSendShortcut;
  AppTerminalPetPreference _terminalPetPreference;
  bool _showUnavailableSlashCommands;

  AppThemePreference get theme => _theme;

  AppColorPalette get colorPalette => _colorPalette;

  AppFontSizePreference get fontSize => _fontSize;

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

  void setColorPalette(AppColorPalette colorPalette) {
    if (_colorPalette == colorPalette) {
      return;
    }
    _colorPalette = colorPalette;
    notifyListeners();
  }

  void setFontSize(AppFontSizePreference fontSize) {
    if (_fontSize == fontSize) {
      return;
    }
    _fontSize = fontSize;
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
