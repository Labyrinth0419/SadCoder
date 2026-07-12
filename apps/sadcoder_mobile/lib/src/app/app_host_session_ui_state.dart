import 'dart:async';

import '../commands/slash_command_manifest_reader.dart';
import '../commands/slash_command_registry_controller.dart';
import '../config/codex_config_override_controller.dart';
import '../features/chat/chat_timeline_controller.dart';
import '../session/codex_session_state_controller.dart';
import '../threads/thread_cache_store.dart';
import '../threads/thread_detail_controller.dart';
import '../threads/thread_item_cache_store.dart';
import '../threads/thread_list_controller.dart';
import '../threads/thread_summary.dart';
import '../threads/thread_timeline_cursor_store.dart';
import '../turns/turn_controller.dart';
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
      onTurnCompleted: ({required threadId, required turn}) {
        turnController.finishTurn(threadId: threadId, turn: turn);
      },
    );
    slashCommandRegistryController = SlashCommandRegistryController(
      readerProvider: () =>
          sessionController.slashCommandManifestReader ??
          fallbackSlashCommandManifestReader,
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
      threadTimelineCursorProvider: _loadTimelineCursor,
    );
    threadListController.addListener(_handleThreadListChanged);
    threadDetailController.addListener(_handleThreadDetailChanged);
    turnController.addListener(_handleTurnChanged);
    timelineController.addListener(_handleTimelineChanged);
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
  Future<void>? _restoreCachedThreadStateFuture;
  String? _lastPersistedTimelineCursorFingerprint;
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

  void dispose() {
    _disposed = true;
    detachEvents();
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
      case ThreadDetailStatus.idle:
        timelineController.clear();
      case ThreadDetailStatus.failed:
        break;
    }
    _persistThreadCache();
  }

  void _handleThreadListChanged() {
    _persistThreadCache();
  }

  void _handleTurnChanged() {
    _persistThreadCache();
  }

  void _handleTimelineChanged() {
    _persistTimelineCursor();
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
        store
            .saveThreadCursor(
              profileId: profileId,
              threadId: threadId,
              snapshot: snapshot,
            )
            .catchError((Object _) {}),
      );
    } on Object {
      // Cursor persistence is best-effort reconnect state.
    }
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
