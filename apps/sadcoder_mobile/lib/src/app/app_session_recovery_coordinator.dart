import 'dart:async';

import '../session/codex_session_state_controller.dart';
import '../threads/thread_detail_controller.dart';
import '../threads/thread_item_list_reader.dart';
import '../threads/thread_list_controller.dart';
import '../threads/thread_summary.dart';
import '../threads/thread_timeline_cursor_store.dart';
import '../threads/thread_turn_list_reader.dart';
import '../turns/turn_controller.dart';

typedef ThreadItemRecoveryHandler =
    void Function({
      required String threadId,
      required List<ThreadItemSummary> items,
    });
typedef ThreadTimelineCursorProvider =
    Future<ThreadTimelineCursorSnapshot?> Function(String threadId);
typedef ThreadRecoveryHintProvider =
    Future<ThreadRecoveryHint> Function(String threadId);
typedef ThreadRecoverySessionIdentity = ({
  String profileId,
  int connectionGeneration,
});
typedef ThreadRecoverySessionIdentityProvider =
    ThreadRecoverySessionIdentity? Function();
typedef ThreadRecoveryIsolationHandler = void Function();

class ThreadRecoveryHint {
  const ThreadRecoveryHint({
    this.timelineCursor,
    this.forceConservativeBackfill = false,
  });

  static const empty = ThreadRecoveryHint();

  final ThreadTimelineCursorSnapshot? timelineCursor;
  final bool forceConservativeBackfill;
}

class AppSessionRecoveryCoordinator {
  AppSessionRecoveryCoordinator({
    required ThreadListController threadListController,
    required ThreadDetailController threadDetailController,
    required TurnController turnController,
    ThreadTurnListReader? Function()? threadTurnListReaderProvider,
    ThreadItemListReader? Function()? threadItemListReaderProvider,
    ThreadItemRecoveryHandler? threadItemRecoveryHandler,
    ThreadTimelineCursorProvider? threadTimelineCursorProvider,
    ThreadRecoveryHintProvider? threadRecoveryHintProvider,
    ThreadRecoverySessionIdentityProvider? sessionIdentityProvider,
    ThreadRecoveryIsolationHandler? sessionIsolationHandler,
  }) : _threadListController = threadListController,
       _threadDetailController = threadDetailController,
       _turnController = turnController,
       _threadTurnListReaderProvider = threadTurnListReaderProvider,
       _threadItemListReaderProvider = threadItemListReaderProvider,
       _threadItemRecoveryHandler = threadItemRecoveryHandler,
       _threadTimelineCursorProvider = threadTimelineCursorProvider,
       _threadRecoveryHintProvider = threadRecoveryHintProvider,
       _sessionIdentityProvider = sessionIdentityProvider,
       _sessionIsolationHandler = sessionIsolationHandler;

  final ThreadListController _threadListController;
  final ThreadDetailController _threadDetailController;
  final TurnController _turnController;
  final ThreadTurnListReader? Function()? _threadTurnListReaderProvider;
  final ThreadItemListReader? Function()? _threadItemListReaderProvider;
  final ThreadItemRecoveryHandler? _threadItemRecoveryHandler;
  final ThreadTimelineCursorProvider? _threadTimelineCursorProvider;
  final ThreadRecoveryHintProvider? _threadRecoveryHintProvider;
  final ThreadRecoverySessionIdentityProvider? _sessionIdentityProvider;
  final ThreadRecoveryIsolationHandler? _sessionIsolationHandler;
  CodexSessionStatus? _lastStatus;
  ThreadRecoverySessionIdentity? _activeIdentity;
  ThreadRecoverySessionIdentity? _pendingIdentity;
  String? _pendingThreadId;
  int _fallbackConnectionGeneration = 0;
  int _recoveryGeneration = 0;

  static const _turnBackfillLimit = 50;
  static const _turnBackfillMaxPages = 3;
  static const _itemBackfillLimit = 200;
  static const _itemBackfillMaxPages = 3;

