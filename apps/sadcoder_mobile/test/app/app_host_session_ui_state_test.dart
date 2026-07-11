import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/app/app_host_session_ui_state.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/threads/thread_cache_store.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

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
}

class _UiStateFixture {
  _UiStateFixture({required String profileId, required ThreadCacheStore store})
    : approvalController = ApprovalStateController(),
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
