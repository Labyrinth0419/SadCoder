import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'thread_summary.dart';

abstract interface class ThreadItemCacheStore {
  Future<ThreadItemCacheSnapshot?> loadThreadItems({
    required String profileId,
    required String threadId,
  });

  Future<void> saveThreadItems({
    required String profileId,
    required String threadId,
    required ThreadItemCacheSnapshot snapshot,
  });
}

class ThreadItemCacheSnapshot {
  const ThreadItemCacheSnapshot({
    required this.threadId,
    required this.items,
    this.nextCursor,
    this.backwardsCursor,
    required this.cachedAtMs,
  });

  factory ThreadItemCacheSnapshot.fromJson(Map<String, Object?> json) {
    final items = _listOfMaps(json['items'])
        .map(ThreadItemSummary.fromJson)
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
    return ThreadItemCacheSnapshot(
      threadId: _stringValue(json['threadId']) ?? '',
      items: List.unmodifiable(items),
      nextCursor: _stringValue(json['nextCursor']),
      backwardsCursor: _stringValue(json['backwardsCursor']),
      cachedAtMs: _intValue(json['cachedAtMs']) ?? 0,
    );
  }

  factory ThreadItemCacheSnapshot.fromPage({
    required String threadId,
    required ThreadItemsPage page,
    required int cachedAtMs,
  }) {
    return ThreadItemCacheSnapshot(
      threadId: threadId.trim(),
      items: page.items,
      nextCursor: page.nextCursor,
      backwardsCursor: page.backwardsCursor,
      cachedAtMs: cachedAtMs,
    );
  }

  final String threadId;
  final List<ThreadItemSummary> items;
  final String? nextCursor;
  final String? backwardsCursor;
  final int cachedAtMs;

  bool get isEmpty => threadId.trim().isEmpty || items.isEmpty;

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': 1,
      'threadId': threadId,
      'items': [for (final item in items) item.toJson()],
      if (nextCursor != null) 'nextCursor': nextCursor,
      if (backwardsCursor != null) 'backwardsCursor': backwardsCursor,
      'cachedAtMs': cachedAtMs,
    };
  }

  ThreadItemsPage toPage() {
    return ThreadItemsPage(
      items: items,
      nextCursor: nextCursor,
      backwardsCursor: backwardsCursor,
    );
  }
}

class SharedPreferencesThreadItemCacheStore implements ThreadItemCacheStore {
  const SharedPreferencesThreadItemCacheStore({
    this.preferencesProvider = SharedPreferences.getInstance,
  });

  static const _keyPrefix = 'threads.itemCache.v1.';

  final Future<SharedPreferences> Function() preferencesProvider;

  @override
  Future<ThreadItemCacheSnapshot?> loadThreadItems({
    required String profileId,
    required String threadId,
  }) async {
    final key = _cacheKey(profileId: profileId, threadId: threadId);
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
      if (decoded is Map) {
        final snapshot = ThreadItemCacheSnapshot.fromJson(
          _stringKeyedMap(decoded),
        );
        return snapshot.isEmpty ? null : snapshot;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  @override
  Future<void> saveThreadItems({
    required String profileId,
    required String threadId,
    required ThreadItemCacheSnapshot snapshot,
  }) async {
    final key = _cacheKey(profileId: profileId, threadId: threadId);
    if (key == null || snapshot.isEmpty) {
      return;
    }
    final preferences = await preferencesProvider();
    await preferences.setString(key, jsonEncode(snapshot.toJson()));
  }

  String? _cacheKey({required String profileId, required String threadId}) {
    final normalizedProfileId = _normalized(profileId);
    final normalizedThreadId = _normalized(threadId);
    if (normalizedProfileId == null || normalizedThreadId == null) {
      return null;
    }
    final encoded = base64Url.encode(
      utf8.encode('$normalizedProfileId\n$normalizedThreadId'),
    );
    return '$_keyPrefix$encoded';
  }
}

String? _normalized(String value) {
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

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
