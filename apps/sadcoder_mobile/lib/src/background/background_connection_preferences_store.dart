import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'background_connection_policy.dart';

abstract interface class BackgroundConnectionPreferencesStore {
  Future<BackgroundConnectionSettings> loadSettings();

  Future<void> saveSettings(BackgroundConnectionSettings settings);
}

class BackgroundConnectionSettings {
  const BackgroundConnectionSettings({
    this.keepConnectionDuringActiveTurn = true,
  });

  static const defaults = BackgroundConnectionSettings();

  factory BackgroundConnectionSettings.fromPreferences(
    BackgroundConnectionPreferences preferences,
  ) {
    return BackgroundConnectionSettings(
      keepConnectionDuringActiveTurn:
          preferences.keepConnectionDuringActiveTurn,
    );
  }

  factory BackgroundConnectionSettings.fromJson(Map<String, Object?> json) {
    return BackgroundConnectionSettings(
      keepConnectionDuringActiveTurn:
          _boolValue(json['keepConnectionDuringActiveTurn']) ??
          defaults.keepConnectionDuringActiveTurn,
    );
  }

  final bool keepConnectionDuringActiveTurn;

  Map<String, Object?> toJson() => {
    'keepConnectionDuringActiveTurn': keepConnectionDuringActiveTurn,
  };
}

class SharedPreferencesBackgroundConnectionPreferencesStore
    implements BackgroundConnectionPreferencesStore {
  const SharedPreferencesBackgroundConnectionPreferencesStore({
    this.preferencesProvider = SharedPreferences.getInstance,
  });

  static const _settingsKey = 'background.connection.settings.v1';

  final Future<SharedPreferences> Function() preferencesProvider;

  @override
  Future<BackgroundConnectionSettings> loadSettings() async {
    final preferences = await preferencesProvider();
    final raw = preferences.getString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return BackgroundConnectionSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return BackgroundConnectionSettings.fromJson(_stringKeyedMap(decoded));
      }
    } on FormatException {
      return BackgroundConnectionSettings.defaults;
    }
    return BackgroundConnectionSettings.defaults;
  }

  @override
  Future<void> saveSettings(BackgroundConnectionSettings settings) async {
    final preferences = await preferencesProvider();
    await preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}

class PersistedBackgroundConnectionPreferences
    extends BackgroundConnectionPreferences {
  PersistedBackgroundConnectionPreferences._({
    required BackgroundConnectionPreferencesStore store,
    required BackgroundConnectionSettings settings,
  }) : _store = store,
       super(
         keepConnectionDuringActiveTurn:
             settings.keepConnectionDuringActiveTurn,
       );

  static Future<PersistedBackgroundConnectionPreferences> load({
    BackgroundConnectionPreferencesStore store =
        const SharedPreferencesBackgroundConnectionPreferencesStore(),
  }) async {
    final settings = await store.loadSettings();
    return PersistedBackgroundConnectionPreferences._(
      store: store,
      settings: settings,
    );
  }

  final BackgroundConnectionPreferencesStore _store;

  @override
  void setKeepConnectionDuringActiveTurn(bool value) {
    final previous = keepConnectionDuringActiveTurn;
    super.setKeepConnectionDuringActiveTurn(value);
    if (previous != keepConnectionDuringActiveTurn) {
      _persist();
    }
  }

  void _persist() {
    try {
      unawaited(
        _store
            .saveSettings(BackgroundConnectionSettings.fromPreferences(this))
            .catchError((Object _) {}),
      );
    } on Object {
      // Background preference persistence must not block in-memory changes.
    }
  }
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

bool? _boolValue(Object? value) => value is bool ? value : null;
