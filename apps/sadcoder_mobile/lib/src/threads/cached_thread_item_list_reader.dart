import 'thread_item_cache_store.dart';
import 'thread_item_list_reader.dart';
import 'thread_summary.dart';

typedef ThreadItemCacheClock = int Function();

class CachedThreadItemListReader implements ThreadItemListReader {
  const CachedThreadItemListReader({
    required this.profileId,
    required this.remoteReader,
    required this.cacheStore,
    this.clock = _systemClock,
  });

  final String profileId;
  final ThreadItemListReader remoteReader;
  final ThreadItemCacheStore cacheStore;
  final ThreadItemCacheClock clock;

  @override
  Future<ThreadItemsPage> listItems({
    required String threadId,
    String? turnId,
    String? cursor,
    int? limit,
    String? sortDirection,
  }) async {
    final cacheable = _isCacheableRequest(
      threadId: threadId,
      turnId: turnId,
      cursor: cursor,
      sortDirection: sortDirection,
    );
    try {
      final page = await remoteReader.listItems(
        threadId: threadId,
        turnId: turnId,
        cursor: cursor,
        limit: limit,
        sortDirection: sortDirection,
      );
      if (cacheable) {
        await cacheStore.saveThreadItems(
          profileId: profileId,
          threadId: threadId,
          snapshot: ThreadItemCacheSnapshot.fromPage(
            threadId: threadId,
            page: page,
            cachedAtMs: clock(),
          ),
        );
      }
      return page;
    } on Object {
      if (!cacheable) {
        rethrow;
      }
      final snapshot = await cacheStore.loadThreadItems(
        profileId: profileId,
        threadId: threadId,
      );
      if (snapshot == null) {
        rethrow;
      }
      return snapshot.toPage();
    }
  }

  bool _isCacheableRequest({
    required String threadId,
    String? turnId,
    String? cursor,
    String? sortDirection,
  }) {
    return _nonEmpty(threadId) != null &&
        _nonEmpty(turnId) == null &&
        _nonEmpty(cursor) == null &&
        _canonicalSortDirection(sortDirection);
  }
}

int _systemClock() => DateTime.now().millisecondsSinceEpoch;

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _canonicalSortDirection(String? value) {
  final trimmed = _nonEmpty(value);
  return trimmed == null || trimmed == 'asc';
}
