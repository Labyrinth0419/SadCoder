import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'slash_command_registry.dart';

abstract interface class SlashCommandManifestStore {
  Future<SlashCommandManifest?> loadManifest({
    required String profileId,
    String? cwd,
  });

  Future<void> saveManifest({
    required String profileId,
    String? cwd,
    required SlashCommandManifest manifest,
    required int cachedAtMs,
  });
}

abstract interface class SlashCommandManifestProfileCleaner {
  Future<void> deleteProfileManifests(String profileId);
}

class SharedPreferencesSlashCommandManifestStore
    implements SlashCommandManifestStore, SlashCommandManifestProfileCleaner {
  const SharedPreferencesSlashCommandManifestStore({
    this.preferencesProvider = SharedPreferences.getInstance,
  });

  static const _keyPrefix = 'slash.commandManifest.v1.';

  final Future<SharedPreferences> Function() preferencesProvider;

  @override
  Future<SlashCommandManifest?> loadManifest({
    required String profileId,
    String? cwd,
  }) async {
    final key = _cacheKey(profileId: profileId, cwd: cwd);
    if (key == null) {
      return null;
    }
    final preferences = await preferencesProvider();
    final raw = preferences.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final decodedMap = _stringKeyedMap(decoded);
      final manifestJson = decodedMap['manifest'] ?? decodedMap;
      final manifestMap = _stringKeyedMap(manifestJson);
      if (manifestMap.isEmpty) {
        return null;
      }
      final manifest = SlashCommandManifest.fromJson(manifestMap);
      return manifest.commands.isEmpty ? null : manifest;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> saveManifest({
    required String profileId,
    String? cwd,
    required SlashCommandManifest manifest,
    required int cachedAtMs,
  }) async {
    final key = _cacheKey(profileId: profileId, cwd: cwd);
    if (key == null || manifest.commands.isEmpty) {
      return;
    }
    final preferences = await preferencesProvider();
    await preferences.setString(
      key,
      jsonEncode({
        'schemaVersion': 1,
        'profileId': profileId.trim(),
        if (_normalized(cwd) != null) 'cwd': _normalized(cwd),
        'manifest': manifest.toJson(),
        'cachedAtMs': cachedAtMs,
      }),
    );
  }

  @override
  Future<void> deleteProfileManifests(String profileId) async {
    final normalizedProfileId = _normalized(profileId);
    if (normalizedProfileId == null) {
      return;
    }
    final preferences = await preferencesProvider();
    final keys = preferences
        .getKeys()
        .where((key) => _keyBelongsToProfile(key, normalizedProfileId))
        .toList();
    await Future.wait(keys.map(preferences.remove));
  }

  String? _cacheKey({required String profileId, String? cwd}) {
    final normalizedProfileId = _normalized(profileId);
    if (normalizedProfileId == null) {
      return null;
    }
    final normalizedCwd = _normalized(cwd) ?? '';
    final encoded = base64Url.encode(
      utf8.encode('$normalizedProfileId\n$normalizedCwd'),
    );
    return '$_keyPrefix$encoded';
  }

  bool _keyBelongsToProfile(String key, String profileId) {
    if (!key.startsWith(_keyPrefix)) {
      return false;
    }
    try {
      final encoded = key.substring(_keyPrefix.length);
      final decoded = utf8.decode(base64Url.decode(encoded));
      return decoded == profileId || decoded.startsWith('$profileId\n');
    } on FormatException {
      return false;
    }
  }
}

String? _normalized(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
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
