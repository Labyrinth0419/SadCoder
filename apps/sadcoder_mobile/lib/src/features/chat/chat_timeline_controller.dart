import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../events/codex_event.dart';
import '../../events/guardian_assessment_event.dart';
import '../../goals/thread_goal.dart';
import '../../threads/thread_summary.dart';

typedef TurnCompletedHandler =
    void Function({required String threadId, required TurnSummary turn});
typedef TurnStartedHandler =
    void Function({required String threadId, required TurnSummary turn});

const chatTimelineInitialItemLimit = 80;
const chatTimelineMaxItemWindow = 480;

enum ChatTimelineHistoryStatus { idle, loading, failed }

class ChatTimelineController extends ChangeNotifier {
  ChatTimelineController({
    TurnCompletedHandler? onTurnCompleted,
    TurnStartedHandler? onTurnStarted,
  }) : _onTurnCompleted = onTurnCompleted,
       _onTurnStarted = onTurnStarted;

  final TurnCompletedHandler? _onTurnCompleted;
  final TurnStartedHandler? _onTurnStarted;
  final List<ChatTimelineTurn> _turns = [];
  final RecentAutoReviewDenials _recentAutoReviewDenials =
      RecentAutoReviewDenials();
  String? _selectedThreadId;
  String? _olderItemsCursor;
  ChatTimelineHistoryStatus _olderHistoryStatus =
      ChatTimelineHistoryStatus.idle;
  Object? _olderHistoryError;
  Stream<CodexEvent>? _attachedEvents;
  StreamSubscription<CodexEvent>? _subscription;
  int _localInstructionSequence = 0;

  List<ChatTimelineTurn> get turns => List.unmodifiable(_turns);

  String? get selectedThreadId => _selectedThreadId;

  String? get olderItemsCursor => _olderItemsCursor;

  bool get hasOlderItems => _olderItemsCursor != null;

  ChatTimelineHistoryStatus get olderHistoryStatus => _olderHistoryStatus;

  Object? get olderHistoryError => _olderHistoryError;

  bool get isLoadingOlderHistory =>
      _olderHistoryStatus == ChatTimelineHistoryStatus.loading;

  int get itemCount =>
      _turns.fold<int>(0, (count, turn) => count + turn.items.length);

  ChatTimelineCursor get cursor =>
      ChatTimelineCursor.fromTurns(threadId: _selectedThreadId, turns: _turns);

  List<GuardianAssessmentEvent> get recentAutoReviewDenials =>
      _recentAutoReviewDenials.entries;

  GuardianAssessmentEvent? latestAutoReviewDenial({String? threadId}) {
    return _recentAutoReviewDenials.latest(threadId: threadId);
  }

  void removeAutoReviewDenial(String id) {
    if (_recentAutoReviewDenials.remove(id)) {
      notifyListeners();
    }
  }

  String? lastAssistantMessageMarkdown() {
    for (final turn in _turns.reversed) {
      for (final item in turn.items.reversed) {
        if (item.itemType == 'agentMessage' && item.text.trim().isNotEmpty) {
          return item.text.trim();
        }
      }
    }
    return null;
  }

  String? reasoningMarkdownForTurn(String? turnId) {
    final normalizedTurnId = _normalized(turnId);
    if (normalizedTurnId == null) {
      return null;
    }
    final turnIndex = _turns.indexWhere(
      (turn) => turn.turnId == normalizedTurnId,
    );
    if (turnIndex == -1) {
      return null;
    }
    final sections = [
      for (final item in _turns[turnIndex].items)
        if (item.itemType == 'reasoning' && item.text.trim().isNotEmpty)
          item.text.trim(),
    ];
    return sections.isEmpty ? null : sections.join('\n\n');
  }

  void attach(Stream<CodexEvent>? events) {
    if (identical(_attachedEvents, events)) {
      return;
    }
    unawaited(_subscription?.cancel());
    _attachedEvents = events;
    _subscription = null;
    if (events == null) {
      return;
    }
    _subscription = events.listen(ingest, onError: (_) {});
  }

