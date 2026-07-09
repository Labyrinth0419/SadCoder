import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'known_host.dart';

class SharedPreferencesKnownHostStore implements KnownHostStore {
  const SharedPreferencesKnownHostStore({
    this.preferencesProvider = SharedPreferences.getInstance,
  });

  static const _knownHostsKey = 'ssh.knownHosts.v1';

  final Future<SharedPreferences> Function() preferencesProvider;

  @override
  Future<KnownHostEntry?> readKnownHost({
    required String host,
    required int port,
    required String keyType,
  }) async {
    final entries = await _readEntries();
    return entries[knownHostStoreKey(host: host, port: port, keyType: keyType)];
  }

  @override
  Future<KnownHostEntry?> readKnownHostForEndpoint({
    required String host,
    required int port,
  }) async {
    final entries = await _readEntries();
    final endpointKey = knownHostEndpointKey(host: host, port: port);
    for (final entry in entries.values) {
      if (knownHostEndpointKey(host: entry.host, port: entry.port) ==
          endpointKey) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<void> saveKnownHost(KnownHostEntry entry) async {
    final entries = await _readEntries();
    entries[knownHostStoreKey(
          host: entry.host,
          port: entry.port,
          keyType: entry.keyType,
        )] =
        entry;
    final preferences = await preferencesProvider();
    await preferences.setString(
      _knownHostsKey,
      jsonEncode([for (final entry in entries.values) entry.toJson()]),
    );
  }

  Future<Map<String, KnownHostEntry>> _readEntries() async {
    final preferences = await preferencesProvider();
    final raw = preferences.getString(_knownHostsKey);
    if (raw == null || raw.trim().isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return {};
    }
    final entries = <String, KnownHostEntry>{};
    for (final value in decoded) {
      if (value is! Map) {
        continue;
      }
      final entry = KnownHostEntry.fromJson(
        value.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (entry.host.isEmpty ||
          entry.keyType.isEmpty ||
          entry.fingerprintSha256.isEmpty) {
        continue;
      }
      entries[knownHostStoreKey(
            host: entry.host,
            port: entry.port,
            keyType: entry.keyType,
          )] =
          entry;
    }
    return entries;
  }
}
