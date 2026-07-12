import 'dart:async';

import '../agent/agent_snapshot.dart';
import '../commands/slash_command_manifest_reader.dart';
import '../commands/slash_command_registry_controller.dart';
import '../config/codex_config_override_controller.dart';
import '../features/chat/chat_timeline_controller.dart';
import '../session/codex_session_state_controller.dart';
import '../ssh/ssh_profile.dart';
import '../threads/thread_cache_store.dart';
import '../threads/thread_detail_controller.dart';
import '../threads/thread_item_cache_store.dart';
import '../threads/thread_list_controller.dart';
import '../threads/thread_summary.dart';
import '../threads/thread_timeline_cursor_store.dart';
import '../turns/turn_controller.dart';
import 'agent_snapshot_cursor_provider.dart';
import 'app_session_recovery_coordinator.dart';

class AppHostSessionUiState {
  AppHostSessionUiState({
    required this.sessionController,
    required CodexConfigOverrideController configOverrideController,
    this.threadCacheProfileId,
    this.threadCacheStore,
    this.threadItemCacheStore,
    this.threadTimelineCursorStore,
    SlashCommandManifestReader? fallbackSlashCommandManifestReader,
  }) {
    threadListController = ThreadListController(
      readerProvider: () => sessionController.threadListReader,
    );
    threadDetailController = ThreadDetailController(
      readerProvider: () => sessionController.threadDetailReader,
    );
    turnController = TurnController(
      runnerProvider: () => sessionController.turnRunner,
      activeThreadIdProvider: () => threadDetailController.selectedThreadId,
      overrideLayersProvider: () => configOverrideController.layers,
    );
    timelineController = ChatTimelineController(
      onTurnStarted: ({required threadId, required turn}) {
        turnController.trackStartedTurn(threadId: threadId, turn: turn);
      },
      onTurnCompleted: ({required threadId, required turn}) {
        turnController.finishTurn(threadId: threadId, turn: turn);
      },
    );
    slashCommandRegistryController = SlashCommandRegistryController(
      readerProvider: () =>
          sessionController.slashCommandManifestReader ??
          fallbackSlashCommandManifestReader,
    );
    _agentSnapshotCursorProvider = AppAgentSnapshotCursorProvider(
      profileId: threadCacheProfileId,
      threadCacheStore: threadCacheStore,
      threadTimelineCursorStore: threadTimelineCursorStore,
      selectedThreadIdProvider: () =>
          _normalized(timelineController.selectedThreadId) ??
          _normalized(threadDetailController.selectedThreadId),
      deliveredCursorProvider: (threadId) =>
          _deliveredCursorByThreadId[threadId],
    );
    _sessionRecoveryCoordinator = AppSessionRecoveryCoordinator(
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      threadTurnListReaderProvider: () =>
          sessionController.threadTurnListReader,
      threadItemListReaderProvider: () =>
          sessionController.threadItemListReader,
      threadItemRecoveryHandler: timelineController.restoreThreadItems,
      threadRecoveryHintProvider: _loadRecoveryHint,
    );
    threadListController.addListener(_handleThreadListChanged);
    threadDetailController.addListener(_handleThreadDetailChanged);
    turnController.addListener(_handleTurnChanged);
    timelineController.addListener(_handleTimelineChanged);
    _agentSnapshotSubscription = sessionController.agentSnapshots.listen(
      _handleAgentSnapshot,
      onError: (_) {},
    );
    sessionController.addListener(_handleSessionControllerChanged);
    handleSessionStatus(sessionController.status);
    unawaited(_restoreCachedThreadStateOnce().catchError((Object _) {}));
  }

  final CodexSessionStateController sessionController;
  final String? threadCacheProfileId;
  final ThreadCacheStore? threadCacheStore;
  final ThreadItemCacheStore? threadItemCacheStore;
  final ThreadTimelineCursorStore? threadTimelineCursorStore;
  late final ThreadListController threadListController;
  late final ThreadDetailController threadDetailController;
  late final TurnController turnController;
  late final ChatTimelineController timelineController;
  late final SlashCommandRegistryController slashCommandRegistryController;
  late final AppSessionRecoveryCoordinator _sessionRecoveryCoordinator;
  late final AppAgentSnapshotCursorProvider _agentSnapshotCursorProvider;
  late final StreamSubscription<AgentSnapshot> _agentSnapshotSubscription;
  Future<void>? _restoreCachedThreadStateFuture;
  String? _lastPersistedTimelineCursorFingerprint;
  final Map<String, String> _deliveredCursorByThreadId = {};
  final Set<String> _cursorGapThreadIds = {};
  bool _restoringCachedThreadState = false;
  bool _disposed = false;

