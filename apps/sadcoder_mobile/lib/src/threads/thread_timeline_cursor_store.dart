import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ThreadTimelineCursorStore {
  Future<ThreadTimelineCursorSnapshot?> loadThreadCursor({
    required String profileId,
    required String threadId,
  });

  Future<void> saveThreadCursor({
    required String profileId,
    required String threadId,
    required ThreadTimelineCursorSnapshot snapshot,
  });
}

abstract interface class ThreadTimelineCursorProfileCleaner {
  Future<void> deleteProfileCursors(String profileId);
}

class ThreadTimelineCursorSnapshot {
  const ThreadTimelineCursorSnapshot({
    required this.threadId,
    required this.turnIds,
    required this.itemIds,
    this.lastTurnId,
    this.lastItemId,
    this.deliveredCursor,
    required this.cachedAtMs,
  });

  factory ThreadTimelineCursorSnapshot.fromJson(Map<String, Object?> json) {
    final turnIds = _listOfStrings(json['turnIds']);
    final itemIds = _listOfStrings(json['itemIds']);
    return ThreadTimelineCursorSnapshot(
      threadId: _stringValue(json['threadId']) ?? '',
      turnIds: List.unmodifiable(turnIds),
      itemIds: List.unmodifiable(itemIds),
      lastTurnId: _stringValue(json['lastTurnId']) ?? _lastOrNull(turnIds),
      lastItemId: _stringValue(json['lastItemId']) ?? _lastOrNull(itemIds),
      deliveredCursor: _stringValue(json['deliveredCursor']),
      cachedAtMs: _intValue(json['cachedAtMs']) ?? 0,
    );
  }

  final String threadId;
  final List<String> turnIds;
  final List<String> itemIds;
  final String? lastTurnId;
  final String? lastItemId;
  final String? deliveredCursor;
  final int cachedAtMs;

  bool get isEmpty {
    return threadId.trim().isEmpty ||
        (turnIds.isEmpty &&
            itemIds.isEmpty &&
            lastTurnId == null &&
            lastItemId == null &&
            deliveredCursor == null);
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': 1,
      'threadId': threadId,
      'turnIds': turnIds,
      'itemIds': itemIds,
      if (lastTurnId != null) 'lastTurnId': lastTurnId,
      if (lastItemId != null) 'lastItemId': lastItemId,
      if (deliveredCursor != null) 'deliveredCursor': deliveredCursor,
      'cachedAtMs': cachedAtMs,
    };
  }
}

class SharedPreferencesThreadTimelineCursorStore
    implements ThreadTimelineCursorStore, ThreadTimelineCursorProfileCleaner {
  const SharedPreferencesThreadTimelineCursorStore({
    this.preferencesProvider = SharedPreferences.getInstance,
  });

  static const _keyPrefix = 'threads.timelineCursor.v1.';

  final Future<SharedPreferences> Function() preferencesProvider;

  @override
  Future<ThreadTimelineCursorSnapshot?> loadThreadCursor({
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
        final snapshot = ThreadTimelineCursorSnapshot.fromJson(
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
  Future<void> saveThreadCursor({
    required String profileId,
    required String threadId,
    required ThreadTimelineCursorSnapshot snapshot,
  }) async {
    final key = _cacheKey(profileId: profileId, threadId: threadId);
    if (key == null || snapshot.isEmpty) {
      return;
    }
    final preferences = await preferencesProvider();
    await preferences.setString(key, jsonEncode(snapshot.toJson()));
  }

  @override
  Future<void> deleteProfileCursors(String profileId) async {
    final normalizedProfileId = _normalized(profileId);
    if (normalizedProfileId == null) {
      return;
    }
    final preferences = await preferencesProvider();
    final keys = preferences.getKeys().where(
      (key) => _keyBelongsToProfile(key, normalizedProfileId),
    );
    await Future.wait(keys.map(preferences.remove));
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

  bool _keyBelongsToProfile(String key, String profileId) {
    if (!key.startsWith(_keyPrefix)) {
      return false;
    }
    try {
      final encoded = key.substring(_keyPrefix.length);
      final decoded = utf8.decode(base64Url.decode(encoded));
      return decoded.startsWith('$profileId\n');
    } on FormatException {
      return false;
    }
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

List<String> _listOfStrings(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
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

T? _lastOrNull<T>(List<T> values) {
  return values.isEmpty ? null : values.last;
}