  void ingest(CodexEvent event) {
    _ingestGuardianAssessment(event);
    _handleTurnStart(event);
    _handleTurnCompletion(event);
    if (!_acceptsEvent(event)) {
      return;
    }
    switch (event.kind) {
      case CodexEventKind.turnStarted:
        _upsertTurn(event, status: event.turn?.status ?? 'inProgress');
      case CodexEventKind.turnCompleted:
        _upsertTurn(event, status: event.turn?.status ?? 'completed');
      case CodexEventKind.itemStarted || CodexEventKind.itemCompleted:
        _upsertItem(event);
      case CodexEventKind.threadGoalUpdated:
        _upsertThreadGoal(event);
      case CodexEventKind.agentMessageDelta:
        _appendDelta(event, fallbackType: 'agentMessage');
      case CodexEventKind.commandExecutionOutputDelta:
        _appendDelta(event, fallbackType: 'commandExecution', asOutput: true);
      case CodexEventKind.reasoningDelta:
        _appendDelta(event, fallbackType: 'reasoning');
      case CodexEventKind.reasoningSectionBreak:
        _appendReasoningSectionBreak(event);
      case CodexEventKind.fileChangeOutputDelta:
        _appendDelta(event, fallbackType: 'fileChange', asOutput: true);
      case CodexEventKind.fileChangePatchUpdated:
        _updateFileChanges(event);
      case CodexEventKind.mcpToolCallProgress:
        _appendDelta(event, fallbackType: 'mcpToolCall');
      case CodexEventKind.planDelta:
        _appendDelta(event, fallbackType: 'plan');
      case CodexEventKind.autoApprovalReviewStarted ||
          CodexEventKind.autoApprovalReviewCompleted:
        return;
      case CodexEventKind.threadStarted ||
          CodexEventKind.threadArchived ||
          CodexEventKind.threadUnarchived ||
          CodexEventKind.threadDeleted ||
          CodexEventKind.threadNameUpdated ||
          CodexEventKind.threadSettingsUpdated ||
          CodexEventKind.threadTokenUsageUpdated ||
          CodexEventKind.accountUpdated ||
          CodexEventKind.accountRateLimitsUpdated ||
          CodexEventKind.mcpServerStartupStatusUpdated ||
          CodexEventKind.externalAgentConfigImportProgress ||
          CodexEventKind.externalAgentConfigImportCompleted ||
          CodexEventKind.windowsSandboxSetupCompleted ||
          CodexEventKind.processOutputDelta ||
          CodexEventKind.processExited ||
          CodexEventKind.threadRealtimeStarted ||
          CodexEventKind.threadRealtimeItemAdded ||
          CodexEventKind.threadRealtimeTranscriptDelta ||
          CodexEventKind.threadRealtimeTranscriptDone ||
          CodexEventKind.threadRealtimeOutputAudioDelta ||
          CodexEventKind.threadRealtimeSdp ||
          CodexEventKind.threadRealtimeError ||
          CodexEventKind.threadRealtimeClosed ||
          CodexEventKind.fsChanged ||
          CodexEventKind.unknown:
        return;
    }
    notifyListeners();
  }

  void showThread(
    ThreadSummary thread, {
    int maxItems = chatTimelineInitialItemLimit,
  }) {
    if (thread.id.isEmpty) {
      clear();
      return;
    }
    final liveTurns = _selectedThreadId == thread.id
        ? List<ChatTimelineTurn>.from(_turns)
        : const <ChatTimelineTurn>[];
    _selectedThreadId = thread.id;
    _resetHistoryPaging();
    _turns
      ..clear()
      ..addAll(
        thread.turns.map(
          (turn) =>
              ChatTimelineTurn.fromTurnSummary(threadId: thread.id, turn: turn),
        ),
      );
    _trimToMaxItems(maxItems);
    for (final liveTurn in liveTurns) {
      _mergeTurn(liveTurn);
    }
    _trimToMaxItems(chatTimelineMaxItemWindow);
    notifyListeners();
  }

  void showThreadItemWindow({
    required ThreadSummary thread,
    required List<ThreadItemSummary> items,
    String? olderItemsCursor,
    int maxItems = chatTimelineInitialItemLimit,
  }) {
    final normalizedThreadId = _normalized(thread.id);
    if (normalizedThreadId == null) {
      clear();
      return;
    }
    final liveTurns = _selectedThreadId == normalizedThreadId
        ? List<ChatTimelineTurn>.from(_turns)
        : const <ChatTimelineTurn>[];
    _selectedThreadId = normalizedThreadId;
    _olderItemsCursor = _normalized(olderItemsCursor);
    _olderHistoryStatus = ChatTimelineHistoryStatus.idle;
    _olderHistoryError = null;
    _turns.clear();
    for (final item in _latestItems(items, maxItems: maxItems)) {
      _mergeCachedItem(
        threadId: normalizedThreadId,
        turnId: item.turnId,
        item: item,
      );
    }
    for (final liveTurn in liveTurns) {
      _mergeTurn(liveTurn);
    }
    _trimToMaxItems(chatTimelineMaxItemWindow);
    notifyListeners();
  }

  void prependThreadItems({
    required String threadId,
    required List<ThreadItemSummary> items,
    String? olderItemsCursor,
  }) {
    final normalizedThreadId = _normalized(threadId);
    if (normalizedThreadId == null || normalizedThreadId != _selectedThreadId) {
      return;
    }
    final currentTurns = List<ChatTimelineTurn>.from(_turns);
    final currentItemIds = {
      for (final turn in currentTurns)
        for (final item in turn.items) item.itemId,
    };
    _turns.clear();
    for (final item in items) {
      if (currentItemIds.contains(item.id)) {
        continue;
      }
      _mergeCachedItem(
        threadId: normalizedThreadId,
        turnId: item.turnId,
        item: item,
      );
    }
    for (final currentTurn in currentTurns) {
      _mergeTurn(currentTurn);
    }
    _olderItemsCursor = _normalized(olderItemsCursor);
    _olderHistoryStatus = ChatTimelineHistoryStatus.idle;
    _olderHistoryError = null;
    _trimToMaxItems(chatTimelineMaxItemWindow);
    notifyListeners();
  }

  void beginOlderHistoryLoad() {
    if (_olderHistoryStatus == ChatTimelineHistoryStatus.loading) {
      return;
    }
    _olderHistoryStatus = ChatTimelineHistoryStatus.loading;
    _olderHistoryError = null;
    notifyListeners();
  }