  void handleSessionStatus(CodexSessionStatus status) {
    final wasConnected = _lastStatus == CodexSessionStatus.connected;
    if (wasConnected && status != CodexSessionStatus.connected) {
      _pendingThreadId = _threadIdToRecover();
      _pendingIdentity = _activeIdentity;
      _invalidateSessionState();
    }
    final becameConnected =
        !wasConnected && status == CodexSessionStatus.connected;
    _lastStatus = status;
    if (!becameConnected) {
      return;
    }

    if (_sessionIdentityProvider == null) {
      _fallbackConnectionGeneration++;
    }
    final identity = _currentSessionIdentity();
    if (identity == null) {
      return;
    }
    _activeIdentity = identity;
    unawaited(_threadListController.refresh());
    final pendingMatchesProfile =
        _pendingIdentity?.profileId == identity.profileId;
    final threadId = pendingMatchesProfile
        ? _normalized(_pendingThreadId)
        : _threadIdToRecover();
    _pendingThreadId = null;
    _pendingIdentity = null;
    if (threadId != null) {
      _startRecovery(threadId);
    }
  }

  void recoverCurrentThread() {
    final threadId = _threadIdToRecover();
    if (threadId != null) {
      _startRecovery(threadId);
    }
  }

  void recoverThread(String threadId) {
    final normalizedThreadId = _normalized(threadId);
    if (normalizedThreadId != null) {
      _startRecovery(normalizedThreadId);
    }
  }

  void _startRecovery(String threadId) {
    final identity = _identityForRecovery();
    if (identity == null) {
      return;
    }
    final token = _ThreadRecoveryToken(
      threadId: threadId,
      profileId: identity.profileId,
      connectionGeneration: identity.connectionGeneration,
      recoveryGeneration: ++_recoveryGeneration,
    );
    unawaited(_recoverThread(token));
  }

  Future<void> _recoverThread(_ThreadRecoveryToken token) async {
    final threadId = token.threadId;
    final recoveryHint = await _loadRecoveryHint(threadId);
    if (!_isCurrent(token)) {
      return;
    }
    final turnListReader = _threadTurnListReaderProvider?.call();
    if (turnListReader == null) {
      final itemRecovered = await _recoverThreadWithItems(
        token,
        recoveryHint: recoveryHint,
      );
      if (!itemRecovered && _isCurrent(token)) {
        await _threadDetailController.readThread(threadId);
      }
      return;
    }

    await _threadDetailController.readThread(threadId, includeTurns: false);
    if (!_ownsSelectedThread(token)) {
      return;
    }
    try {
      final turns = <TurnSummary>[];
      final seenTurnIds = <String>{};
      final stopTurnId = recoveryHint.forceConservativeBackfill
          ? null
          : _normalized(recoveryHint.timelineCursor?.lastTurnId);
      String? cursor;
      for (var pageIndex = 0; pageIndex < _turnBackfillMaxPages; pageIndex++) {
        final page = await turnListReader.listTurns(
          threadId: threadId,
          cursor: cursor,
          limit: _turnBackfillLimit,
          sortDirection: 'desc',
          itemsView: 'full',
        );
        if (!_ownsSelectedThread(token)) {
          return;
        }
        final reachedKnownTurn = _appendUniqueTurns(
          turns,
          seenTurnIds,
          page.turns,
          stopAfterTurnId: stopTurnId,
        );
        final nextCursor = _normalized(page.nextCursor);
        if (reachedKnownTurn ||
            page.turns.isEmpty ||
            nextCursor == null ||
            nextCursor == cursor) {
          break;
        }
        cursor = nextCursor;
      }
      if (_ownsSelectedThread(token)) {
        _threadDetailController.backfillTurns(
          threadId: threadId,
          turns: turns.reversed.toList(growable: false),
        );
      }
    } catch (_) {
      if (_ownsSelectedThread(token)) {
        final itemRecovered = await _recoverThreadItems(
          token,
          recoveryHint: recoveryHint,
        );
        if (!itemRecovered && _ownsSelectedThread(token)) {
          await _threadDetailController.readThread(threadId);
        }
      }
    }
  }