  void attachEvents() {
    timelineController.attach(sessionController.events);
  }

  void detachEvents() {
    timelineController.attach(null);
  }

  void handleSessionStatus(CodexSessionStatus status) {
    if (status == CodexSessionStatus.connected) {
      unawaited(
        _restoreCachedThreadStateOnce()
            .then((_) {
              if (_disposed ||
                  sessionController.status != CodexSessionStatus.connected) {
                return;
              }
              _sessionRecoveryCoordinator.handleSessionStatus(status);
            })
            .catchError((Object _) {}),
      );
      final profile = sessionController.profile;
      if (profile != null) {
        unawaited(slashCommandRegistryController.refresh(profile));
      }
      return;
    }
    _sessionRecoveryCoordinator.handleSessionStatus(status);
    slashCommandRegistryController.reset();
  }

  Future<void> restoreCachedThreadState() async {
    await _restoreCachedThreadStateOnce();
  }

  Future<void> _restoreCachedThreadStateOnce() {
    return _restoreCachedThreadStateFuture ??= _restoreCachedThreadState();
  }

  Future<void> _restoreCachedThreadState() async {
    final store = threadCacheStore;
    final profileId = _normalized(threadCacheProfileId);
    if (store == null || profileId == null) {
      return;
    }
    final snapshot = await store.loadProfileCache(profileId);
    if (_disposed || snapshot == null || snapshot.isEmpty) {
      return;
    }
    _restoringCachedThreadState = true;
    try {
      if (threadListController.status == ThreadListStatus.idle &&
          snapshot.threads.isNotEmpty) {
        threadListController.restoreCached(snapshot.threads);
      }
      if (threadDetailController.selectedThreadId == null) {
        String? restoredThreadId;
        final selectedThread = snapshot.selectedThread;
        if (selectedThread != null) {
          threadDetailController.restoreCachedDetail(selectedThread);
          turnController.restoreCachedActiveThread(selectedThread.id);
          restoredThreadId = selectedThread.id;
        } else if (snapshot.selectedThreadId != null) {
          threadDetailController.restoreCachedSelection(
            snapshot.selectedThreadId,
          );
          turnController.restoreCachedActiveThread(snapshot.selectedThreadId);
          restoredThreadId = snapshot.selectedThreadId;
        }
        await _restoreCachedThreadItems(
          profileId: profileId,
          threadId: restoredThreadId,
        );
      }
    } finally {
      _restoringCachedThreadState = false;
    }
  }

  Future<void> _restoreCachedThreadItems({
    required String profileId,
    required String? threadId,
  }) async {
    final store = threadItemCacheStore;
    final normalizedThreadId = _normalized(threadId);
    if (store == null || normalizedThreadId == null) {
      return;
    }
    final snapshot = await store.loadThreadItems(
      profileId: profileId,
      threadId: normalizedThreadId,
    );
    if (_disposed || snapshot == null || snapshot.isEmpty) {
      return;
    }
    timelineController.restoreCachedItems(
      threadId: normalizedThreadId,
      items: snapshot.items,
    );
  }