  void failOlderHistoryLoad(Object error) {
    _olderHistoryStatus = ChatTimelineHistoryStatus.failed;
    _olderHistoryError = error;
    notifyListeners();
  }

  void clearOlderHistoryError() {
    if (_olderHistoryStatus == ChatTimelineHistoryStatus.idle &&
        _olderHistoryError == null) {
      return;
    }
    _olderHistoryStatus = ChatTimelineHistoryStatus.idle;
    _olderHistoryError = null;
    notifyListeners();
  }

  void selectThread(String? threadId) {
    final normalizedThreadId = threadId?.trim();
    if (normalizedThreadId == null || normalizedThreadId.isEmpty) {
      clear();
      return;
    }
    if (_selectedThreadId == normalizedThreadId) {
      return;
    }
    _selectedThreadId = normalizedThreadId;
    _turns.removeWhere((turn) => turn.threadId != normalizedThreadId);
    _resetHistoryPaging();
    notifyListeners();
  }

  void showTurn({required String threadId, required TurnSummary turn}) {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty || turn.id.isEmpty) {
      return;
    }
    if (_selectedThreadId != normalizedThreadId) {
      _turns.clear();
      _resetHistoryPaging();
    }
    _selectedThreadId = normalizedThreadId;
    _mergeTurn(
      ChatTimelineTurn.fromTurnSummary(
        threadId: normalizedThreadId,
        turn: turn,
      ),
    );
    _trimToMaxItems(chatTimelineMaxItemWindow);
    notifyListeners();
  }

  void showLocalUserMessage({
    required String threadId,
    required String turnId,
    required String text,
  }) {
    final normalizedThreadId = threadId.trim();
    final normalizedTurnId = turnId.trim();
    final normalizedText = text.trim();
    if (normalizedThreadId.isEmpty ||
        normalizedTurnId.isEmpty ||
        normalizedText.isEmpty) {
      return;
    }
    if (_selectedThreadId != normalizedThreadId) {
      _selectedThreadId = normalizedThreadId;
      _turns.removeWhere((turn) => turn.threadId != normalizedThreadId);
      _resetHistoryPaging();
    }
    _mergeCachedItemIntoTurn(
      threadId: normalizedThreadId,
      turnId: normalizedTurnId,
      item: ChatTimelineItem.localUserMessage(
        turnId: normalizedTurnId,
        text: normalizedText,
      ),
    );
    _trimToMaxItems(chatTimelineMaxItemWindow);
    notifyListeners();
  }

  void showQueuedInstruction({
    required String threadId,
    required String turnId,
    required String text,
  }) {
    final normalizedThreadId = threadId.trim();
    final normalizedTurnId = turnId.trim();
    final normalizedText = text.trim();
    if (normalizedThreadId.isEmpty ||
        normalizedTurnId.isEmpty ||
        normalizedText.isEmpty) {
      return;
    }
    if (_selectedThreadId != normalizedThreadId) {
      _selectedThreadId = normalizedThreadId;
      _turns.removeWhere((turn) => turn.threadId != normalizedThreadId);
      _resetHistoryPaging();
    }
    _mergeCachedItemIntoTurn(
      threadId: normalizedThreadId,
      turnId: normalizedTurnId,
      item: ChatTimelineItem.localQueuedInstruction(
        turnId: normalizedTurnId,
        sequence: ++_localInstructionSequence,
        text: normalizedText,
      ),
    );
    _trimToMaxItems(chatTimelineMaxItemWindow);
    notifyListeners();
  }

  void showInterruptInstruction({
    required String threadId,
    required String turnId,
  }) {
    final normalizedThreadId = threadId.trim();
    final normalizedTurnId = turnId.trim();
    if (normalizedThreadId.isEmpty || normalizedTurnId.isEmpty) {
      return;
    }
    if (_selectedThreadId != normalizedThreadId) {
      _selectedThreadId = normalizedThreadId;
      _turns.removeWhere((turn) => turn.threadId != normalizedThreadId);
      _resetHistoryPaging();
    }
    _mergeCachedItemIntoTurn(
      threadId: normalizedThreadId,
      turnId: normalizedTurnId,
      item: ChatTimelineItem.localInterruptInstruction(
        turnId: normalizedTurnId,
        sequence: ++_localInstructionSequence,
      ),
    );
    _trimToMaxItems(chatTimelineMaxItemWindow);
    notifyListeners();
  }

  void restoreCachedItems({
    required String threadId,
    required List<ThreadItemSummary> items,
  }) {
    restoreThreadItems(threadId: threadId, items: items);
  }

  void restoreThreadItems({
    required String threadId,
    required List<ThreadItemSummary> items,
  }) {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty || items.isEmpty) {
      return;
    }
    final selectedChanged = _selectedThreadId != normalizedThreadId;
    if (selectedChanged) {
      _turns.clear();
      _resetHistoryPaging();
    }
    _selectedThreadId = normalizedThreadId;
    final itemsByTurn = <String, List<ThreadItemSummary>>{};
    for (final item in items) {
      if (item.id.trim().isEmpty) {
        continue;
      }
      final turnId =
          _normalized(item.turnId) ??
          _turnIdContainingItem(item.id) ??
          _cachedItemsTurnId;
      itemsByTurn.putIfAbsent(turnId, () => []).add(item);
    }
    var changed = selectedChanged;
    for (final entry in itemsByTurn.entries) {
      changed =
          _mergeRecoveredItemBatch(
            threadId: normalizedThreadId,
            turnId: entry.key,
            items: entry.value,
          ) ||
          changed;
    }
    if (changed) {
      _trimToMaxItems(chatTimelineMaxItemWindow);
      notifyListeners();
    }
  }

  void clear() {
    _selectedThreadId = null;
    _turns.clear();
    _localInstructionSequence = 0;
    _resetHistoryPaging();
    _recentAutoReviewDenials.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _upsertTurn(CodexEvent event, {required String status}) {
    final threadId = event.threadId;
    final turnId = event.turnId;
    if (threadId == null || turnId == null || turnId.isEmpty) {
      return;
    }
    _selectLiveThread(threadId);
    final index = _turns.indexWhere((turn) => turn.turnId == turnId);
    if (index == -1) {
      _turns.add(
        ChatTimelineTurn(
          threadId: threadId,
          turnId: turnId,
          status: status,
          items: const [],
        ),
      );
      _trimToMaxItems(chatTimelineMaxItemWindow);
      return;
    }
    _turns[index] = _turns[index].copyWith(status: status);
  }

  void _mergeTurn(ChatTimelineTurn next) {
    final index = _turns.indexWhere((turn) => turn.turnId == next.turnId);
    if (index == -1) {
      _turns.add(next);
      _trimToMaxItems(chatTimelineMaxItemWindow);
      return;
    }
    _turns[index] = _turns[index].mergeLive(next);
  }

  bool _mergeCachedItem({
    required String threadId,
    required String? turnId,
    required ThreadItemSummary item,
  }) {
    final timelineItem = ChatTimelineItem.fromThreadItem(item);
    final normalizedTurnId = _normalized(turnId);
    if (normalizedTurnId != null) {
      return _mergeCachedItemIntoTurn(
        threadId: threadId,
        turnId: normalizedTurnId,
        item: timelineItem,
      );
    }

    for (var turnIndex = 0; turnIndex < _turns.length; turnIndex++) {
      final itemIndex = _turns[turnIndex].items.indexWhere(
        (existing) => existing.itemId == item.id,
      );
      if (itemIndex == -1) {
        continue;
      }
      final items = List<ChatTimelineItem>.from(_turns[turnIndex].items);
      items[itemIndex] = timelineItem.mergeLive(items[itemIndex]);
      _turns[turnIndex] = _turns[turnIndex].copyWith(items: items);
      return true;
    }

    return _mergeCachedItemIntoTurn(
      threadId: threadId,
      turnId: _cachedItemsTurnId,
      item: timelineItem,
    );
  }

  bool _mergeCachedItemIntoTurn({
    required String threadId,
    required String turnId,
    required ChatTimelineItem item,
  }) {
    var turnIndex = _turns.indexWhere((turn) => turn.turnId == turnId);
    if (turnIndex == -1) {
      _turns.add(
        ChatTimelineTurn(
          threadId: threadId,
          turnId: turnId,
          status: 'unknown',
          items: const [],
        ),
      );
      turnIndex = _turns.length - 1;
    }
    final turn = _turns[turnIndex];
    final items = List<ChatTimelineItem>.from(turn.items);
    final itemIndex = items.indexWhere(
      (existing) => existing.itemId == item.itemId,
    );
    if (itemIndex == -1 &&
        item.itemType == 'userMessage' &&
        !item.isLocalUserMessage) {
      _reconcileLocalUserProjections(items, item);
    }
    if (itemIndex == -1) {
      items.add(item);
    } else {
      items[itemIndex] = item.mergeLive(items[itemIndex]);
    }
    _turns[turnIndex] = turn.copyWith(items: items);
    return true;
  }

  String? _turnIdContainingItem(String itemId) {
    for (final turn in _turns) {
      if (turn.items.any((item) => item.itemId == itemId)) {
        return turn.turnId;
      }
    }
    return null;
  }

  bool _mergeRecoveredItemBatch({
    required String threadId,
    required String turnId,
    required List<ThreadItemSummary> items,
  }) {
    var turnIndex = _turns.indexWhere((turn) => turn.turnId == turnId);
    if (turnIndex == -1) {
      _turns.add(
        ChatTimelineTurn(
          threadId: threadId,
          turnId: turnId,
          status: 'unknown',
          items: const [],
        ),
      );
      turnIndex = _turns.length - 1;
    }
    final turn = _turns[turnIndex];
    final existingItems = turn.items;
    final recoveredIds = {for (final item in items) item.id};
    var firstOverlap = existingItems.length;
    for (var index = 0; index < existingItems.length; index++) {
      if (recoveredIds.contains(existingItems[index].itemId)) {
        firstOverlap = index;
        break;
      }
    }
    final mergedItems = <ChatTimelineItem>[...existingItems.take(firstOverlap)];
    for (final item in items) {
      final recovered = ChatTimelineItem.fromThreadItem(item);
      final existingIndex = existingItems.indexWhere(
        (existing) => existing.itemId == recovered.itemId,
      );
      mergedItems.add(
        existingIndex == -1
            ? recovered
            : recovered.mergeLive(existingItems[existingIndex]),
      );
    }
    mergedItems.addAll(
      existingItems
          .skip(firstOverlap)
          .where((existing) => !recoveredIds.contains(existing.itemId)),
    );
    for (final item in items) {
      if (existingItems.any((existing) => existing.itemId == item.id)) {
        continue;
      }
      final recovered = ChatTimelineItem.fromThreadItem(item);
      if (recovered.itemType == 'userMessage' &&
          !recovered.isLocalUserMessage) {
        _reconcileLocalUserProjections(mergedItems, recovered);
      }
    }
    _turns[turnIndex] = turn.copyWith(items: mergedItems);
    return true;
  }

  bool _acceptsEvent(CodexEvent event) {
    final selectedThreadId = _selectedThreadId;
    final eventThreadId = event.threadId;
    if (selectedThreadId == null || eventThreadId == null) {
      return true;
    }
    return selectedThreadId == eventThreadId;
  }

  void _handleTurnStart(CodexEvent event) {
    if (event.kind != CodexEventKind.turnStarted) {
      return;
    }
    final threadId = event.threadId;
    final turn = event.turn;
    if (threadId == null || turn == null) {
      return;
    }
    _onTurnStarted?.call(threadId: threadId, turn: turn);
  }

  void _handleTurnCompletion(CodexEvent event) {
    if (event.kind != CodexEventKind.turnCompleted) {
      return;
    }
    final threadId = event.threadId;
    final turn = event.turn;
    if (threadId != null && turn != null) {
      _onTurnCompleted?.call(threadId: threadId, turn: turn);
    }
  }

  void _ingestGuardianAssessment(CodexEvent event) {
    final assessment = event.guardianAssessment;
    if (assessment == null ||
        event.kind != CodexEventKind.autoApprovalReviewCompleted) {
      return;
    }
    final before = _recentAutoReviewDenials.entries.length;
    _recentAutoReviewDenials.ingest(assessment);
    if (_recentAutoReviewDenials.entries.length != before ||
        _recentAutoReviewDenials.latest(threadId: assessment.threadId)?.id ==
            assessment.id) {
      notifyListeners();
    }
  }

  void _upsertItem(CodexEvent event) {
    final turnIndex = _ensureTurn(event);
    if (turnIndex == null) {
      return;
    }
    final itemId = event.itemId;
    if (itemId == null || itemId.isEmpty) {
      return;
    }
    final turn = _turns[turnIndex];
    final items = List<ChatTimelineItem>.from(turn.items);
    final item = ChatTimelineItem.fromEvent(event);
    final itemIndex = items.indexWhere((item) => item.itemId == itemId);
    if (itemIndex == -1 &&
        item.itemType == 'userMessage' &&
        !item.isLocalUserMessage) {
      _reconcileLocalUserProjections(items, item);
    }
    if (itemIndex == -1) {
      items.add(item);
    } else {
      items[itemIndex] = items[itemIndex].merge(item);
    }
    _turns[turnIndex] = turn.copyWith(items: items);
    _trimToMaxItems(chatTimelineMaxItemWindow);
  }

  void _upsertThreadGoal(CodexEvent event) {
    final threadId = _normalized(event.threadId);
    final goal = event.threadGoal;
    if (threadId == null || goal == null) {
      return;
    }
    _selectLiveThread(threadId);
    final next = ChatTimelineItem.fromThreadGoalEvent(event);
    for (var turnIndex = 0; turnIndex < _turns.length; turnIndex++) {
      final itemIndex = _turns[turnIndex].items.indexWhere(
        (item) => item.itemId == next.itemId,
      );
      if (itemIndex == -1) {
        continue;
      }
      final items = List<ChatTimelineItem>.from(_turns[turnIndex].items);
      items[itemIndex] = items[itemIndex].merge(next);
      _turns[turnIndex] = _turns[turnIndex].copyWith(items: items);
      return;
    }
    _mergeCachedItemIntoTurn(
      threadId: threadId,
      turnId: _normalized(event.turnId) ?? _threadGoalEventsTurnId,
      item: next,
    );
    _trimToMaxItems(chatTimelineMaxItemWindow);
  }

  void _appendDelta(
    CodexEvent event, {
    required String fallbackType,
    bool asOutput = false,
  }) {
    final turnIndex = _ensureTurn(event);
    if (turnIndex == null) {
      return;
    }
    final itemId = event.itemId;
    if (itemId == null || itemId.isEmpty) {
      return;
    }
    final turn = _turns[turnIndex];
    final items = List<ChatTimelineItem>.from(turn.items);
    final itemIndex = items.indexWhere((item) => item.itemId == itemId);
    if (itemIndex == -1) {
      items.add(
        ChatTimelineItem(
          itemId: itemId,
          itemType: fallbackType,
          text: asOutput ? '' : event.delta ?? '',
          output: asOutput ? event.delta ?? '' : '',
          raw: const {},
        ),
      );
    } else {
      final existing = items[itemIndex];
      items[itemIndex] = existing.copyWith(
        text: asOutput ? existing.text : existing.text + (event.delta ?? ''),
        output: asOutput
            ? existing.output + (event.delta ?? '')
            : existing.output,
      );
    }
    _turns[turnIndex] = turn.copyWith(items: items);
    _trimToMaxItems(chatTimelineMaxItemWindow);
  }

  void _appendReasoningSectionBreak(CodexEvent event) {
    final turnId = event.turnId;
    if (turnId == null || turnId.isEmpty) {
      return;
    }
    final turnIndex = _turns.indexWhere((turn) => turn.turnId == turnId);
    if (turnIndex == -1) {
      return;
    }
    final itemId = event.itemId;
    if (itemId == null || itemId.isEmpty) {
      return;
    }
    final turn = _turns[turnIndex];
    final items = List<ChatTimelineItem>.from(turn.items);
    final itemIndex = items.indexWhere((item) => item.itemId == itemId);
    if (itemIndex == -1) {
      return;
    }
    final existing = items[itemIndex];
    if (existing.text.trim().isEmpty || existing.text.endsWith('\n\n')) {
      return;
    }
    items[itemIndex] = existing.copyWith(
      text: existing.text.endsWith('\n')
          ? '${existing.text}\n'
          : '${existing.text}\n\n',
    );
    _turns[turnIndex] = turn.copyWith(items: items);
  }

  void _updateFileChanges(CodexEvent event) {
    final turnIndex = _ensureTurn(event);
    if (turnIndex == null) {
      return;
    }
    final itemId = event.itemId;
    if (itemId == null || itemId.isEmpty) {
      return;
    }
    final turn = _turns[turnIndex];
    final items = List<ChatTimelineItem>.from(turn.items);
    final itemIndex = items.indexWhere((item) => item.itemId == itemId);
    if (itemIndex == -1) {
      items.add(
        ChatTimelineItem(
          itemId: itemId,
          itemType: 'fileChange',
          text: '',
          output: '',
          fileChanges: event.fileChanges ?? const [],
          raw: event.raw,
        ),
      );
    } else {
      items[itemIndex] = items[itemIndex].copyWith(
        fileChanges: event.fileChanges ?? const [],
      );
    }
    _turns[turnIndex] = turn.copyWith(items: items);
    _trimToMaxItems(chatTimelineMaxItemWindow);
  }

  int? _ensureTurn(CodexEvent event) {
    final threadId = event.threadId;
    final turnId = event.turnId;
    if (threadId == null || turnId == null || turnId.isEmpty) {
      return null;
    }
    _selectLiveThread(threadId);
    var index = _turns.indexWhere((turn) => turn.turnId == turnId);
    if (index == -1) {
      _turns.add(
        ChatTimelineTurn(
          threadId: threadId,
          turnId: turnId,
          status: 'inProgress',
          items: const [],
        ),
      );
      index = _turns.length - 1;
    }
    return index;
  }

  void _selectLiveThread(String threadId) {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty || _selectedThreadId != null) {
      return;
    }
    _selectedThreadId = normalizedThreadId;
  }

  void _resetHistoryPaging() {
    _olderItemsCursor = null;
    _olderHistoryStatus = ChatTimelineHistoryStatus.idle;
    _olderHistoryError = null;
  }

  void _trimToMaxItems(int maxItems) {
    if (maxItems <= 0) {
      _turns.clear();
      return;
    }
    var overflow = itemCount - maxItems;
    while (overflow > 0 && _turns.isNotEmpty) {
      final first = _turns.first;
      if (first.items.isEmpty) {
        _turns.removeAt(0);
        continue;
      }
      if (first.items.length <= overflow) {
        overflow -= first.items.length;
        _turns.removeAt(0);
        continue;
      }
      _turns[0] = first.copyWith(
        items: first.items.skip(overflow).toList(growable: false),
      );
      overflow = 0;
    }
  }

  List<ThreadItemSummary> _latestItems(
    List<ThreadItemSummary> items, {
    required int maxItems,
  }) {
    if (maxItems <= 0 || items.length <= maxItems) {
      return items;
    }
    return items.skip(items.length - maxItems).toList(growable: false);
  }
}

