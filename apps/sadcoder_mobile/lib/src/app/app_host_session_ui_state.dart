import 'dart:async';

import '../commands/slash_command_manifest_reader.dart';
import '../commands/slash_command_registry_controller.dart';
import '../config/codex_config_override_controller.dart';
import '../features/chat/chat_timeline_controller.dart';
import '../session/codex_session_state_controller.dart';
import '../threads/thread_cache_store.dart';
import '../threads/thread_detail_controller.dart';
import '../threads/thread_list_controller.dart';
import '../turns/turn_controller.dart';
import 'app_session_recovery_coordinator.dart';

class AppHostSessionUiState {
  AppHostSessionUiState({
    required this.sessionController,
    required CodexConfigOverrideController configOverrideController,
    this.threadCacheProfileId,
    this.threadCacheStore,
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
    );
    threadListController.addListener(_handleThreadListChanged);
    threadDetailController.addListener(_handleThreadDetailChanged);
    turnController.addListener(_handleTurnChanged);
    unawaited(_restoreCachedThreadStateOnce().catchError((Object _) {}));
  }

  final CodexSessionStateController sessionController;
  final String? threadCacheProfileId;
  final ThreadCacheStore? threadCacheStore;
  late final ThreadListController threadListController;
  late final ThreadDetailController threadDetailController;
  late final TurnController turnController;
  late final ChatTimelineController timelineController;
  late final SlashCommandRegistryController slashCommandRegistryController;
  late final AppSessionRecoveryCoordinator _sessionRecoveryCoordinator;
  Future<void>? _restoreCachedThreadStateFuture;
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
      if (threadDetailController.selectedThreadId == null &&
          snapshot.selectedThreadId != null) {
        threadDetailController.restoreCachedSelection(
          snapshot.selectedThreadId,
        );
      }
    } finally {
      _restoringCachedThreadState = false;
    }
  }

  void dispose() {
    _disposed = true;
    detachEvents();
    threadListController.removeListener(_handleThreadListChanged);
    threadDetailController.removeListener(_handleThreadDetailChanged);
    turnController.removeListener(_handleTurnChanged);
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
    final snapshot = ThreadCacheSnapshot(
      threads: threadListController.threads,
      selectedThreadId:
          _normalized(turnController.activeThreadId) ??
          _normalized(threadDetailController.selectedThreadId),
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
}

String? _normalized(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
