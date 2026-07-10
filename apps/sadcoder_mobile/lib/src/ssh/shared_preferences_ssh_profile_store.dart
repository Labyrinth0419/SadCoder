import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ssh_profile.dart';
import 'ssh_profile_store.dart';

class SharedPreferencesSshProfileStore implements SshProfileListStore {
  const SharedPreferencesSshProfileStore({
    this.preferencesProvider = SharedPreferences.getInstance,
  });

  static const _lastProfileKey = 'ssh.lastProfile.v1';
  static const _profilesKey = 'ssh.profiles.v1';

  final Future<SharedPreferences> Function() preferencesProvider;

  @override
  Future<SshProfile?> loadLastProfile() async {
    final preferences = await preferencesProvider();
    final raw = preferences.getString(_lastProfileKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    return SshProfile.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  Future<void> saveLastProfile(SshProfile profile) async {
    final preferences = await preferencesProvider();
    await _saveLastProfile(preferences, profile);
  }

  @override
  Future<List<SshProfile>> loadProfiles() async {
    final preferences = await preferencesProvider();
    final raw = preferences.getString(_profilesKey);
    if (raw == null || raw.trim().isEmpty) {
      final lastProfile = await loadLastProfile();
      return lastProfile == null ? const [] : [lastProfile];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return List.unmodifiable(
      decoded.whereType<Map>().map(
        (entry) => SshProfile.fromJson(_stringKeyedMap(entry)),
      ),
    );
  }

  @override
  Future<void> saveProfile(SshProfile profile) async {
    final preferences = await preferencesProvider();
    final profiles = [
      profile,
      for (final existing in await loadProfiles())
        if (existing.id != profile.id) existing,
    ];
    await preferences.setString(
      _profilesKey,
      jsonEncode([
        for (final profile in profiles) profile.toJson(includeSecrets: false),
      ]),
    );
    await _saveLastProfile(preferences, profile);
  }

  Future<void> _saveLastProfile(
    SharedPreferences preferences,
    SshProfile profile,
  ) async {
    await preferences.setString(
      _lastProfileKey,
      jsonEncode(profile.toJson(includeSecrets: false)),
    );
  }
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> value) {
  return value.map((key, value) => MapEntry(key.toString(), value));
}