const _cachedItemsTurnId = 'cached_items';
const _threadGoalEventsTurnId = 'thread_goal_events';

class ChatTimelineTurn {
  const ChatTimelineTurn({
    required this.threadId,
    required this.turnId,
    required this.status,
    required this.items,
  });

  factory ChatTimelineTurn.fromTurnSummary({
    required String threadId,
    required TurnSummary turn,
  }) {
    return ChatTimelineTurn(
      threadId: threadId,
      turnId: turn.id,
      status: turn.status,
      items: turn.items
          .map(ChatTimelineItem.fromThreadItem)
          .toList(growable: false),
    );
  }

  final String threadId;
  final String turnId;
  final String status;
  final List<ChatTimelineItem> items;

  ChatTimelineTurn copyWith({String? status, List<ChatTimelineItem>? items}) {
    return ChatTimelineTurn(
      threadId: threadId,
      turnId: turnId,
      status: status ?? this.status,
      items: items ?? this.items,
    );
  }

  ChatTimelineTurn mergeLive(ChatTimelineTurn liveTurn) {
    final mergedItems = List<ChatTimelineItem>.from(items);
    for (final liveItem in liveTurn.items) {
      if (liveItem.isLocalUserMessage &&
          mergedItems.any(
            (item) =>
                item.itemType == 'userMessage' && !item.isLocalUserMessage,
          )) {
        continue;
      }
      final index = mergedItems.indexWhere(
        (item) => item.itemId == liveItem.itemId,
      );
      if (index == -1 &&
          liveItem.itemType == 'userMessage' &&
          !liveItem.isLocalUserMessage) {
        _reconcileLocalUserProjections(mergedItems, liveItem);
      }
      if (index == -1) {
        mergedItems.add(liveItem);
      } else {
        mergedItems[index] = mergedItems[index].mergeLive(liveItem);
      }
    }
    return ChatTimelineTurn(
      threadId: threadId,
      turnId: turnId,
      status: _mergeStatus(status, liveTurn.status),
      items: mergedItems,
    );
  }
}

