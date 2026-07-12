import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sadcoder_mobile/src/threads/thread_cache_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

void main() {
  test('persists thread summaries per profile without turn payloads', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesThreadCacheStore();
    final selectedThread = _threadWithTurn('thr_local', 'Local task');

    await store.saveProfileCache(
      'local',
      ThreadCacheSnapshot(
        threads: [selectedThread],
        selectedThreadId: 'thr_local',
        selectedThread: selectedThread,
        cachedAtMs: 123,
      ),
    );
    await store.saveProfileCache(
      'remote',
      ThreadCacheSnapshot(
        threads: [_thread('thr_remote', 'Remote task')],
        cachedAtMs: 456,
      ),
    );

    final local = await store.loadProfileCache('local');
    final remote = await store.loadProfileCache('remote');

    expect(local?.selectedThreadId, 'thr_local');
    expect(local?.cachedAtMs, 123);
    expect(local?.threads.single.id, 'thr_local');
    expect(local?.threads.single.turns, isEmpty);
    expect(local?.selectedThread?.id, 'thr_local');
    expect(local?.selectedThread?.turns.single.id, 'turn_thr_local');
    expect(remote?.threads.single.id, 'thr_remote');
  });

  test('returns null for missing or malformed cache payloads', () async {
    SharedPreferences.setMockInitialValues({
      'threads.cache.v1.bG9jYWw=': 'not json',
    });
    const store = SharedPreferencesThreadCacheStore();

    expect(await store.loadProfileCache('missing'), isNull);
    expect(await store.loadProfileCache('local'), isNull);
  });

  test('deletes one profile cache without removing other profiles', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesThreadCacheStore();

    await store.saveProfileCache(
      'local',
      ThreadCacheSnapshot(
        threads: [_thread('thr_local', 'Local task')],
        cachedAtMs: 1,
      ),
    );
    await store.saveProfileCache(
      'remote',
      ThreadCacheSnapshot(
        threads: [_thread('thr_remote', 'Remote task')],
        cachedAtMs: 2,
      ),
    );

    await store.deleteProfileCache('local');

    expect(await store.loadProfileCache('local'), isNull);
    expect(
      (await store.loadProfileCache('remote'))?.threads.single.id,
      'thr_remote',
    );
  });
}

ThreadSummary _thread(String id, String preview) {
  return ThreadSummary.fromJson({
    'id': id,
    'sessionId': 'sess_1',
    'preview': preview,
    'ephemeral': false,
    'status': 'idle',
    'cwd': '/repo',
    'updatedAt': 1,
  });
}

ThreadSummary _threadWithTurn(String id, String preview) {
  return ThreadSummary.fromJson({
    'id': id,
    'sessionId': 'sess_1',
    'preview': preview,
    'ephemeral': false,
    'status': 'idle',
    'cwd': '/repo',
    'updatedAt': 42,
    'turns': [
      {'id': 'turn_$id', 'status': 'completed', 'items': <Object?>[]},
    ],
  });
}