  Future<ThreadTimelineCursorSnapshot?> _loadTimelineCursor(
    String threadId,
  ) async {
    final store = threadTimelineCursorStore;
    final profileId = _normalized(threadCacheProfileId);
    final normalizedThreadId = _normalized(threadId);
    if (store == null || profileId == null || normalizedThreadId == null) {
      return null;
    }
    try {
      final snapshot = await store.loadThreadCursor(
        profileId: profileId,
        threadId: normalizedThreadId,
      );
      if (_disposed) {
        return null;
      }
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<ThreadRecoveryHint> _loadRecoveryHint(String threadId) async {
    final timelineCursor = await _loadTimelineCursor(threadId);
    final normalizedThreadId = _normalized(threadId);
    final forceConservativeBackfill =
        normalizedThreadId != null &&
        _cursorGapThreadIds.remove(normalizedThreadId);
    return ThreadRecoveryHint(
      timelineCursor: timelineCursor,
      forceConservativeBackfill: forceConservativeBackfill,
    );
  }

  Future<String?> loadAgentSnapshotCursor(SshProfile profile) {
    return _agentSnapshotCursorProvider.load(profile);
  }

  void dispose() {
    _disposed = true;
    detachEvents();
    sessionController.removeListener(_handleSessionControllerChanged);
    unawaited(_agentSnapshotSubscription.cancel());
    threadListController.removeListener(_handleThreadListChanged);
    threadDetailController.removeListener(_handleThreadDetailChanged);
    turnController.removeListener(_handleTurnChanged);
    timelineController.removeListener(_handleTimelineChanged);
    timelineController.dispose();
    slashCommandRegistryController.dispose();
    turnController.dispose();
    threadDetailController.dispose();
    threadListController.dispose();
  }

  void _handleSessionControllerChanged() {
    handleSessionStatus(sessionController.status);
  }

  void _handleThreadDetailChanged() {
    switch (threadDetailController.status) {
      case ThreadDetailStatus.loading:
        timelineController.selectThread(
          threadDetailController.selectedThreadId,
        );
      case ThreadDetailStatus.loaded:
        final detail = threadDetailController.detail;
        if (detail != null) {
          timelineController.showThread(detail.thread);
        }
        _recoverCurrentThreadIfCursorGapPending();
      case ThreadDetailStatus.idle:
        timelineController.clear();
      case ThreadDetailStatus.failed:
        break;
    }
    _persistThreadCache();
  }

  void _recoverCurrentThreadIfCursorGapPending() {
    if (sessionController.status != CodexSessionStatus.connected) {
      return;
    }
    final threadId = _normalized(threadDetailController.selectedThreadId);
    if (threadId == null || !_cursorGapThreadIds.contains(threadId)) {
      return;
    }
    _sessionRecoveryCoordinator.recoverCurrentThread();
  }

  void _handleThreadListChanged() {
    _persistThreadCache();
  }

  void _handleTurnChanged() {
    _syncActiveTurnToTimeline();
    _persistThreadCache();
  }

  void _syncActiveTurnToTimeline() {
    final activeThreadId = _normalized(turnController.activeThreadId);
    if (activeThreadId == null) {
      return;
    }
    final lastTurn = turnController.lastTurn;
    if (lastTurn != null && lastTurn.id.trim().isNotEmpty) {
      timelineController.showTurn(threadId: activeThreadId, turn: lastTurn);
      return;
    }
    timelineController.selectThread(activeThreadId);
  }

  void _handleTimelineChanged() {
    _persistTimelineCursor();
  }

  void _handleAgentSnapshot(AgentSnapshot snapshot) {
    final threadIds = _threadIdsForAgentSnapshot(snapshot);
    final threadCursors = _threadCursorsForAgentSnapshot(snapshot);
    if (snapshot.cursorGap) {
      final gapThreadIds = threadIds.isEmpty
          ? _fallbackThreadIdsForSnapshotGap()
          : threadIds;
      _cursorGapThreadIds.addAll(gapThreadIds);
      if (gapThreadIds.isNotEmpty &&
          sessionController.status == CodexSessionStatus.connected) {
        _sessionRecoveryCoordinator.recoverCurrentThread();
      }
    }

    if (threadCursors.isEmpty) {
      return;
    }
    for (final MapEntry(key: threadId, value: threadCursor)
        in threadCursors.entries) {
      _deliveredCursorByThreadId[threadId] = threadCursor.deliveredCursor;
      unawaited(
        _persistDeliveredCursor(
          threadId: threadId,
          deliveredCursor: threadCursor.deliveredCursor,
          lastTurnId: threadCursor.lastTurnId,
          lastItemId: threadCursor.lastItemId,
        ),
      );
    }
  }

  Set<String> _fallbackThreadIdsForSnapshotGap() {
    return {
      _normalized(_agentSnapshotCursorProvider.lastResolvedThreadId),
      _normalized(timelineController.selectedThreadId),
      _normalized(threadDetailController.selectedThreadId),
      _normalized(turnController.activeThreadId),
    }.whereType<String>().toSet();
  }

  void _persistThreadCache() {
    if (_disposed || _restoringCachedThreadState) {
      return;
    }
    final store = threadCacheStore;
    final profileId = _normalized(threadCacheProfileId);
    if (store == null ||
        profileId == null ||
        threadListController.status != ThreadListStatus.loaded ||
        threadListController.archived) {
      return;
    }
    final selectedThread = _cachedSelectedThread();
    final selectedThreadId =
        _normalized(selectedThread?.id) ??
        _normalized(threadDetailController.selectedThreadId) ??
        _normalized(turnController.activeThreadId);
    final snapshot = ThreadCacheSnapshot(
      threads: threadListController.threads,
      selectedThreadId: selectedThreadId,
      selectedThread: selectedThread,
      cachedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (snapshot.isEmpty) {
      return;
    }
    try {
      unawaited(
        store.saveProfileCache(profileId, snapshot).catchError((Object _) {}),
      );
    } on Object {
      // Thread cache is best-effort reconnect state; the live UI stays usable.
    }
  }

  ThreadSummary? _cachedSelectedThread() {
    if (threadDetailController.status != ThreadDetailStatus.loaded) {
      return null;
    }
    final detail = threadDetailController.detail;
    final selectedThreadId = _normalized(
      threadDetailController.selectedThreadId,
    );
    if (detail == null || selectedThreadId == null) {
      return null;
    }
    return detail.thread.id == selectedThreadId ? detail.thread : null;
  }

  void _persistTimelineCursor() {
    if (_disposed || _restoringCachedThreadState) {
      return;
    }
    final store = threadTimelineCursorStore;
    final profileId = _normalized(threadCacheProfileId);
    final cursor = timelineController.cursor;
    final threadId = _normalized(cursor.threadId);
    if (store == null || profileId == null || threadId == null) {
      return;
    }
    final snapshot = ThreadTimelineCursorSnapshot(
      threadId: threadId,
      turnIds: cursor.turnIds,
      itemIds: cursor.itemIds,
      lastTurnId: cursor.lastTurnId,
      lastItemId: cursor.lastItemId,
      deliveredCursor: _deliveredCursorByThreadId[threadId],
      cachedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (snapshot.isEmpty) {
      return;
    }
    final fingerprint = _timelineCursorFingerprint(snapshot);
    if (_lastPersistedTimelineCursorFingerprint == fingerprint) {
      return;
    }
    _lastPersistedTimelineCursorFingerprint = fingerprint;
    try {
      unawaited(
        _saveTimelineCursor(
          store: store,
          profileId: profileId,
          threadId: threadId,
          snapshot: snapshot,
        ).catchError((Object _) {}),
      );
    } on Object {
      // Cursor persistence is best-effort reconnect state.
    }
  }

  Future<void> _persistDeliveredCursor({
    required String threadId,
    required String deliveredCursor,
    String? lastTurnId,
    String? lastItemId,
  }) async {
    if (_disposed) {
      return;
    }
    final store = threadTimelineCursorStore;
    final profileId = _normalized(threadCacheProfileId);
    if (store == null || profileId == null) {
      return;
    }
    final current = timelineController.cursor;
    final currentMatchesThread = current.threadId == threadId;
    final existing = await store.loadThreadCursor(
      profileId: profileId,
      threadId: threadId,
    );
    if (_disposed) {
      return;
    }
    final snapshot = ThreadTimelineCursorSnapshot(
      threadId: threadId,
      turnIds: _mergedIds(
        existing?.turnIds,
        currentMatchesThread ? current.turnIds : null,
      ),
      itemIds: _mergedIds(
        existing?.itemIds,
        currentMatchesThread ? current.itemIds : null,
      ),
      lastTurnId: currentMatchesThread
          ? current.lastTurnId ??
                _normalized(lastTurnId) ??
                existing?.lastTurnId
          : _normalized(lastTurnId) ?? existing?.lastTurnId,
      lastItemId: currentMatchesThread
          ? current.lastItemId ??
                _normalized(lastItemId) ??
                existing?.lastItemId
          : _normalized(lastItemId) ?? existing?.lastItemId,
      deliveredCursor: deliveredCursor,
      cachedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await store.saveThreadCursor(
      profileId: profileId,
      threadId: threadId,
      snapshot: snapshot,
    );
  }

  Future<void> _saveTimelineCursor({
    required ThreadTimelineCursorStore store,
    required String profileId,
    required String threadId,
    required ThreadTimelineCursorSnapshot snapshot,
  }) async {
    if (snapshot.deliveredCursor != null) {
      await store.saveThreadCursor(
        profileId: profileId,
        threadId: threadId,
        snapshot: snapshot,
      );
      return;
    }
    final existing = await store.loadThreadCursor(
      profileId: profileId,
      threadId: threadId,
    );
    if (_disposed) {
      return;
    }
    await store.saveThreadCursor(
      profileId: profileId,
      threadId: threadId,
      snapshot: _withDeliveredCursor(snapshot, existing?.deliveredCursor),
    );
  }
}

String? _normalized(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _timelineCursorFingerprint(ThreadTimelineCursorSnapshot snapshot) {
  final buffer = StringBuffer(snapshot.threadId)
    ..write('\nturns:')
    ..writeAll(snapshot.turnIds, ',')
    ..write('\nitems:')
    ..writeAll(snapshot.itemIds, ',')
    ..write('\nlastTurn:')
    ..write(snapshot.lastTurnId ?? '')
    ..write('\nlastItem:')
    ..write(snapshot.lastItemId ?? '');
  return buffer.toString();
}

Set<String> _threadIdsForAgentSnapshot(AgentSnapshot snapshot) {
  final threadIds = <String>{};
  for (final thread in snapshot.threads) {
    final threadId = _normalized(thread.threadId);
    if (threadId != null) {
      threadIds.add(threadId);
    }
  }
  for (final event in snapshot.recentEvents) {
    final threadId = _threadIdFromParams(event.params);
    if (threadId != null) {
      threadIds.add(threadId);
    }
  }
  return threadIds;
}

Map<String, _AgentSnapshotThreadCursor> _threadCursorsForAgentSnapshot(
  AgentSnapshot snapshot,
) {
  final threadCursors = <String, _AgentSnapshotThreadCursor>{};
  final deliveredCursor = _normalized(snapshot.deliveredCursor);
  for (final thread in snapshot.threads) {
    final threadId = _normalized(thread.threadId);
    final cursor = _normalized(thread.lastEventCursor);
    if (threadId != null && cursor != null) {
      threadCursors[threadId] = _AgentSnapshotThreadCursor(
        deliveredCursor: cursor,
        lastTurnId: _normalized(thread.lastTurnId),
        lastItemId: _normalized(thread.lastItemId),
      );
    }
  }
  for (final event in snapshot.recentEvents) {
    final threadId = _threadIdFromParams(event.params);
    final cursor = _normalized(event.cursor) ?? deliveredCursor;
    if (threadId != null && cursor != null) {
      threadCursors[threadId] = _AgentSnapshotThreadCursor(
        deliveredCursor: cursor,
        lastTurnId: _turnIdFromParams(event.params),
        lastItemId: _itemIdFromParams(event.params),
      );
    }
  }
  return threadCursors;
}

String? _threadIdFromParams(Object? params) {
  if (params is! Map) {
    return null;
  }
  return _normalized(params['threadId']?.toString()) ??
      _normalized(params['thread_id']?.toString()) ??
      _nestedNormalized(params['thread'], ['id', 'threadId', 'thread_id']);
}

String? _turnIdFromParams(Object? params) {
  if (params is! Map) {
    return null;
  }
  return _normalized(params['turnId']?.toString()) ??
      _normalized(params['turn_id']?.toString()) ??
      _nestedNormalized(params['turn'], ['id', 'turnId', 'turn_id']);
}

String? _itemIdFromParams(Object? params) {
  if (params is! Map) {
    return null;
  }
  return _normalized(params['itemId']?.toString()) ??
      _normalized(params['item_id']?.toString()) ??
      _nestedNormalized(params['item'], ['id', 'itemId', 'item_id']);
}

String? _nestedNormalized(Object? value, List<String> keys) {
  if (value is! Map) {
    return null;
  }
  for (final key in keys) {
    final normalized = _normalized(value[key]?.toString());
    if (normalized != null) {
      return normalized;
    }
  }
  return null;
}

List<String> _mergedIds(List<String>? first, List<String>? second) {
  final ids = <String>[];
  final seen = <String>{};
  for (final values in [first, second]) {
    if (values == null) {
      continue;
    }
    for (final value in values) {
      final normalized = _normalized(value);
      if (normalized != null && seen.add(normalized)) {
        ids.add(normalized);
      }
    }
  }
  return List.unmodifiable(ids);
}

ThreadTimelineCursorSnapshot _withDeliveredCursor(
  ThreadTimelineCursorSnapshot snapshot,
  String? deliveredCursor,
) {
  return ThreadTimelineCursorSnapshot(
    threadId: snapshot.threadId,
    turnIds: snapshot.turnIds,
    itemIds: snapshot.itemIds,
    lastTurnId: snapshot.lastTurnId,
    lastItemId: snapshot.lastItemId,
    deliveredCursor: deliveredCursor,
    cachedAtMs: snapshot.cachedAtMs,
  );
}

class _AgentSnapshotThreadCursor {
  const _AgentSnapshotThreadCursor({
    required this.deliveredCursor,
    this.lastTurnId,
    this.lastItemId,
  });

  final String deliveredCursor;
  final String? lastTurnId;
  final String? lastItemId;
}