class ChatTimelineCursor {
  const ChatTimelineCursor({
    required this.threadId,
    required this.turnIds,
    required this.itemIds,
    this.lastTurnId,
    this.lastItemId,
  });

  factory ChatTimelineCursor.fromTurns({
    required String? threadId,
    required List<ChatTimelineTurn> turns,
  }) {
    final turnIds = <String>[];
    final itemIds = <String>[];
    String? lastTurnId;
    String? lastItemId;
    for (final turn in turns) {
      final turnId = _normalized(turn.turnId);
      if (turnId != null) {
        turnIds.add(turnId);
        lastTurnId = turnId;
      }
      for (final item in turn.items) {
        final itemId = _normalized(item.itemId);
        if (itemId == null) {
          continue;
        }
        itemIds.add(itemId);
        lastItemId = itemId;
      }
    }
    return ChatTimelineCursor(
      threadId: _normalized(threadId),
      turnIds: List.unmodifiable(turnIds),
      itemIds: List.unmodifiable(itemIds),
      lastTurnId: lastTurnId,
      lastItemId: lastItemId,
    );
  }

  final String? threadId;
  final List<String> turnIds;
  final List<String> itemIds;
  final String? lastTurnId;
  final String? lastItemId;

  bool get isEmpty => threadId == null && turnIds.isEmpty && itemIds.isEmpty;
}

