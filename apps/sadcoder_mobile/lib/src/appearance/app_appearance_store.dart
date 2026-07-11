import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_appearance_controller.dart';

abstract interface class AppAppearanceSettingsStore {
  Future<AppAppearanceSettings> loadSettings();

  Future<void> saveSettings(AppAppearanceSettings settings);
}

class AppAppearanceSettings {
  const AppAppearanceSettings({
    this.theme = AppThemePreference.system,
    this.colorPalette = AppColorPalette.sadcoder,
    this.titleDisplay = AppTitleDisplaySettings.defaults,
    this.statusLineDisplay = AppStatusLineDisplaySettings.defaults,
    this.composerInputMode = AppComposerInputMode.standard,
    this.composerSendShortcut = AppComposerSendShortcut.enter,
    this.terminalPetPreference = AppTerminalPetPreference.tuiOnly,
    this.showUnavailableSlashCommands = false,
  });

  static const defaults = AppAppearanceSettings();

  factory AppAppearanceSettings.fromController(
    AppAppearanceController controller,
  ) {
    return AppAppearanceSettings(
      theme: controller.theme,
      colorPalette: controller.colorPalette,
      titleDisplay: controller.titleDisplay,
      statusLineDisplay: controller.statusLineDisplay,
      composerInputMode: controller.composerInputMode,
      composerSendShortcut: controller.composerSendShortcut,
      terminalPetPreference: controller.terminalPetPreference,
      showUnavailableSlashCommands: controller.showUnavailableSlashCommands,
    );
  }

  factory AppAppearanceSettings.fromJson(Map<String, Object?> json) {
    final titleDisplay = _stringKeyedMap(json['titleDisplay']);
    final statusLineDisplay = _stringKeyedMap(json['statusLineDisplay']);
    return AppAppearanceSettings(
      theme:
          AppThemePreference.parse(_stringValue(json['theme']) ?? '') ??
          AppThemePreference.system,
      colorPalette:
          AppColorPalette.parse(_stringValue(json['colorPalette']) ?? '') ??
          AppColorPalette.sadcoder,
      titleDisplay: AppTitleDisplaySettings(
        showThreadTitle:
            _boolValue(titleDisplay['showThreadTitle']) ??
            AppTitleDisplaySettings.defaults.showThreadTitle,
        showWorkingDirectory:
            _boolValue(titleDisplay['showWorkingDirectory']) ??
            AppTitleDisplaySettings.defaults.showWorkingDirectory,
      ),
      statusLineDisplay: AppStatusLineDisplaySettings(
        showConnection:
            _boolValue(statusLineDisplay['showConnection']) ??
            AppStatusLineDisplaySettings.defaults.showConnection,
        showThread:
            _boolValue(statusLineDisplay['showThread']) ??
            AppStatusLineDisplaySettings.defaults.showThread,
        showWorkingDirectory:
            _boolValue(statusLineDisplay['showWorkingDirectory']) ??
            AppStatusLineDisplaySettings.defaults.showWorkingDirectory,
        showModel:
            _boolValue(statusLineDisplay['showModel']) ??
            AppStatusLineDisplaySettings.defaults.showModel,
        showEffort:
            _boolValue(statusLineDisplay['showEffort']) ??
            AppStatusLineDisplaySettings.defaults.showEffort,
      ),
      composerInputMode: _enumByName(
        AppComposerInputMode.values,
        _stringValue(json['composerInputMode']),
        AppComposerInputMode.standard,
      ),
      composerSendShortcut:
          AppComposerSendShortcut.parseCommandValue(
            _stringValue(json['composerSendShortcut']) ?? '',
          ) ??
          AppComposerSendShortcut.enter,
      terminalPetPreference:
          AppTerminalPetPreference.parseCommandValue(
            _stringValue(json['terminalPetPreference']) ?? '',
          ) ??
          AppTerminalPetPreference.tuiOnly,
      showUnavailableSlashCommands:
          _boolValue(json['showUnavailableSlashCommands']) ?? false,
    );
  }

  final AppThemePreference theme;
  final AppColorPalette colorPalette;
  final AppTitleDisplaySettings titleDisplay;
  final AppStatusLineDisplaySettings statusLineDisplay;
  final AppComposerInputMode composerInputMode;
  final AppComposerSendShortcut composerSendShortcut;
  final AppTerminalPetPreference terminalPetPreference;
  final bool showUnavailableSlashCommands;

  AppAppearanceController createController() {
    return AppAppearanceController(
      theme: theme,
      colorPalette: colorPalette,
      titleDisplay: titleDisplay,
      statusLineDisplay: statusLineDisplay,
      composerInputMode: composerInputMode,
      composerSendShortcut: composerSendShortcut,
      terminalPetPreference: terminalPetPreference,
      showUnavailableSlashCommands: showUnavailableSlashCommands,
    );
  }

  Map<String, Object?> toJson() => {
    'theme': theme.commandValue,
    'colorPalette': colorPalette.commandValue,
    'titleDisplay': {
      'showThreadTitle': titleDisplay.showThreadTitle,
      'showWorkingDirectory': titleDisplay.showWorkingDirectory,
    },
    'statusLineDisplay': {
      'showConnection': statusLineDisplay.showConnection,
      'showThread': statusLineDisplay.showThread,
      'showWorkingDirectory': statusLineDisplay.showWorkingDirectory,
      'showModel': statusLineDisplay.showModel,
      'showEffort': statusLineDisplay.showEffort,
    },
    'composerInputMode': composerInputMode.name,
    'composerSendShortcut': _composerSendShortcutWireValue(
      composerSendShortcut,
    ),
    'terminalPetPreference': _terminalPetPreferenceWireValue(
      terminalPetPreference,
    ),
    'showUnavailableSlashCommands': showUnavailableSlashCommands,
  };
}

class SharedPreferencesAppAppearanceStore
    implements AppAppearanceSettingsStore {
  const SharedPreferencesAppAppearanceStore({
    this.preferencesProvider = SharedPreferences.getInstance,
  });

  static const _settingsKey = 'appearance.settings.v1';

  final Future<SharedPreferences> Function() preferencesProvider;

  @override
  Future<AppAppearanceSettings> loadSettings() async {
    final preferences = await preferencesProvider();
    final raw = preferences.getString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return AppAppearanceSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppAppearanceSettings.fromJson(_stringKeyedMap(decoded));
      }
    } on FormatException {
      return AppAppearanceSettings.defaults;
    }
    return AppAppearanceSettings.defaults;
  }

  @override
  Future<void> saveSettings(AppAppearanceSettings settings) async {
    final preferences = await preferencesProvider();
    await preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null || name.trim().isEmpty) {
    return fallback;
  }
  for (final value in values) {
    if (value.name == name.trim()) {
      return value;
    }
  }
  return fallback;
}

Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool? _boolValue(Object? value) => value is bool ? value : null;

String _composerSendShortcutWireValue(AppComposerSendShortcut shortcut) {
  return switch (shortcut) {
    AppComposerSendShortcut.enter => 'enter',
    AppComposerSendShortcut.ctrlEnter => 'ctrl-enter',
  };
}

String _terminalPetPreferenceWireValue(AppTerminalPetPreference preference) {
  return switch (preference) {
    AppTerminalPetPreference.tuiOnly => 'tui',
    AppTerminalPetPreference.hidden => 'hidden',
  };
}
