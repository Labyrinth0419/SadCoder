import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sadcoder_mobile/src/threads/thread_item_cache_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

void main() {
  test('persists thread items per profile and thread', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesThreadItemCacheStore();

    await store.saveThreadItems(
      profileId: 'local',
      threadId: 'thr_1',
      snapshot: ThreadItemCacheSnapshot(
        threadId: 'thr_1',
        items: [_item('item_local', 'Local item', turnId: 'turn_local')],
        nextCursor: 'older',
        backwardsCursor: 'newer',
        cachedAtMs: 123,
      ),
    );
    await store.saveThreadItems(
      profileId: 'remote',
      threadId: 'thr_1',
      snapshot: ThreadItemCacheSnapshot(
        threadId: 'thr_1',
        items: [_item('item_remote', 'Remote item')],
        cachedAtMs: 456,
      ),
    );

    final local = await store.loadThreadItems(
      profileId: 'local',
      threadId: 'thr_1',
    );
    final remote = await store.loadThreadItems(
      profileId: 'remote',
      threadId: 'thr_1',
    );

    expect(local?.items.single.id, 'item_local');
    expect(local?.items.single.text, 'Local item');
    expect(local?.items.single.turnId, 'turn_local');
    expect(local?.nextCursor, 'older');
    expect(local?.backwardsCursor, 'newer');
    expect(local?.cachedAtMs, 123);
    expect(remote?.items.single.id, 'item_remote');
  });

  test('snapshot from page preserves pagination metadata', () {
    final snapshot = ThreadItemCacheSnapshot.fromPage(
      threadId: ' thr_1 ',
      page: ThreadItemsPage(
        items: [_item('item_1', 'Recovered')],
        nextCursor: 'next',
        backwardsCursor: 'back',
      ),
      cachedAtMs: 789,
    );

    expect(snapshot.threadId, 'thr_1');
    expect(snapshot.items.single.id, 'item_1');
    expect(snapshot.nextCursor, 'next');
    expect(snapshot.backwardsCursor, 'back');
    expect(snapshot.cachedAtMs, 789);
  });

  test('ignores missing, malformed, and empty cache payloads', () async {
    SharedPreferences.setMockInitialValues({
      'threads.itemCache.v1.bG9jYWwKdGhyXzE=': 'not json',
    });
    const store = SharedPreferencesThreadItemCacheStore();

    expect(
      await store.loadThreadItems(profileId: 'missing', threadId: 'thr_1'),
      isNull,
    );
    expect(
      await store.loadThreadItems(profileId: 'local', threadId: 'thr_1'),
      isNull,
    );
  });

  test('deletes all item caches for one profile only', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesThreadItemCacheStore();

    await store.saveThreadItems(
      profileId: 'local',
      threadId: 'thr_1',
      snapshot: ThreadItemCacheSnapshot(
        threadId: 'thr_1',
        items: [_item('item_local_1', 'Local 1')],
        cachedAtMs: 1,
      ),
    );
    await store.saveThreadItems(
      profileId: 'local',
      threadId: 'thr_2',
      snapshot: ThreadItemCacheSnapshot(
        threadId: 'thr_2',
        items: [_item('item_local_2', 'Local 2')],
        cachedAtMs: 2,
      ),
    );
    await store.saveThreadItems(
      profileId: 'remote',
      threadId: 'thr_1',
      snapshot: ThreadItemCacheSnapshot(
        threadId: 'thr_1',
        items: [_item('item_remote', 'Remote')],
        cachedAtMs: 3,
      ),
    );

    await store.deleteProfileItems('local');

    expect(
      await store.loadThreadItems(profileId: 'local', threadId: 'thr_1'),
      isNull,
    );
    expect(
      await store.loadThreadItems(profileId: 'local', threadId: 'thr_2'),
      isNull,
    );
    expect(
      (await store.loadThreadItems(
        profileId: 'remote',
        threadId: 'thr_1',
      ))?.items.single.id,
      'item_remote',
    );
  });
}

ThreadItemSummary _item(String id, String text, {String? turnId}) {
  final json = <String, Object?>{
    'id': id,
    'type': 'agentMessage',
    'text': text,
  };
  if (turnId != null) {
    json['turnId'] = turnId;
  }
  return ThreadItemSummary.fromJson(json);
}
