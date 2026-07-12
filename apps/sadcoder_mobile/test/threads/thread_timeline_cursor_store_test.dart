import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sadcoder_mobile/src/threads/thread_timeline_cursor_store.dart';

void main() {
  test('persists timeline cursors per profile and thread', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesThreadTimelineCursorStore();

    await store.saveThreadCursor(
      profileId: 'local',
      threadId: 'thr_1',
      snapshot: const ThreadTimelineCursorSnapshot(
        threadId: 'thr_1',
        turnIds: ['turn_1', 'turn_2'],
        itemIds: ['item_1', 'item_2'],
        lastTurnId: 'turn_2',
        lastItemId: 'item_2',
        deliveredCursor: 'event_cursor_2',
        cachedAtMs: 123,
      ),
    );
    await store.saveThreadCursor(
      profileId: 'remote',
      threadId: 'thr_1',
      snapshot: const ThreadTimelineCursorSnapshot(
        threadId: 'thr_1',
        turnIds: ['turn_remote'],
        itemIds: [],
        lastTurnId: 'turn_remote',
        cachedAtMs: 456,
      ),
    );

    final local = await store.loadThreadCursor(
      profileId: 'local',
      threadId: 'thr_1',
    );
    final remote = await store.loadThreadCursor(
      profileId: 'remote',
      threadId: 'thr_1',
    );

    expect(local?.threadId, 'thr_1');
    expect(local?.turnIds, ['turn_1', 'turn_2']);
    expect(local?.itemIds, ['item_1', 'item_2']);
    expect(local?.lastTurnId, 'turn_2');
    expect(local?.lastItemId, 'item_2');
    expect(local?.deliveredCursor, 'event_cursor_2');
    expect(local?.cachedAtMs, 123);
    expect(remote?.turnIds, ['turn_remote']);
    expect(remote?.cachedAtMs, 456);
  });

  test('derives last ids when loading legacy cursor payloads', () async {
    SharedPreferences.setMockInitialValues({
      'threads.timelineCursor.v1.bG9jYWwKdGhyXzE=':
          '{"threadId":"thr_1","turnIds":["turn_1","turn_2"],'
          '"itemIds":["item_1","item_2"],"cachedAtMs":789}',
    });
    const store = SharedPreferencesThreadTimelineCursorStore();

    final snapshot = await store.loadThreadCursor(
      profileId: 'local',
      threadId: 'thr_1',
    );

    expect(snapshot?.lastTurnId, 'turn_2');
    expect(snapshot?.lastItemId, 'item_2');
    expect(snapshot?.cachedAtMs, 789);
  });

  test('ignores missing malformed and empty cursor payloads', () async {
    SharedPreferences.setMockInitialValues({
      'threads.timelineCursor.v1.bG9jYWwKdGhyXzE=': 'not json',
      'threads.timelineCursor.v1.bG9jYWwKdGhyXzI=':
          '{"threadId":"thr_2","turnIds":[],"itemIds":[],"cachedAtMs":1}',
    });
    const store = SharedPreferencesThreadTimelineCursorStore();

    expect(
      await store.loadThreadCursor(profileId: 'missing', threadId: 'thr_1'),
      isNull,
    );
    expect(
      await store.loadThreadCursor(profileId: 'local', threadId: 'thr_1'),
      isNull,
    );
    expect(
      await store.loadThreadCursor(profileId: 'local', threadId: 'thr_2'),
      isNull,
    );
  });
}
