import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/app/app_host_session_ui_state.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/threads/thread_cache_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_item_cache_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/threads/thread_timeline_cursor_store.dart';

void main() {
  test('restores cached thread list and selection for its host', () async {
    final store = _MemoryThreadCacheStore({
      'profile-a': ThreadCacheSnapshot(
        threads: [_thread('thr_a', 'Host A task')],
        selectedThreadId: 'thr_a',
        selectedThread: _threadWithTurn('thr_a', 'Host A task'),
        cachedAtMs: 1,
      ),
      'profile-b': ThreadCacheSnapshot(
        threads: [_thread('thr_b', 'Host B task')],
        selectedThreadId: 'thr_b',
        cachedAtMs: 2,
      ),
    });
    final fixture = _UiStateFixture(profileId: 'profile-a', store: store);
    addTearDown(fixture.dispose);

    await fixture.state.restoreCachedThreadState();

    expect(fixture.state.threadListController.threads.single.id, 'thr_a');
    expect(fixture.state.threadDetailController.selectedThreadId, 'thr_a');
    expect(fixture.state.threadDetailController.detail?.thread.id, 'thr_a');
    expect(
      fixture.state.threadDetailController.detail?.thread.turns.single.id,
      'turn_thr_a',
    );
    expect(fixture.state.turnController.activeThreadId, 'thr_a');
  });

  test(
    'persists loaded thread summaries and active selection by host',
    () async {
      final store = _MemoryThreadCacheStore();
      final fixture = _UiStateFixture(profileId: 'profile-a', store: store);
      addTearDown(fixture.dispose);

      fixture.state.threadListController.restoreCached([
        _thread('thr_saved', 'Saved task'),
      ]);
      fixture.state.threadDetailController.restoreCachedDetail(
        _threadWithTurn('thr_saved', 'Saved task'),
      );
      await Future<void>.delayed(Duration.zero);

      final snapshot = store.snapshots['profile-a'];
      expect(snapshot?.threads.single.id, 'thr_saved');
      expect(snapshot?.selectedThreadId, 'thr_saved');
      expect(snapshot?.selectedThread?.id, 'thr_saved');
      expect(snapshot?.selectedThread?.turns.single.id, 'turn_thr_saved');
      expect(store.snapshots.keys, ['profile-a']);
    },
  );

  test('restores cached selected thread items into timeline', () async {
    final threadStore = _MemoryThreadCacheStore({
      'profile-a': ThreadCacheSnapshot(
        threads: [_thread('thr_a', 'Host A task')],
        selectedThreadId: 'thr_a',
        cachedAtMs: 1,
      ),
    });
    final itemStore = _MemoryThreadItemCacheStore({
      'profile-a::thr_a': ThreadItemCacheSnapshot(
        threadId: 'thr_a',
        items: [_item('item_cached', 'Cached answer', turnId: 'turn_cached')],
        cachedAtMs: 2,
      ),
    });
    final fixture = _UiStateFixture(
      profileId: 'profile-a',
      store: threadStore,
      itemStore: itemStore,
    );
    addTearDown(fixture.dispose);

    await fixture.state.restoreCachedThreadState();

    expect(fixture.state.threadDetailController.selectedThreadId, 'thr_a');
    expect(fixture.state.timelineController.selectedThreadId, 'thr_a');
    expect(fixture.state.timelineController.turns.single.turnId, 'turn_cached');
    expect(
      fixture.state.timelineController.turns.single.items.single.text,
      'Cached answer',
    );
  });

  test('persists timeline cursor for its host', () async {
    final threadStore = _MemoryThreadCacheStore();
    final cursorStore = _MemoryThreadTimelineCursorStore();
    final fixture = _UiStateFixture(
      profileId: 'profile-a',
      store: threadStore,
      timelineCursorStore: cursorStore,
    );
    addTearDown(fixture.dispose);

    fixture.state.timelineController.showThread(
      _threadWithTurnAndItem('thr_a', 'Host A task'),
    );
    await Future<void>.delayed(Duration.zero);

    final snapshot = cursorStore.snapshots['profile-a::thr_a'];
    expect(snapshot?.threadId, 'thr_a');
    expect(snapshot?.turnIds, ['turn_thr_a']);
    expect(snapshot?.itemIds, ['item_thr_a']);
    expect(snapshot?.lastTurnId, 'turn_thr_a');
    expect(snapshot?.lastItemId, 'item_thr_a');
    expect(cursorStore.snapshots.keys, ['profile-a::thr_a']);
  });
}

class _UiStateFixture {
  _UiStateFixture({
    required String profileId,
    required ThreadCacheStore store,
    ThreadItemCacheStore? itemStore,
    ThreadTimelineCursorStore? timelineCursorStore,
  }) : approvalController = ApprovalStateController(),
       configOverrideController = CodexConfigOverrideController() {
    sessionController = CodexSessionStateController(
      connector: _NeverConnectStarter(),
      approvalController: approvalController,
    );
    state = AppHostSessionUiState(
      sessionController: sessionController,
      configOverrideController: configOverrideController,
      threadCacheProfileId: profileId,
      threadCacheStore: store,
      threadItemCacheStore: itemStore,
      threadTimelineCursorStore: timelineCursorStore,
    );
  }

  final ApprovalStateController approvalController;
  final CodexConfigOverrideController configOverrideController;
  late final CodexSessionStateController sessionController;
  late final AppHostSessionUiState state;

  void dispose() {
    state.dispose();
    sessionController.dispose();
    configOverrideController.dispose();
    approvalController.dispose();
  }
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

class _MemoryThreadItemCacheStore implements ThreadItemCacheStore {
  _MemoryThreadItemCacheStore([Map<String, ThreadItemCacheSnapshot>? initial])
    : snapshots = Map.of(initial ?? const {});

  final Map<String, ThreadItemCacheSnapshot> snapshots;

  @override
  Future<ThreadItemCacheSnapshot?> loadThreadItems({
    required String profileId,
    required String threadId,
  }) async {
    return snapshots['$profileId::$threadId'];
  }

  @override
  Future<void> saveThreadItems({
    required String profileId,
    required String threadId,
    required ThreadItemCacheSnapshot snapshot,
  }) async {
    snapshots['$profileId::$threadId'] = snapshot;
  }
}

class _MemoryThreadTimelineCursorStore implements ThreadTimelineCursorStore {
  final snapshots = <String, ThreadTimelineCursorSnapshot>{};

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

class _NeverConnectStarter implements CodexSessionConnectionStarter {
  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) {
    throw UnimplementedError();
  }
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
    'updatedAt': 1,
    'turns': [
      {'id': 'turn_$id', 'status': 'completed', 'items': <Object?>[]},
    ],
  });
}

ThreadSummary _threadWithTurnAndItem(String id, String preview) {
  return ThreadSummary.fromJson({
    'id': id,
    'sessionId': 'sess_1',
    'preview': preview,
    'ephemeral': false,
    'status': 'idle',
    'cwd': '/repo',
    'updatedAt': 42,
    'turns': [
      {
        'id': 'turn_$id',
        'status': 'completed',
        'items': [
          {'id': 'item_$id', 'type': 'agentMessage', 'text': 'Cached answer'},
        ],
      },
    ],
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
