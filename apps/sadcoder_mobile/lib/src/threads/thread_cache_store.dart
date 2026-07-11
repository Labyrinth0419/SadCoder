import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'thread_summary.dart';

abstract interface class ThreadCacheStore {
  Future<ThreadCacheSnapshot?> loadProfileCache(String profileId);

  Future<void> saveProfileCache(String profileId, ThreadCacheSnapshot snapshot);
}

class ThreadCacheSnapshot {
  const ThreadCacheSnapshot({
    required this.threads,
    this.selectedThreadId,
    this.selectedThread,
    required this.cachedAtMs,
  });

  factory ThreadCacheSnapshot.fromJson(Map<String, Object?> json) {
    final threads = _listOfMaps(json['threads'])
        .map(ThreadSummary.fromJson)
        .where((thread) {
          return thread.id.trim().isNotEmpty;
        })
        .toList(growable: false);
    final selectedThread = _threadFromJson(json['selectedThread']);

    return ThreadCacheSnapshot(
      threads: List.unmodifiable(threads),
      selectedThreadId:
          _stringValue(json['selectedThreadId']) ?? selectedThread?.id,
      selectedThread: selectedThread,
      cachedAtMs: _intValue(json['cachedAtMs']) ?? 0,
    );
  }

  final List<ThreadSummary> threads;
  final String? selectedThreadId;
  final ThreadSummary? selectedThread;
  final int cachedAtMs;

  bool get isEmpty =>
      threads.isEmpty && selectedThreadId == null && selectedThread == null;

  Map<String, Object?> toJson() {
    final selectedThread = this.selectedThread;
    return {
      'schemaVersion': 1,
      'threads': [for (final thread in threads) thread.toSummaryJson()],
      if (selectedThreadId != null || selectedThread != null)
        'selectedThreadId': selectedThread?.id ?? selectedThreadId,
      if (selectedThread != null)
        'selectedThread': selectedThread.toDetailJson(),
      'cachedAtMs': cachedAtMs,
    };
  }
}

class SharedPreferencesThreadCacheStore implements ThreadCacheStore {
  const SharedPreferencesThreadCacheStore({
    this.preferencesProvider = SharedPreferences.getInstance,
  });

  static const _keyPrefix = 'threads.cache.v1.';

  final Future<SharedPreferences> Function() preferencesProvider;

  @override
  Future<ThreadCacheSnapshot?> loadProfileCache(String profileId) async {
    final normalized = _normalizedProfileId(profileId);
    if (normalized == null) {
      return null;
    }
    final preferences = await preferencesProvider();
    final raw = preferences.getString(_cacheKey(normalized));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return ThreadCacheSnapshot.fromJson(_stringKeyedMap(decoded));
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  @override
  Future<void> saveProfileCache(
    String profileId,
    ThreadCacheSnapshot snapshot,
  ) async {
    final normalized = _normalizedProfileId(profileId);
    if (normalized == null) {
      return;
    }
    final preferences = await preferencesProvider();
    await preferences.setString(
      _cacheKey(normalized),
      jsonEncode(snapshot.toJson()),
    );
  }

  String _cacheKey(String profileId) {
    return '$_keyPrefix${base64Url.encode(utf8.encode(profileId))}';
  }
}

String? _normalizedProfileId(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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

List<Map<String, Object?>> _listOfMaps(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<Map>().map(_stringKeyedMap).toList(growable: false);
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

ThreadSummary? _threadFromJson(Object? value) {
  final json = _stringKeyedMap(value);
  if (json.isEmpty) {
    return null;
  }
  final thread = ThreadSummary.fromJson(json);
  return thread.id.trim().isEmpty ? null : thread;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
