import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../events/codex_event.dart';
import '../../events/guardian_assessment_event.dart';
import '../../threads/thread_summary.dart';

typedef TurnCompletedHandler =
    void Function({required String threadId, required TurnSummary turn});

class ChatTimelineController extends ChangeNotifier {
  ChatTimelineController({TurnCompletedHandler? onTurnCompleted})
    : _onTurnCompleted = onTurnCompleted;

  final TurnCompletedHandler? _onTurnCompleted;
  final List<ChatTimelineTurn> _turns = [];
  final RecentAutoReviewDenials _recentAutoReviewDenials =
      RecentAutoReviewDenials();
  String? _selectedThreadId;
  Stream<CodexEvent>? _attachedEvents;
  StreamSubscription<CodexEvent>? _subscription;

  List<ChatTimelineTurn> get turns => List.unmodifiable(_turns);

  String? get selectedThreadId => _selectedThreadId;

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
          CodexEventKind.unknown:
        return;
    }
    notifyListeners();
  }

  void showThread(ThreadSummary thread) {
    if (thread.id.isEmpty) {
      clear();
      return;
    }
    final liveTurns = _selectedThreadId == thread.id
        ? List<ChatTimelineTurn>.from(_turns)
        : const <ChatTimelineTurn>[];
    _selectedThreadId = thread.id;
    _turns
      ..clear()
      ..addAll(
        thread.turns.map(
          (turn) =>
              ChatTimelineTurn.fromTurnSummary(threadId: thread.id, turn: turn),
        ),
      );
    for (final liveTurn in liveTurns) {
      _mergeTurn(liveTurn);
    }
    notifyListeners();
  }

  void selectThread(String? threadId) {
    final normalizedThreadId = threadId?.trim();
    if (normalizedThreadId == null || normalizedThreadId.isEmpty) {
      clear();
      return;
    }
    _selectedThreadId = normalizedThreadId;
    _turns.clear();
    notifyListeners();
  }

  void showTurn({required String threadId, required TurnSummary turn}) {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty || turn.id.isEmpty) {
      return;
    }
    if (_selectedThreadId != normalizedThreadId) {
      _turns.clear();
    }
    _selectedThreadId = normalizedThreadId;
    _mergeTurn(
      ChatTimelineTurn.fromTurnSummary(
        threadId: normalizedThreadId,
        turn: turn,
      ),
    );
    notifyListeners();
  }

  void restoreCachedItems({
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
    }
    _selectedThreadId = normalizedThreadId;
    var changed = selectedChanged;
    for (final item in items) {
      if (item.id.trim().isEmpty) {
        continue;
      }
      changed =
          _mergeCachedItem(
            threadId: normalizedThreadId,
            turnId: item.turnId,
            item: item,
          ) ||
          changed;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void clear() {
    _selectedThreadId = null;
    _turns.clear();
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
      return;
    }
    _turns[index] = _turns[index].copyWith(status: status);
  }

  void _mergeTurn(ChatTimelineTurn next) {
    final index = _turns.indexWhere((turn) => turn.turnId == next.turnId);
    if (index == -1) {
      _turns.add(next);
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
    if (itemIndex == -1) {
      items.add(item);
    } else {
      items[itemIndex] = item.mergeLive(items[itemIndex]);
    }
    _turns[turnIndex] = turn.copyWith(items: items);
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
    final itemIndex = items.indexWhere((item) => item.itemId == itemId);
    final item = ChatTimelineItem.fromEvent(event);
    if (itemIndex == -1) {
      items.add(item);
    } else {
      items[itemIndex] = items[itemIndex].merge(item);
    }
    _turns[turnIndex] = turn.copyWith(items: items);
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
  }

  int? _ensureTurn(CodexEvent event) {
    final threadId = event.threadId;
    final turnId = event.turnId;
    if (threadId == null || turnId == null || turnId.isEmpty) {
      return null;
    }
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
}

const _cachedItemsTurnId = 'cached_items';

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
      final index = mergedItems.indexWhere(
        (item) => item.itemId == liveItem.itemId,
      );
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
  final List<ThreadFileChangeSummary> fileChanges;
  final Map<String, Object?> raw;

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
