import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/background/background_connection_preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'SharedPreferences store persists background connection settings',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesBackgroundConnectionPreferencesStore();
      const settings = BackgroundConnectionSettings(
        keepConnectionDuringActiveTurn: false,
      );

      await store.saveSettings(settings);
      final loaded = await store.loadSettings();

      expect(loaded.keepConnectionDuringActiveTurn, false);
    },
  );

  test(
    'SharedPreferences store falls back to defaults for invalid data',
    () async {
      SharedPreferences.setMockInitialValues({
        'background.connection.settings.v1': '{not json',
      });
      const store = SharedPreferencesBackgroundConnectionPreferencesStore();

      final loaded = await store.loadSettings();

      expect(loaded.keepConnectionDuringActiveTurn, true);
    },
  );

  test('persisted preferences load settings and save changes', () async {
    final store = _FakeBackgroundConnectionPreferencesStore(
      const BackgroundConnectionSettings(keepConnectionDuringActiveTurn: false),
    );

    final preferences = await PersistedBackgroundConnectionPreferences.load(
      store: store,
    );
    addTearDown(preferences.dispose);

    expect(preferences.keepConnectionDuringActiveTurn, false);

    preferences.setKeepConnectionDuringActiveTurn(true);
    preferences.setKeepConnectionDuringActiveTurn(true);

    expect(store.saved, hasLength(1));
    expect(store.saved.single.keepConnectionDuringActiveTurn, true);
  });
}

class _FakeBackgroundConnectionPreferencesStore
    implements BackgroundConnectionPreferencesStore {
  _FakeBackgroundConnectionPreferencesStore(this.settings);

  BackgroundConnectionSettings settings;
  final saved = <BackgroundConnectionSettings>[];

  @override
  Future<BackgroundConnectionSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(BackgroundConnectionSettings settings) async {
    this.settings = settings;
    saved.add(settings);
  }
}