class ChatTimelineItem {
  const ChatTimelineItem({
    required this.itemId,
    required this.itemType,
    required this.text,
    required this.output,
    this.command,
    this.cwd,
    this.status,
    this.exitCode,
    this.durationMs,
    this.server,
    this.tool,
    this.threadGoal,
    this.fileChanges = const [],
    required this.raw,
  });

  factory ChatTimelineItem.fromEvent(CodexEvent event) {
    final raw = event.item ?? const <String, Object?>{};
    final threadItem = ThreadItemSummary.fromJson(raw);
    return ChatTimelineItem(
      itemId: event.itemId ?? '',
      itemType: event.itemType ?? threadItem.type,
      text: threadItem.text,
      output: threadItem.output,
      command: threadItem.command,
      cwd: threadItem.cwd,
      status: threadItem.status,
      exitCode: threadItem.exitCode,
      durationMs: threadItem.durationMs,
      server: threadItem.server,
      tool: threadItem.tool,
      fileChanges: threadItem.fileChanges,
      raw: raw,
    );
  }

  factory ChatTimelineItem.fromThreadItem(ThreadItemSummary item) {
    return ChatTimelineItem(
      itemId: item.id,
      itemType: item.type,
      text: item.text,
      output: item.output,
      command: item.command,
      cwd: item.cwd,
      status: item.status,
      exitCode: item.exitCode,
      durationMs: item.durationMs,
      server: item.server,
      tool: item.tool,
      fileChanges: item.fileChanges,
      raw: item.raw,
    );
  }

