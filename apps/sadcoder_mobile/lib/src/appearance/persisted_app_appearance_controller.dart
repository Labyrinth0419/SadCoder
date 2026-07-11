import 'dart:async';

import 'app_appearance_controller.dart';
import 'app_appearance_store.dart';

class PersistedAppAppearanceController extends AppAppearanceController {
  PersistedAppAppearanceController._({
    required AppAppearanceSettingsStore store,
    required AppAppearanceSettings settings,
  }) : _store = store,
       super(
         theme: settings.theme,
         colorPalette: settings.colorPalette,
         titleDisplay: settings.titleDisplay,
         statusLineDisplay: settings.statusLineDisplay,
         composerInputMode: settings.composerInputMode,
         composerSendShortcut: settings.composerSendShortcut,
         terminalPetPreference: settings.terminalPetPreference,
         showUnavailableSlashCommands: settings.showUnavailableSlashCommands,
       );

  static Future<PersistedAppAppearanceController> load({
    AppAppearanceSettingsStore store =
        const SharedPreferencesAppAppearanceStore(),
  }) async {
    final settings = await store.loadSettings();
    return PersistedAppAppearanceController._(store: store, settings: settings);
  }

  final AppAppearanceSettingsStore _store;

  @override
  void setTheme(AppThemePreference theme) {
    final previous = this.theme;
    super.setTheme(theme);
    if (previous != this.theme) {
      _persist();
    }
  }

  @override
  void setColorPalette(AppColorPalette colorPalette) {
    final previous = this.colorPalette;
    super.setColorPalette(colorPalette);
    if (previous != this.colorPalette) {
      _persist();
    }
  }

  @override
  void setTitleDisplay(AppTitleDisplaySettings settings) {
    final previous = titleDisplay;
    super.setTitleDisplay(settings);
    if (previous != titleDisplay) {
      _persist();
    }
  }

  @override
  void setStatusLineDisplay(AppStatusLineDisplaySettings settings) {
    final previous = statusLineDisplay;
    super.setStatusLineDisplay(settings);
    if (previous != statusLineDisplay) {
      _persist();
    }
  }

  @override
  void setComposerInputMode(AppComposerInputMode mode) {
    final previous = composerInputMode;
    super.setComposerInputMode(mode);
    if (previous != composerInputMode) {
      _persist();
    }
  }

  @override
  void setComposerSendShortcut(AppComposerSendShortcut shortcut) {
    final previous = composerSendShortcut;
    super.setComposerSendShortcut(shortcut);
    if (previous != composerSendShortcut) {
      _persist();
    }
  }

  @override
  void setTerminalPetPreference(AppTerminalPetPreference preference) {
    final previous = terminalPetPreference;
    super.setTerminalPetPreference(preference);
    if (previous != terminalPetPreference) {
      _persist();
    }
  }

  @override
  void setShowUnavailableSlashCommands(bool value) {
    final previous = showUnavailableSlashCommands;
    super.setShowUnavailableSlashCommands(value);
    if (previous != showUnavailableSlashCommands) {
      _persist();
    }
  }

  void _persist() {
    try {
      unawaited(
        _store
            .saveSettings(AppAppearanceSettings.fromController(this))
            .catchError((Object _) {}),
      );
    } on Object {
      // Appearance persistence should not prevent the in-memory setting change.
    }
  }
}
