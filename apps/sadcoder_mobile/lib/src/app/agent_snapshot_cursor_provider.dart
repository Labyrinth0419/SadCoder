import '../session/host_session_manager.dart';
import '../ssh/ssh_profile.dart';
import '../threads/thread_cache_store.dart';
import '../threads/thread_timeline_cursor_store.dart';

typedef SelectedThreadIdProvider = String? Function();
typedef DeliveredCursorProvider = String? Function(String threadId);

class AppAgentSnapshotCursorProvider {
  const AppAgentSnapshotCursorProvider({
    required this.threadCacheStore,
    required this.threadTimelineCursorStore,
    this.profileId,
    this.selectedThreadIdProvider,
    this.deliveredCursorProvider,
  });

  final ThreadCacheStore? threadCacheStore;
  final ThreadTimelineCursorStore? threadTimelineCursorStore;
  final String? profileId;
  final SelectedThreadIdProvider? selectedThreadIdProvider;
  final DeliveredCursorProvider? deliveredCursorProvider;

  Future<String?> load(SshProfile profile) async {
    final resolvedProfileId =
        _normalized(profileId) ?? _normalized(hostSessionProfileId(profile));
    if (resolvedProfileId == null) {
      return null;
    }
    final threadId =
        _normalized(selectedThreadIdProvider?.call()) ??
        await _loadCachedSelectedThreadId(resolvedProfileId);
    if (threadId == null) {
      return null;
    }
    final inMemoryCursor = _normalized(deliveredCursorProvider?.call(threadId));
    if (inMemoryCursor != null) {
      return inMemoryCursor;
    }
    final cursorStore = threadTimelineCursorStore;
    if (cursorStore == null) {
      return null;
    }
    try {
      final snapshot = await cursorStore.loadThreadCursor(
        profileId: resolvedProfileId,
        threadId: threadId,
      );
      return _normalized(snapshot?.deliveredCursor);
    } on Object {
      return null;
    }
  }

  Future<String?> _loadCachedSelectedThreadId(String profileId) async {
    final cacheStore = threadCacheStore;
    if (cacheStore == null) {
      return null;
    }
    try {
      final snapshot = await cacheStore.loadProfileCache(profileId);
      return _normalized(snapshot?.selectedThread?.id) ??
          _normalized(snapshot?.selectedThreadId);
    } on Object {
      return null;
    }
  }
}

String? _normalized(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