  factory ChatTimelineItem.localUserMessage({
    required String turnId,
    required String text,
  }) {
    final itemId = _localUserMessageItemId(turnId);
    return ChatTimelineItem(
      itemId: itemId,
      itemType: 'userMessage',
      text: text,
      output: '',
      raw: {'id': itemId, 'type': 'userMessage', 'text': text, 'local': true},
    );
  }

  factory ChatTimelineItem.localQueuedInstruction({
    required String turnId,
    required int sequence,
    required String text,
  }) {
    final itemId = _localInstructionItemId(
      type: 'queued',
      turnId: turnId,
      sequence: sequence,
    );
    return ChatTimelineItem(
      itemId: itemId,
      itemType: 'queuedInstruction',
      text: text,
      output: '',
      raw: {
        'id': itemId,
        'type': 'queuedInstruction',
        'text': text,
        'local': true,
      },
    );
  }

  factory ChatTimelineItem.localInterruptInstruction({
    required String turnId,
    required int sequence,
  }) {
    final itemId = _localInstructionItemId(
      type: 'interrupt',
      turnId: turnId,
      sequence: sequence,
    );
    return ChatTimelineItem(
      itemId: itemId,
      itemType: 'interruptInstruction',
      text: '',
      output: '',
      raw: {'id': itemId, 'type': 'interruptInstruction', 'local': true},
    );
  }

