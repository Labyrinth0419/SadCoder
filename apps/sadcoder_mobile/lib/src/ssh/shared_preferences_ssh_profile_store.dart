import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ssh_profile.dart';
import 'ssh_profile_store.dart';

class SharedPreferencesSshProfileStore implements SshProfileStore {
  const SharedPreferencesSshProfileStore({
    this.preferencesProvider = SharedPreferences.getInstance,
  });

  static const _lastProfileKey = 'ssh.lastProfile.v1';

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
    await preferences.setString(
      _lastProfileKey,
      jsonEncode(profile.toJson(includeSecrets: false)),
    );
  }
}
