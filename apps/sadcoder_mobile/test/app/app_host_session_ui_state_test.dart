import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/agent/agent_snapshot.dart';
import 'package:sadcoder_mobile/src/agent/agent_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/app/app_host_session_ui_state.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_manifest_reader.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_registry.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/threads/thread_cache_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_item_cache_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/threads/thread_timeline_cursor_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_turn_list_reader.dart';

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

  test('persists agent delivered cursor for snapshot thread', () async {
    final threadStore = _MemoryThreadCacheStore();
    final cursorStore = _MemoryThreadTimelineCursorStore({
      'profile-a::thr_a': const ThreadTimelineCursorSnapshot(
        threadId: 'thr_a',
        turnIds: ['turn_existing'],
        itemIds: ['item_existing'],
        lastTurnId: 'turn_existing',
        lastItemId: 'item_existing',
        cachedAtMs: 1,
      ),
    });
    final approvalController = ApprovalStateController();
    final configOverrideController = CodexConfigOverrideController();
    final sessionController = CodexSessionStateController(
      connector: _SnapshotSessionStarter(
        snapshot: const AgentSnapshot(
          schemaVersion: 1,
          pendingApprovals: [],
          recentEvents: [
            AgentCachedEvent(
              method: 'turn/started',
              cursor: 'event-7',
              params: {
                'threadId': 'thr_a',
                'turn': {
                  'id': 'turn_existing',
                  'status': 'completed',
                  'items': <Object?>[],
                },
              },
            ),
          ],
          deliveredCursor: 'event-7',
        ),
      ),
      approvalController: approvalController,
    );
    final state = AppHostSessionUiState(
      sessionController: sessionController,
      configOverrideController: configOverrideController,
      threadCacheProfileId: 'profile-a',
      threadCacheStore: threadStore,
      threadTimelineCursorStore: cursorStore,
    );
    addTearDown(state.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(configOverrideController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profileA);
    await _flushMicrotasks();

    final snapshot = cursorStore.snapshots['profile-a::thr_a'];
    expect(snapshot?.deliveredCursor, 'event-7');
    expect(snapshot?.turnIds, ['turn_existing']);
    expect(snapshot?.itemIds, ['item_existing']);
    expect(snapshot?.lastTurnId, 'turn_existing');
    expect(snapshot?.lastItemId, 'item_existing');
  });

  test('persists per-thread cursor from agent thread snapshot', () async {
    final threadStore = _MemoryThreadCacheStore();
    final cursorStore = _MemoryThreadTimelineCursorStore({
      'profile-a::thr_a': const ThreadTimelineCursorSnapshot(
        threadId: 'thr_a',
        turnIds: ['turn_existing'],
        itemIds: ['item_existing'],
        lastTurnId: 'turn_existing',
        lastItemId: 'item_existing',
        cachedAtMs: 1,
      ),
    });
    final approvalController = ApprovalStateController();
    final configOverrideController = CodexConfigOverrideController();
    final sessionController = CodexSessionStateController(
      connector: _SnapshotSessionStarter(
        snapshot: const AgentSnapshot(
          schemaVersion: 1,
          pendingApprovals: [],
          recentEvents: [],
          threads: [
            AgentCachedThread(
              threadId: 'thr_a',
              lastTurnId: 'turn_existing',
              lastItemId: 'item_existing',
              lastEventCursor: 'event-7',
            ),
          ],
          deliveredCursor: 'event-9',
        ),
      ),
      approvalController: approvalController,
    );
    final state = AppHostSessionUiState(
      sessionController: sessionController,
      configOverrideController: configOverrideController,
      threadCacheProfileId: 'profile-a',
      threadCacheStore: threadStore,
      threadTimelineCursorStore: cursorStore,
    );
    addTearDown(state.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(configOverrideController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profileA);
    await _flushMicrotasks();

    final snapshot = cursorStore.snapshots['profile-a::thr_a'];
    expect(snapshot?.deliveredCursor, 'event-7');
    expect(snapshot?.turnIds, ['turn_existing']);
    expect(snapshot?.itemIds, ['item_existing']);
    expect(snapshot?.lastTurnId, 'turn_existing');
    expect(snapshot?.lastItemId, 'item_existing');
  });

  test(
    'persists turn and item boundaries from agent thread snapshot',
    () async {
      final threadStore = _MemoryThreadCacheStore();
      final cursorStore = _MemoryThreadTimelineCursorStore();
      final approvalController = ApprovalStateController();
      final configOverrideController = CodexConfigOverrideController();
      final sessionController = CodexSessionStateController(
        connector: _SnapshotSessionStarter(
          snapshot: const AgentSnapshot(
            schemaVersion: 1,
            pendingApprovals: [],
            recentEvents: [],
            threads: [
              AgentCachedThread(
                threadId: 'thr_a',
                lastTurnId: 'turn_snapshot',
                lastItemId: 'item_snapshot',
                lastEventCursor: 'event-7',
              ),
            ],
          ),
        ),
        approvalController: approvalController,
      );
      final state = AppHostSessionUiState(
        sessionController: sessionController,
        configOverrideController: configOverrideController,
        threadCacheProfileId: 'profile-a',
        threadCacheStore: threadStore,
        threadTimelineCursorStore: cursorStore,
      );
      addTearDown(state.dispose);
      addTearDown(sessionController.dispose);
      addTearDown(configOverrideController.dispose);
      addTearDown(approvalController.dispose);

      await sessionController.connect(_profileA);
      await _flushMicrotasks();

      final snapshot = cursorStore.snapshots['profile-a::thr_a'];
      expect(snapshot?.deliveredCursor, 'event-7');
      expect(snapshot?.lastTurnId, 'turn_snapshot');
      expect(snapshot?.lastItemId, 'item_snapshot');
    },
  );

  test('merges recent event cursor with agent thread boundaries', () async {
    final threadStore = _MemoryThreadCacheStore();
    final cursorStore = _MemoryThreadTimelineCursorStore();
    final approvalController = ApprovalStateController();
    final configOverrideController = CodexConfigOverrideController();
    final sessionController = CodexSessionStateController(
      connector: _SnapshotSessionStarter(
        snapshot: const AgentSnapshot(
          schemaVersion: 1,
          pendingApprovals: [],
          recentEvents: [
            AgentCachedEvent(
              method: 'thread/item',
              cursor: 'event-8',
              params: {'threadId': 'thr_a'},
            ),
          ],
          threads: [
            AgentCachedThread(
              threadId: 'thr_a',
              lastTurnId: 'turn_snapshot',
              lastItemId: 'item_snapshot',
              lastEventCursor: 'event-7',
            ),
          ],
        ),
      ),
      approvalController: approvalController,
    );
    final state = AppHostSessionUiState(
      sessionController: sessionController,
      configOverrideController: configOverrideController,
      threadCacheProfileId: 'profile-a',
      threadCacheStore: threadStore,
      threadTimelineCursorStore: cursorStore,
    );
    addTearDown(state.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(configOverrideController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profileA);
    await _flushMicrotasks();

    final snapshot = cursorStore.snapshots['profile-a::thr_a'];
    expect(snapshot?.deliveredCursor, 'event-8');
    expect(snapshot?.lastTurnId, 'turn_snapshot');
    expect(snapshot?.lastItemId, 'item_snapshot');
  });

  test('loads agent snapshot cursor from cached selected thread', () async {
    final threadStore = _MemoryThreadCacheStore({
      'profile-a': ThreadCacheSnapshot(
        threads: [_thread('thr_a', 'Host A task')],
        selectedThreadId: 'thr_a',
        cachedAtMs: 1,
      ),
    });
    final cursorStore = _MemoryThreadTimelineCursorStore({
      'profile-a::thr_a': const ThreadTimelineCursorSnapshot(
        threadId: 'thr_a',
        turnIds: [],
        itemIds: [],
        deliveredCursor: 'event-9',
        cachedAtMs: 2,
      ),
    });
    final fixture = _UiStateFixture(
      profileId: 'profile-a',
      store: threadStore,
      timelineCursorStore: cursorStore,
    );
    addTearDown(fixture.dispose);

    final cursor = await fixture.state.loadAgentSnapshotCursor(_profileA);

    expect(cursor, 'event-9');
  });

  test('observes session status and refreshes threads after connect', () async {
    final threadStore = _MemoryThreadCacheStore();
    final threadListReader = _RecordingThreadListReader([
      _thread('thr_connected', 'Connected task'),
    ]);
    final approvalController = ApprovalStateController();
    final configOverrideController = CodexConfigOverrideController();
    final sessionController = CodexSessionStateController(
      connector: _ThreadListSessionStarter(threadListReader),
      approvalController: approvalController,
    );
    final state = AppHostSessionUiState(
      sessionController: sessionController,
      configOverrideController: configOverrideController,
      threadCacheProfileId: 'profile-a',
      threadCacheStore: threadStore,
    );
    addTearDown(state.dispose);
    addTearDown(sessionController.dispose);
    addTearDown(configOverrideController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profileA);
    await _flushMicrotasks();

    expect(threadListReader.limits, [20]);
    expect(state.threadListController.threads.single.id, 'thr_connected');
  });

  test(
    'conservatively recovers a thread selected after snapshot cursor gap',
    () async {
      final threadStore = _MemoryThreadCacheStore();
      final cursorStore = _MemoryThreadTimelineCursorStore({
        'profile-a::thr_gap': const ThreadTimelineCursorSnapshot(
          threadId: 'thr_gap',
          turnIds: ['turn_seen'],
          itemIds: [],
          lastTurnId: 'turn_seen',
          cachedAtMs: 1,
        ),
      });
      final detailReader = _RecordingThreadDetailReader();
      final turnListReader = _RecordingThreadTurnListReader.pages([
        ThreadTurnsPage(
          turns: [_turn('turn_new', 'new'), _turn('turn_seen', 'seen updated')],
          nextCursor: 'older_turns',
        ),
        ThreadTurnsPage(turns: [_turn('turn_old', 'old')]),
      ]);
      final approvalController = ApprovalStateController();
      final configOverrideController = CodexConfigOverrideController();
      final sessionController = CodexSessionStateController(
        connector: _RecoverySnapshotSessionStarter(
          snapshot: const AgentSnapshot(
            schemaVersion: 1,
            pendingApprovals: [],
            recentEvents: [
              AgentCachedEvent(
                method: 'turn/started',
                cursor: 'event-9',
                params: {
                  'threadId': 'thr_gap',
                  'turn': {
                    'id': 'turn_new',
                    'status': 'completed',
                    'items': <Object?>[],
                  },
                },
              ),
            ],
            deliveredCursor: 'event-9',
            cursorGap: true,
          ),
          threadDetailReader: detailReader,
          threadTurnListReader: turnListReader,
        ),
        approvalController: approvalController,
      );
      final state = AppHostSessionUiState(
        sessionController: sessionController,
        configOverrideController: configOverrideController,
        threadCacheProfileId: 'profile-a',
        threadCacheStore: threadStore,
        threadTimelineCursorStore: cursorStore,
      );
      addTearDown(state.dispose);
      addTearDown(sessionController.dispose);
      addTearDown(configOverrideController.dispose);
      addTearDown(approvalController.dispose);

      await sessionController.connect(_profileA);
      await _flushMicrotasks();

      expect(detailReader.calls, isEmpty);

      await state.threadDetailController.readThread('thr_gap');
      await _flushMicrotasks();

      expect(detailReader.calls, [
        (threadId: 'thr_gap', includeTurns: true),
        (threadId: 'thr_gap', includeTurns: false),
      ]);
      expect(turnListReader.calls, [
        (
          threadId: 'thr_gap',
          cursor: null,
          limit: 50,
          sortDirection: 'desc',
          itemsView: 'full',
        ),
        (
          threadId: 'thr_gap',
          cursor: 'older_turns',
          limit: 50,
          sortDirection: 'desc',
          itemsView: 'full',
        ),
      ]);
      expect(
        state.threadDetailController.detail?.turns.map((turn) => turn.id),
        ['turn_old', 'turn_seen', 'turn_new'],
      );
    },
  );

  test(
    'conservatively recovers a thread selected after thread snapshot gap',
    () async {
      final threadStore = _MemoryThreadCacheStore();
      final cursorStore = _MemoryThreadTimelineCursorStore({
        'profile-a::thr_gap': const ThreadTimelineCursorSnapshot(
          threadId: 'thr_gap',
          turnIds: ['turn_seen'],
          itemIds: [],
          lastTurnId: 'turn_seen',
          deliveredCursor: 'event-4',
          cachedAtMs: 1,
        ),
      });
      final detailReader = _RecordingThreadDetailReader();
      final turnListReader = _RecordingThreadTurnListReader.pages([
        ThreadTurnsPage(
          turns: [_turn('turn_new', 'new'), _turn('turn_seen', 'seen updated')],
        ),
      ]);
      final approvalController = ApprovalStateController();
      final configOverrideController = CodexConfigOverrideController();
      final sessionController = CodexSessionStateController(
        connector: _RecoverySnapshotSessionStarter(
          snapshot: const AgentSnapshot(
            schemaVersion: 1,
            pendingApprovals: [],
            recentEvents: [],
            threads: [
              AgentCachedThread(
                threadId: 'thr_gap',
                lastTurnId: 'turn_new',
                lastEventCursor: 'event-9',
              ),
            ],
            deliveredCursor: 'event-9',
            cursorGap: true,
          ),
          threadDetailReader: detailReader,
          threadTurnListReader: turnListReader,
        ),
        approvalController: approvalController,
      );
      final state = AppHostSessionUiState(
        sessionController: sessionController,
        configOverrideController: configOverrideController,
        threadCacheProfileId: 'profile-a',
        threadCacheStore: threadStore,
        threadTimelineCursorStore: cursorStore,
      );
      addTearDown(state.dispose);
      addTearDown(sessionController.dispose);
      addTearDown(configOverrideController.dispose);
      addTearDown(approvalController.dispose);

      await sessionController.connect(_profileA);
      await _flushMicrotasks();

      expect(detailReader.calls, isEmpty);

      await state.threadDetailController.readThread('thr_gap');
      await _flushMicrotasks();

      expect(detailReader.calls, [
        (threadId: 'thr_gap', includeTurns: true),
        (threadId: 'thr_gap', includeTurns: false),
      ]);
      expect(turnListReader.calls, [
        (
          threadId: 'thr_gap',
          cursor: null,
          limit: 50,
          sortDirection: 'desc',
          itemsView: 'full',
        ),
      ]);
      expect(
        state.threadDetailController.detail?.turns.map((turn) => turn.id),
        ['turn_seen', 'turn_new'],
      );
    },
  );

  test(
    'conservatively recovers a thread selected after unknown snapshot gap',
    () async {
      final threadStore = _MemoryThreadCacheStore();
      final cursorStore = _MemoryThreadTimelineCursorStore({
        'profile-a::thr_gap': const ThreadTimelineCursorSnapshot(
          threadId: 'thr_gap',
          turnIds: ['turn_seen'],
          itemIds: [],
          lastTurnId: 'turn_seen',
          cachedAtMs: 1,
        ),
      });
      final detailReader = _RecordingThreadDetailReader();
      final turnListReader = _RecordingThreadTurnListReader.pages([
        ThreadTurnsPage(
          turns: [_turn('turn_new', 'new'), _turn('turn_seen', 'seen updated')],
          nextCursor: 'older_turns',
        ),
        ThreadTurnsPage(turns: [_turn('turn_old', 'old')]),
      ]);
      final approvalController = ApprovalStateController();
      final configOverrideController = CodexConfigOverrideController();
      final sessionController = CodexSessionStateController(
        connector: _RecoverySnapshotSessionStarter(
          snapshot: const AgentSnapshot(
            schemaVersion: 1,
            pendingApprovals: [],
            recentEvents: [],
            deliveredCursor: 'event-9',
            cursorGap: true,
          ),
          threadDetailReader: detailReader,
          threadTurnListReader: turnListReader,
        ),
        approvalController: approvalController,
      );
      final state = AppHostSessionUiState(
        sessionController: sessionController,
        configOverrideController: configOverrideController,
        threadCacheProfileId: 'profile-a',
        threadCacheStore: threadStore,
        threadTimelineCursorStore: cursorStore,
      );
      addTearDown(state.dispose);
      addTearDown(sessionController.dispose);
      addTearDown(configOverrideController.dispose);
      addTearDown(approvalController.dispose);

      await sessionController.connect(_profileA);
      await _flushMicrotasks();

      expect(detailReader.calls, isEmpty);

      await state.threadDetailController.readThread('thr_gap');
      await _flushMicrotasks();

      expect(detailReader.calls, [
        (threadId: 'thr_gap', includeTurns: true),
        (threadId: 'thr_gap', includeTurns: false),
      ]);
      expect(turnListReader.calls, [
        (
          threadId: 'thr_gap',
          cursor: null,
          limit: 50,
          sortDirection: 'desc',
          itemsView: 'full',
        ),
        (
          threadId: 'thr_gap',
          cursor: 'older_turns',
          limit: 50,
          sortDirection: 'desc',
          itemsView: 'full',
        ),
      ]);
      expect(
        state.threadDetailController.detail?.turns.map((turn) => turn.id),
        ['turn_old', 'turn_seen', 'turn_new'],
      );
    },
  );
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

class _NeverConnectStarter implements CodexSessionConnectionStarter {
  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) {
    throw UnimplementedError();
  }
}

class _SnapshotSessionStarter implements CodexSessionConnectionStarter {
  const _SnapshotSessionStarter({required this.snapshot});

  final AgentSnapshot snapshot;

  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    return _SnapshotConnection(
      profile: profile,
      snapshotReader: _StaticAgentSnapshotReader(snapshot),
    );
  }
}

class _RecoverySnapshotSessionStarter implements CodexSessionConnectionStarter {
  const _RecoverySnapshotSessionStarter({
    required this.snapshot,
    required this.threadDetailReader,
    required this.threadTurnListReader,
  });

  final AgentSnapshot snapshot;
  final ThreadDetailReader threadDetailReader;
  final ThreadTurnListReader threadTurnListReader;

  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    return _RecoverySnapshotConnection(
      profile: profile,
      snapshotReader: _StaticAgentSnapshotReader(snapshot),
      threadDetailReader: threadDetailReader,
      threadTurnListReader: threadTurnListReader,
    );
  }
}

