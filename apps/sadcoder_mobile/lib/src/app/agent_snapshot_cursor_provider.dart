import '../session/host_session_manager.dart';
import '../ssh/ssh_profile.dart';
import '../threads/thread_cache_store.dart';
import '../threads/thread_timeline_cursor_store.dart';

typedef SelectedThreadIdProvider = String? Function();
typedef PreferredThreadIdsProvider = Iterable<String?> Function();
typedef DeliveredCursorProvider = String? Function(String threadId);

class AppAgentSnapshotCursorProvider {
  AppAgentSnapshotCursorProvider({
    required this.threadCacheStore,
    required this.threadTimelineCursorStore,
    this.profileId,
    this.preferredThreadIdsProvider,
    this.selectedThreadIdProvider,
    this.deliveredCursorProvider,
  });

  final ThreadCacheStore? threadCacheStore;
  final ThreadTimelineCursorStore? threadTimelineCursorStore;
  final String? profileId;
  final PreferredThreadIdsProvider? preferredThreadIdsProvider;
  final SelectedThreadIdProvider? selectedThreadIdProvider;
  final DeliveredCursorProvider? deliveredCursorProvider;
  String? get lastResolvedThreadId => _lastResolvedThreadId;
  String? _lastResolvedThreadId;

  Future<String?> load(SshProfile profile) async {
    _lastResolvedThreadId = null;
    final resolvedProfileId =
        _normalized(profileId) ?? _normalized(hostSessionProfileId(profile));
    if (resolvedProfileId == null) {
      return null;
    }
    final threadId =
        _firstPreferredThreadId() ??
        await _loadCachedSelectedThreadId(resolvedProfileId);
    if (threadId == null) {
      return null;
    }
    _lastResolvedThreadId = threadId;
    return _loadThreadCursor(resolvedProfileId, threadId);
  }

  String? _firstPreferredThreadId() {
    final preferredThreadIds = preferredThreadIdsProvider?.call();
    if (preferredThreadIds != null) {
      for (final threadId in preferredThreadIds) {
        final normalized = _normalized(threadId);
        if (normalized != null) {
          return normalized;
        }
      }
    }
    return _normalized(selectedThreadIdProvider?.call());
  }

  Future<String?> _loadThreadCursor(String profileId, String threadId) async {
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
        profileId: profileId,
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