  Future<bool> _recoverThreadWithItems(
    _ThreadRecoveryToken token, {
    required ThreadRecoveryHint recoveryHint,
  }) async {
    final threadId = token.threadId;
    final itemReader = _threadItemListReaderProvider?.call();
    if (itemReader == null || _threadItemRecoveryHandler == null) {
      return false;
    }
    await _threadDetailController.readThread(threadId, includeTurns: false);
    if (!_ownsSelectedThread(token)) {
      return true;
    }
    return _recoverThreadItems(token, recoveryHint: recoveryHint);
  }

  Future<bool> _recoverThreadItems(
    _ThreadRecoveryToken token, {
    required ThreadRecoveryHint recoveryHint,
  }) async {
    final threadId = token.threadId;
    final itemReader = _threadItemListReaderProvider?.call();
    final recoveryHandler = _threadItemRecoveryHandler;
    if (itemReader == null || recoveryHandler == null) {
      return false;
    }
    try {
      final fallbackItems = <ThreadItemSummary>[];
      final fallbackSeenItemIds = <String>{};
      final items = <ThreadItemSummary>[];
      final seenItemIds = <String>{};
      final itemBoundary = _ItemRecoveryBoundary(
        lastSeenItemId: recoveryHint.forceConservativeBackfill
            ? null
            : recoveryHint.timelineCursor?.lastItemId,
      );
      String? cursor;
      for (var pageIndex = 0; pageIndex < _itemBackfillMaxPages; pageIndex++) {
        final page = await itemReader.listItems(
          threadId: threadId,
          cursor: cursor,
          limit: _itemBackfillLimit,
          sortDirection: 'asc',
        );
        if (!_ownsSelectedThread(token)) {
          return true;
        }
        _appendUniqueItems(fallbackItems, fallbackSeenItemIds, page.items);
        _appendUniqueItems(
          items,
          seenItemIds,
          page.items,
          boundary: itemBoundary,
        );
        final nextCursor = _normalized(page.nextCursor);
        if (page.items.isEmpty || nextCursor == null || nextCursor == cursor) {
          break;
        }
        cursor = nextCursor;
      }
      final recoveredItems = itemBoundary.hasBoundary && itemBoundary.found
          ? items
          : fallbackItems;
      if (recoveredItems.isNotEmpty && _ownsSelectedThread(token)) {
        recoveryHandler(threadId: threadId, items: recoveredItems);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  String? _threadIdToRecover() {
    return _normalized(_turnController.activeThreadId) ??
        _normalized(_threadDetailController.selectedThreadId);
  }

  void _invalidateSessionState() {
    _recoveryGeneration++;
    _activeIdentity = null;
    _sessionIsolationHandler?.call();
    _threadDetailController.clear();
    _turnController.clearLocalConversation();
  }

  ThreadRecoverySessionIdentity? _identityForRecovery() {
    if (_sessionIdentityProvider != null) {
      return _currentSessionIdentity();
    }
    if (_lastStatus != null && _lastStatus != CodexSessionStatus.connected) {
      return null;
    }
    return _activeIdentity ??
        (
          profileId: 'default',
          connectionGeneration: _fallbackConnectionGeneration,
        );
  }

  ThreadRecoverySessionIdentity? _currentSessionIdentity() {
    final provided = _sessionIdentityProvider?.call();
    if (_sessionIdentityProvider != null) {
      final profileId = _normalized(provided?.profileId);
      if (provided == null || profileId == null) {
        return null;
      }
      return (
        profileId: profileId,
        connectionGeneration: provided.connectionGeneration,
      );
    }
    return (
      profileId: 'default',
      connectionGeneration: _fallbackConnectionGeneration,
    );
  }

  bool _ownsSelectedThread(_ThreadRecoveryToken token) {
    return _isCurrent(token) &&
        _threadDetailController.selectedThreadId == token.threadId;
  }

  bool _isCurrent(_ThreadRecoveryToken token) {
    if (token.recoveryGeneration != _recoveryGeneration) {
      return false;
    }
    final identity = _identityForRecovery();
    return identity != null &&
        identity.profileId == token.profileId &&
        identity.connectionGeneration == token.connectionGeneration;
  }

  Future<ThreadTimelineCursorSnapshot?> _loadTimelineCursor(
    String threadId,
  ) async {
    final provider = _threadTimelineCursorProvider;
    if (provider == null) {
      return null;
    }
    try {
      final snapshot = await provider(threadId);
      if (_normalized(snapshot?.threadId) != _normalized(threadId)) {
        return null;
      }
      return snapshot?.isEmpty == true ? null : snapshot;
    } catch (_) {
      return null;
    }
  }

  Future<ThreadRecoveryHint> _loadRecoveryHint(String threadId) async {
    final hintProvider = _threadRecoveryHintProvider;
    if (hintProvider != null) {
      try {
        return _sanitizeRecoveryHint(threadId, await hintProvider(threadId));
      } catch (_) {
        return ThreadRecoveryHint.empty;
      }
    }

    final cursor = await _loadTimelineCursor(threadId);
    return ThreadRecoveryHint(timelineCursor: cursor);
  }

  ThreadRecoveryHint _sanitizeRecoveryHint(
    String threadId,
    ThreadRecoveryHint hint,
  ) {
    final cursor = hint.timelineCursor;
    final normalizedThreadId = _normalized(threadId);
    final normalizedCursorThreadId = _normalized(cursor?.threadId);
    final validCursor =
        cursor != null &&
        normalizedCursorThreadId == normalizedThreadId &&
        cursor.isEmpty != true;
    if (!validCursor && !hint.forceConservativeBackfill) {
      return ThreadRecoveryHint.empty;
    }
    return ThreadRecoveryHint(
      timelineCursor: validCursor ? cursor : null,
      forceConservativeBackfill: hint.forceConservativeBackfill,
    );
  }
}

bool _appendUniqueTurns(
  List<TurnSummary> target,
  Set<String> seenIds,
  List<TurnSummary> turns, {
  String? stopAfterTurnId,
}) {
  final stopId = _normalized(stopAfterTurnId);
  for (final turn in turns) {
    final id = _normalized(turn.id);
    if (id == null || seenIds.add(id)) {
      target.add(turn);
    }
    if (id != null && id == stopId) {
      return true;
    }
  }
  return false;
}

void _appendUniqueItems(
  List<ThreadItemSummary> target,
  Set<String> seenIds,
  List<ThreadItemSummary> items, {
  _ItemRecoveryBoundary? boundary,
}) {
  for (final item in items) {
    final id = _normalized(item.id);
    if (boundary != null && !boundary.shouldKeep(id)) {
      continue;
    }
    if (id == null || seenIds.add(id)) {
      target.add(item);
    }
  }
}

class _ItemRecoveryBoundary {
  _ItemRecoveryBoundary({String? lastSeenItemId})
    : _lastSeenItemId = _normalized(lastSeenItemId),
      _found = _normalized(lastSeenItemId) == null;

  final String? _lastSeenItemId;
  bool _found;

  bool get hasBoundary => _lastSeenItemId != null;
  bool get found => _found;

  bool shouldKeep(String? itemId) {
    if (_found) {
      return true;
    }
    if (itemId != null && itemId == _lastSeenItemId) {
      _found = true;
      return true;
    }
    return false;
  }
}

class _ThreadRecoveryToken {
  const _ThreadRecoveryToken({
    required this.threadId,
    required this.profileId,
    required this.connectionGeneration,
    required this.recoveryGeneration,
  });

  final String threadId;
  final String profileId;
  final int connectionGeneration;
  final int recoveryGeneration;
}

String? _normalized(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
