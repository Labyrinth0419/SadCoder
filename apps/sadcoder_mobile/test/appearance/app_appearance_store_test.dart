import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_store.dart';
import 'package:sadcoder_mobile/src/appearance/persisted_app_appearance_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('SharedPreferences store persists full appearance settings', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesAppAppearanceStore();
    const settings = AppAppearanceSettings(
      theme: AppThemePreference.dark,
      colorPalette: AppColorPalette.candy,
      titleDisplay: AppTitleDisplaySettings(
        showThreadTitle: true,
        showWorkingDirectory: true,
      ),
      statusLineDisplay: AppStatusLineDisplaySettings(
        showConnection: true,
        showThread: true,
        showModel: true,
        showEffort: true,
      ),
      composerInputMode: AppComposerInputMode.vim,
      composerSendShortcut: AppComposerSendShortcut.ctrlEnter,
      terminalPetPreference: AppTerminalPetPreference.hidden,
      showUnavailableSlashCommands: true,
    );

    await store.saveSettings(settings);
    final loaded = await store.loadSettings();

    expect(loaded.theme, AppThemePreference.dark);
    expect(loaded.colorPalette, AppColorPalette.candy);
    expect(loaded.titleDisplay.showThreadTitle, true);
    expect(loaded.titleDisplay.showWorkingDirectory, true);
    expect(loaded.statusLineDisplay.showConnection, true);
    expect(loaded.statusLineDisplay.showThread, true);
    expect(loaded.statusLineDisplay.showModel, true);
    expect(loaded.statusLineDisplay.showEffort, true);
    expect(loaded.composerInputMode, AppComposerInputMode.vim);
    expect(loaded.composerSendShortcut, AppComposerSendShortcut.ctrlEnter);
    expect(loaded.terminalPetPreference, AppTerminalPetPreference.hidden);
    expect(loaded.showUnavailableSlashCommands, true);
  });

  test(
    'SharedPreferences store falls back to defaults for invalid data',
    () async {
      SharedPreferences.setMockInitialValues({
        'appearance.settings.v1': '{not json',
      });
      const store = SharedPreferencesAppAppearanceStore();

      final loaded = await store.loadSettings();

      expect(loaded.theme, AppThemePreference.system);
      expect(loaded.colorPalette, AppColorPalette.sadcoder);
      expect(loaded.composerSendShortcut, AppComposerSendShortcut.enter);
    },
  );

  test('persisted controller loads settings and saves changes', () async {
    final store = _FakeAppearanceStore(
      const AppAppearanceSettings(
        theme: AppThemePreference.light,
        colorPalette: AppColorPalette.lagoon,
      ),
    );

    final controller = await PersistedAppAppearanceController.load(
      store: store,
    );
    addTearDown(controller.dispose);

    expect(controller.theme, AppThemePreference.light);
    expect(controller.colorPalette, AppColorPalette.lagoon);

    controller.setTheme(AppThemePreference.dark);
    controller.setColorPalette(AppColorPalette.ember);
    controller.setColorPalette(AppColorPalette.ember);

    expect(store.saved, hasLength(2));
    expect(store.saved.last.theme, AppThemePreference.dark);
    expect(store.saved.last.colorPalette, AppColorPalette.ember);
  });
}

class _FakeAppearanceStore implements AppAppearanceSettingsStore {
  _FakeAppearanceStore(this.settings);

  AppAppearanceSettings settings;
  final saved = <AppAppearanceSettings>[];

  @override
  Future<AppAppearanceSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(AppAppearanceSettings settings) async {
    this.settings = settings;
    saved.add(settings);
  }
}
