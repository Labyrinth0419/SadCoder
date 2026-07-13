import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/app/agent_snapshot_cursor_provider.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/threads/thread_cache_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_timeline_cursor_store.dart';

void main() {
  test('loads delivered cursor for the selected thread', () async {
    final cursorStore = _MemoryThreadTimelineCursorStore({
      'profile-a::thr_live': const ThreadTimelineCursorSnapshot(
        threadId: 'thr_live',
        turnIds: [],
        itemIds: [],
        deliveredCursor: 'event-live',
        cachedAtMs: 1,
      ),
    });
    final provider = AppAgentSnapshotCursorProvider(
      profileId: 'profile-a',
      threadCacheStore: null,
      threadTimelineCursorStore: cursorStore,
      selectedThreadIdProvider: () => ' thr_live ',
    );

    final cursor = await provider.load(_profileA);

    expect(cursor, 'event-live');
  });

  test('prefers an active thread cursor before the selected thread', () async {
    final cursorStore = _MemoryThreadTimelineCursorStore({
      'profile-a::thr_active': const ThreadTimelineCursorSnapshot(
        threadId: 'thr_active',
        turnIds: [],
        itemIds: [],
        deliveredCursor: 'event-active',
        cachedAtMs: 2,
      ),
      'profile-a::thr_selected': const ThreadTimelineCursorSnapshot(
        threadId: 'thr_selected',
        turnIds: [],
        itemIds: [],
        deliveredCursor: 'event-selected',
        cachedAtMs: 1,
      ),
    });
    final provider = AppAgentSnapshotCursorProvider(
      profileId: 'profile-a',
      threadCacheStore: null,
      threadTimelineCursorStore: cursorStore,
      preferredThreadIdsProvider: () => [' thr_active ', 'thr_selected'],
    );

    final cursor = await provider.load(_profileA);

    expect(cursor, 'event-active');
    expect(provider.lastResolvedThreadId, 'thr_active');
  });

  test(
    'uses a missing active thread cursor instead of another thread',
    () async {
      final cursorStore = _MemoryThreadTimelineCursorStore({
        'profile-a::thr_selected': const ThreadTimelineCursorSnapshot(
          threadId: 'thr_selected',
          turnIds: [],
          itemIds: [],
          deliveredCursor: 'event-selected',
          cachedAtMs: 1,
        ),
      });
      final provider = AppAgentSnapshotCursorProvider(
        profileId: 'profile-a',
        threadCacheStore: null,
        threadTimelineCursorStore: cursorStore,
        preferredThreadIdsProvider: () => ['thr_active', 'thr_selected'],
      );

      final cursor = await provider.load(_profileA);

      expect(cursor, isNull);
      expect(provider.lastResolvedThreadId, 'thr_active');
    },
  );

  test('derives profile id from the connected profile', () async {
    final cursorStore = _MemoryThreadTimelineCursorStore({
      'profile-a::thr_live': const ThreadTimelineCursorSnapshot(
        threadId: 'thr_live',
        turnIds: [],
        itemIds: [],
        deliveredCursor: 'event-profile',
        cachedAtMs: 1,
      ),
    });
    final provider = AppAgentSnapshotCursorProvider(
      threadCacheStore: null,
      threadTimelineCursorStore: cursorStore,
      selectedThreadIdProvider: () => 'thr_live',
    );

    final cursor = await provider.load(_profileA);

    expect(cursor, 'event-profile');
  });

  test('falls back to cached selected thread before UI restore', () async {
    final threadStore = _MemoryThreadCacheStore({
      'profile-a': const ThreadCacheSnapshot(
        threads: [],
        selectedThreadId: 'thr_cached',
        cachedAtMs: 1,
      ),
    });
    final cursorStore = _MemoryThreadTimelineCursorStore({
      'profile-a::thr_cached': const ThreadTimelineCursorSnapshot(
        threadId: 'thr_cached',
        turnIds: [],
        itemIds: [],
        deliveredCursor: 'event-cached',
        cachedAtMs: 2,
      ),
    });
    final provider = AppAgentSnapshotCursorProvider(
      profileId: 'profile-a',
      threadCacheStore: threadStore,
      threadTimelineCursorStore: cursorStore,
    );

    final cursor = await provider.load(_profileA);

    expect(cursor, 'event-cached');
  });

  test(
    'clears the last resolved thread when no cursor target exists',
    () async {
      final cursorStore = _MemoryThreadTimelineCursorStore({
        'profile-a::thr_live': const ThreadTimelineCursorSnapshot(
          threadId: 'thr_live',
          turnIds: [],
          itemIds: [],
          deliveredCursor: 'event-live',
          cachedAtMs: 1,
        ),
      });
      var selectedThreadId = 'thr_live';
      final provider = AppAgentSnapshotCursorProvider(
        profileId: 'profile-a',
        threadCacheStore: null,
        threadTimelineCursorStore: cursorStore,
        selectedThreadIdProvider: () => selectedThreadId,
      );

      expect(await provider.load(_profileA), 'event-live');
      expect(provider.lastResolvedThreadId, 'thr_live');

      selectedThreadId = ' ';
      expect(await provider.load(_profileA), isNull);
      expect(provider.lastResolvedThreadId, isNull);
    },
  );

  test('prefers in-memory delivered cursor over stored cursor', () async {
    final cursorStore = _MemoryThreadTimelineCursorStore({
      'profile-a::thr_live': const ThreadTimelineCursorSnapshot(
        threadId: 'thr_live',
        turnIds: [],
        itemIds: [],
        deliveredCursor: 'event-stored',
        cachedAtMs: 1,
      ),
    });
    final provider = AppAgentSnapshotCursorProvider(
      profileId: 'profile-a',
      threadCacheStore: null,
      threadTimelineCursorStore: cursorStore,
      selectedThreadIdProvider: () => 'thr_live',
      deliveredCursorProvider: (_) => ' event-memory ',
    );

    final cursor = await provider.load(_profileA);

    expect(cursor, 'event-memory');
  });
}

class _MemoryThreadCacheStore implements ThreadCacheStore {
  _MemoryThreadCacheStore([Map<String, ThreadCacheSnapshot>? initial])
    : snapshots = Map.of(initial ?? const {});

  final Map<String, ThreadCacheSnapshot> snapshots;

  @override
  Future<ThreadCacheSnapshot?> loadProfileCache(String profileId) async {
    return snapshots[profileId];
  }

  @override
  Future<void> saveProfileCache(
    String profileId,
    ThreadCacheSnapshot snapshot,
  ) async {
    snapshots[profileId] = snapshot;
  }
}

class _MemoryThreadTimelineCursorStore implements ThreadTimelineCursorStore {
  _MemoryThreadTimelineCursorStore([
    Map<String, ThreadTimelineCursorSnapshot>? initial,
  ]) : snapshots = Map.of(initial ?? const {});

  final Map<String, ThreadTimelineCursorSnapshot> snapshots;

  @override
  Future<ThreadTimelineCursorSnapshot?> loadThreadCursor({
    required String profileId,
    required String threadId,
  }) async {
    return snapshots['$profileId::$threadId'];
  }

  @override
  Future<void> saveThreadCursor({
    required String profileId,
    required String threadId,
    required ThreadTimelineCursorSnapshot snapshot,
  }) async {
    snapshots['$profileId::$threadId'] = snapshot;
  }
}

const _profileA = SshProfile(
  id: 'profile-a',
  name: 'Host A',
  host: 'host-a.example.com',
  username: 'dev',
);