  factory ChatTimelineItem.fromThreadGoalEvent(CodexEvent event) {
    final goal = event.threadGoal!;
    return ChatTimelineItem(
      itemId: _threadGoalItemId(goal),
      itemType: 'threadGoalUpdate',
      text: '/goal ${goal.objective}',
      output: '',
      status: goal.status,
      threadGoal: goal,
      raw: event.raw,
    );
  }

  final String itemId;
  final String itemType;
  final String text;
  final String output;
  final String? command;
  final String? cwd;
  final String? status;
  final int? exitCode;
  final int? durationMs;
  final String? server;
  final String? tool;
  final ThreadGoal? threadGoal;
  final List<ThreadFileChangeSummary> fileChanges;
  final Map<String, Object?> raw;

  bool get isLocalUserMessage =>
      itemType == 'userMessage' && raw['local'] == true;

  bool get isLocalQueuedInstruction =>
      itemType == 'queuedInstruction' && raw['local'] == true;

  ChatTimelineItem copyWith({
    String? text,
    String? output,
    List<ThreadFileChangeSummary>? fileChanges,
  }) {
    return ChatTimelineItem(
      itemId: itemId,
      itemType: itemType,
      text: text ?? this.text,
      output: output ?? this.output,
      command: command,
      cwd: cwd,
      status: status,
      exitCode: exitCode,
      durationMs: durationMs,
      server: server,
      tool: tool,
      threadGoal: threadGoal,
      fileChanges: fileChanges ?? this.fileChanges,
      raw: raw,
    );
  }

  ChatTimelineItem merge(ChatTimelineItem next) {
    return ChatTimelineItem(
      itemId: itemId,
      itemType: next.itemType == 'unknown' ? itemType : next.itemType,
      text: next.text.isEmpty ? text : next.text,
      output: next.output.isEmpty ? output : next.output,
      command: next.command ?? command,
      cwd: next.cwd ?? cwd,
      status: next.status ?? status,
      exitCode: next.exitCode ?? exitCode,
      durationMs: next.durationMs ?? durationMs,
      server: next.server ?? server,
      tool: next.tool ?? tool,
      threadGoal: next.threadGoal ?? threadGoal,
      fileChanges: next.fileChanges.isEmpty ? fileChanges : next.fileChanges,
      raw: next.raw.isEmpty ? raw : next.raw,
    );
  }

  ChatTimelineItem mergeLive(ChatTimelineItem liveItem) {
    return ChatTimelineItem(
      itemId: itemId,
      itemType: itemType == 'unknown' ? liveItem.itemType : itemType,
      text: _mergeText(text, liveItem.text),
      output: _mergeText(output, liveItem.output),
      command: command ?? liveItem.command,
      cwd: cwd ?? liveItem.cwd,
      status: liveItem.status ?? status,
      exitCode: liveItem.exitCode ?? exitCode,
      durationMs: liveItem.durationMs ?? durationMs,
      server: server ?? liveItem.server,
      tool: tool ?? liveItem.tool,
      threadGoal: liveItem.threadGoal ?? threadGoal,
      fileChanges: fileChanges.isEmpty ? liveItem.fileChanges : fileChanges,
      raw: raw.isEmpty ? liveItem.raw : raw,
    );
  }
}

String _mergeStatus(String snapshotStatus, String liveStatus) {
  if (_isTerminalStatus(snapshotStatus)) {
    return snapshotStatus;
  }
  if (_isTerminalStatus(liveStatus)) {
    return liveStatus;
  }
  return snapshotStatus == 'unknown' ? liveStatus : snapshotStatus;
}

bool _isTerminalStatus(String status) {
  return status == 'completed' || status == 'failed' || status == 'interrupted';
}

String _mergeText(String snapshotText, String liveText) {
  if (snapshotText.isEmpty) {
    return liveText;
  }
  if (liveText.isEmpty) {
    return snapshotText;
  }
  if (liveText.startsWith(snapshotText)) {
    return liveText;
  }
  if (snapshotText.startsWith(liveText)) {
    return snapshotText;
  }
  return snapshotText;
}

String? _normalized(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

void _reconcileLocalUserProjections(
  List<ChatTimelineItem> items,
  ChatTimelineItem authoritative,
) {
  items.removeWhere((item) => item.isLocalUserMessage);
  final authoritativeText = _normalized(authoritative.text);
  if (authoritativeText == null) {
    return;
  }
  final queuedIndex = items.indexWhere(
    (item) =>
        item.isLocalQueuedInstruction &&
        _normalized(item.text) == authoritativeText,
  );
  if (queuedIndex != -1) {
    items.removeAt(queuedIndex);
  }
}

String _localUserMessageItemId(String turnId) => 'local_user_$turnId';

String _localInstructionItemId({
  required String type,
  required String turnId,
  required int sequence,
}) {
  return 'local_${type}_${Uri.encodeComponent(turnId)}_$sequence';
}

String _threadGoalItemId(ThreadGoal goal) {
  final createdAt = goal.createdAtSeconds > 0
      ? goal.createdAtSeconds
      : goal.updatedAtSeconds;
  return 'thread_goal_${Uri.encodeComponent(goal.threadId)}_$createdAt';
}
