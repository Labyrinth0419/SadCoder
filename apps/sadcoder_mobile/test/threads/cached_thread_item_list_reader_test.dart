import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/threads/cached_thread_item_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_item_cache_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_item_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

void main() {
  test('caches successful canonical thread item pages', () async {
    final store = _MemoryThreadItemCacheStore();
    final remote = _FakeThreadItemListReader(
      page: ThreadItemsPage(
        items: [_item('item_remote', 'Remote item')],
        nextCursor: 'older',
        backwardsCursor: 'newer',
      ),
    );
    final reader = CachedThreadItemListReader(
      profileId: 'local',
      remoteReader: remote,
      cacheStore: store,
      clock: () => 123,
    );

    final page = await reader.listItems(threadId: 'thr_1');

    expect(page.items.single.id, 'item_remote');
    final snapshot = await store.loadThreadItems(
      profileId: 'local',
      threadId: 'thr_1',
    );
    expect(snapshot?.items.single.id, 'item_remote');
    expect(snapshot?.nextCursor, 'older');
    expect(snapshot?.backwardsCursor, 'newer');
    expect(snapshot?.cachedAtMs, 123);
  });

  test('falls back to cached canonical page when remote read fails', () async {
    final store = _MemoryThreadItemCacheStore();
    await store.saveThreadItems(
      profileId: 'local',
      threadId: 'thr_1',
      snapshot: ThreadItemCacheSnapshot(
        threadId: 'thr_1',
        items: [_item('item_cached', 'Cached item')],
        nextCursor: 'older_cached',
        cachedAtMs: 456,
      ),
    );
    final reader = CachedThreadItemListReader(
      profileId: 'local',
      remoteReader: _FailingThreadItemListReader(),
      cacheStore: store,
    );

    final page = await reader.listItems(threadId: 'thr_1');

    expect(page.items.single.id, 'item_cached');
    expect(page.nextCursor, 'older_cached');
  });

  test('does not fallback for paginated or turn-filtered item reads', () async {
    final store = _MemoryThreadItemCacheStore();
    await store.saveThreadItems(
      profileId: 'local',
      threadId: 'thr_1',
      snapshot: ThreadItemCacheSnapshot(
        threadId: 'thr_1',
        items: [_item('item_cached', 'Cached item')],
        cachedAtMs: 456,
      ),
    );
    final reader = CachedThreadItemListReader(
      profileId: 'local',
      remoteReader: _FailingThreadItemListReader(),
      cacheStore: store,
    );

    expect(
      reader.listItems(threadId: 'thr_1', cursor: 'next'),
      throwsA(isA<StateError>()),
    );
    expect(
      reader.listItems(threadId: 'thr_1', turnId: 'turn_1'),
      throwsA(isA<StateError>()),
    );
    expect(
      reader.listItems(threadId: 'thr_1', sortDirection: 'desc'),
      throwsA(isA<StateError>()),
    );
  });
}

class _MemoryThreadItemCacheStore implements ThreadItemCacheStore {
  final _snapshots = <String, ThreadItemCacheSnapshot>{};

  @override
  Future<ThreadItemCacheSnapshot?> loadThreadItems({
    required String profileId,
    required String threadId,
  }) async {
    return _snapshots['$profileId::$threadId'];
  }

  @override
  Future<void> saveThreadItems({
    required String profileId,
    required String threadId,
    required ThreadItemCacheSnapshot snapshot,
  }) async {
    _snapshots['$profileId::$threadId'] = snapshot;
  }
}

class _FakeThreadItemListReader implements ThreadItemListReader {
  const _FakeThreadItemListReader({required this.page});

  final ThreadItemsPage page;

  @override
  Future<ThreadItemsPage> listItems({
    required String threadId,
    String? turnId,
    String? cursor,
    int? limit,
    String? sortDirection,
  }) async {
    return page;
  }
}

class _FailingThreadItemListReader implements ThreadItemListReader {
  @override
  Future<ThreadItemsPage> listItems({
    required String threadId,
    String? turnId,
    String? cursor,
    int? limit,
    String? sortDirection,
  }) {
    throw StateError('remote item list failed');
  }
}

ThreadItemSummary _item(String id, String text) {
  return ThreadItemSummary.fromJson({
    'id': id,
    'type': 'agentMessage',
    'text': text,
  });
}