class _SnapshotConnection
    implements CodexSessionConnectionHandle, AgentSnapshotConnectionHandle {
  _SnapshotConnection({required this.profile, required this.snapshotReader});

  final _events = StreamController<CodexEvent>.broadcast();
  final _done = Completer<void>();

  @override
  final SshProfile profile;

  final AgentSnapshotReader snapshotReader;

  @override
  AgentSnapshotReader? get agentSnapshotReader => snapshotReader;

  @override
  ThreadListReader get threadListReader => const _EmptyThreadListReader();

  @override
  SlashCommandManifestReader get slashCommandManifestReader =>
      const _EmptySlashCommandManifestReader();

  @override
  Stream<CodexEvent> get events => _events.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<Map<String, Object?>> stopBackend() async {
    return {'stopped': true};
  }

  @override
  Future<void> close({bool notifyApprovalController = true}) async {
    await _events.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThreadListSessionStarter implements CodexSessionConnectionStarter {
  const _ThreadListSessionStarter(this.threadListReader);

  final ThreadListReader threadListReader;

  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    return _ThreadListConnection(
      profile: profile,
      threadListReader: threadListReader,
    );
  }
}

class _RecoverySnapshotConnection
    implements CodexSessionConnectionHandle, AgentSnapshotConnectionHandle {
  _RecoverySnapshotConnection({
    required this.profile,
    required this.snapshotReader,
    required this.threadDetailReader,
    required this.threadTurnListReader,
  });

  final _events = StreamController<CodexEvent>.broadcast();
  final _done = Completer<void>();

  @override
  final SshProfile profile;

  final AgentSnapshotReader snapshotReader;

  @override
  AgentSnapshotReader? get agentSnapshotReader => snapshotReader;

  @override
  ThreadListReader get threadListReader => const _EmptyThreadListReader();

  @override
  final ThreadDetailReader threadDetailReader;

  @override
  final ThreadTurnListReader threadTurnListReader;

  @override
  SlashCommandManifestReader get slashCommandManifestReader =>
      const _EmptySlashCommandManifestReader();

  @override
  Stream<CodexEvent> get events => _events.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<Map<String, Object?>> stopBackend() async {
    return {'stopped': true};
  }

  @override
  Future<void> close({bool notifyApprovalController = true}) async {
    await _events.close();
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThreadListConnection implements CodexSessionConnectionHandle {
  _ThreadListConnection({
    required this.profile,
    required this.threadListReader,
  });

  final _events = StreamController<CodexEvent>.broadcast();
  final _done = Completer<void>();

  @override
  final SshProfile profile;

  @override
  final ThreadListReader threadListReader;

  @override
  SlashCommandManifestReader get slashCommandManifestReader =>
      const _EmptySlashCommandManifestReader();

  @override
  Stream<CodexEvent> get events => _events.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<Map<String, Object?>> stopBackend() async {
    return {'stopped': true};
  }

  @override
  Future<void> close({bool notifyApprovalController = true}) async {
    await _events.close();
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyThreadListReader implements ThreadListReader {
  const _EmptyThreadListReader();

  @override
  Future<ThreadListPage> listThreads({
    int limit = 20,
    bool archived = false,
  }) async {
    return const ThreadListPage(threads: []);
  }
}

class _RecordingThreadListReader implements ThreadListReader {
  _RecordingThreadListReader(this.threads);

  final List<ThreadSummary> threads;
  final limits = <int>[];

  @override
  Future<ThreadListPage> listThreads({
    int limit = 20,
    bool archived = false,
  }) async {
    limits.add(limit);
    return ThreadListPage(threads: threads);
  }
}

class _RecordingThreadDetailReader implements ThreadDetailReader {
  final calls = <({String threadId, bool includeTurns})>[];

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    calls.add((threadId: threadId, includeTurns: includeTurns));
    return ThreadDetail(thread: _thread(threadId, threadId));
  }
}

class _RecordingThreadTurnListReader implements ThreadTurnListReader {
  _RecordingThreadTurnListReader.pages(this.pages);

  final List<ThreadTurnsPage> pages;
  final calls =
      <
        ({
          String threadId,
          String? cursor,
          int? limit,
          String? sortDirection,
          String? itemsView,
        })
      >[];

  @override
  Future<ThreadTurnsPage> listTurns({
    required String threadId,
    String? cursor,
    int? limit,
    String? sortDirection,
    String? itemsView,
  }) async {
    calls.add((
      threadId: threadId,
      cursor: cursor,
      limit: limit,
      sortDirection: sortDirection,
      itemsView: itemsView,
    ));
    final pageIndex = calls.length - 1;
    if (pageIndex >= pages.length) {
      return const ThreadTurnsPage(turns: []);
    }
    return pages[pageIndex];
  }
}

class _EmptySlashCommandManifestReader implements SlashCommandManifestReader {
  const _EmptySlashCommandManifestReader();

  @override
  Future<SlashCommandManifest> readSlashCommands(SshProfile profile) async {
    return const SlashCommandManifest(
      schemaVersion: 1,
      source: 'test',
      commands: [],
    );
  }
}

class _StaticAgentSnapshotReader implements AgentSnapshotReader {
  const _StaticAgentSnapshotReader(this.snapshot);

  final AgentSnapshot snapshot;

  @override
  Future<AgentSnapshot> readSnapshot(
    SshProfile profile, {
    String? sinceCursor,
  }) async {
    return snapshot;
  }
}

const _profileA = SshProfile(
  id: 'profile-a',
  name: 'Host A',
  host: 'host-a.example.com',
  username: 'dev',
);

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

TurnSummary _turn(String id, String text) {
  return TurnSummary.fromJson({
    'id': id,
    'status': 'completed',
    'itemsView': 'full',
    'items': [
      {'id': 'item_$id', 'type': 'agentMessage', 'text': text},
    ],
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
