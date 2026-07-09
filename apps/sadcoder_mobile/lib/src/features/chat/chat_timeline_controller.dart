import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../events/codex_event.dart';
import '../../threads/thread_summary.dart';

typedef TurnCompletedHandler =
    void Function({required String threadId, required TurnSummary turn});

class ChatTimelineController extends ChangeNotifier {
  ChatTimelineController({TurnCompletedHandler? onTurnCompleted})
    : _onTurnCompleted = onTurnCompleted;

  final TurnCompletedHandler? _onTurnCompleted;
  final List<ChatTimelineTurn> _turns = [];
  Stream<CodexEvent>? _attachedEvents;
  StreamSubscription<CodexEvent>? _subscription;

  List<ChatTimelineTurn> get turns => List.unmodifiable(_turns);

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
    switch (event.kind) {
      case CodexEventKind.turnStarted:
        _upsertTurn(event, status: event.turn?.status ?? 'inProgress');
      case CodexEventKind.turnCompleted:
        _upsertTurn(event, status: event.turn?.status ?? 'completed');
        final threadId = event.threadId;
        final turn = event.turn;
        if (threadId != null && turn != null) {
          _onTurnCompleted?.call(threadId: threadId, turn: turn);
        }
      case CodexEventKind.itemStarted || CodexEventKind.itemCompleted:
        _upsertItem(event);
      case CodexEventKind.agentMessageDelta:
        _appendDelta(event, fallbackType: 'agentMessage');
      case CodexEventKind.commandExecutionOutputDelta:
        _appendDelta(event, fallbackType: 'commandExecution', asOutput: true);
      case CodexEventKind.planDelta:
        _appendDelta(event, fallbackType: 'plan');
      case CodexEventKind.threadStarted || CodexEventKind.unknown:
        return;
    }
    notifyListeners();
  }

  void clear() {
    _turns.clear();
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

class ChatTimelineTurn {
  const ChatTimelineTurn({
    required this.threadId,
    required this.turnId,
    required this.status,
    required this.items,
  });

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
}

class ChatTimelineItem {
  const ChatTimelineItem({
    required this.itemId,
    required this.itemType,
    required this.text,
    required this.output,
    required this.raw,
  });

  factory ChatTimelineItem.fromEvent(CodexEvent event) {
    final raw = event.item ?? const <String, Object?>{};
    return ChatTimelineItem(
      itemId: event.itemId ?? '',
      itemType: event.itemType ?? 'unknown',
      text: _stringValue(raw['text']) ?? '',
      output: _stringValue(raw['aggregatedOutput']) ?? '',
      raw: raw,
    );
  }

  final String itemId;
  final String itemType;
  final String text;
  final String output;
  final Map<String, Object?> raw;

  ChatTimelineItem copyWith({String? text, String? output}) {
    return ChatTimelineItem(
      itemId: itemId,
      itemType: itemType,
      text: text ?? this.text,
      output: output ?? this.output,
      raw: raw,
    );
  }

  ChatTimelineItem merge(ChatTimelineItem next) {
    return ChatTimelineItem(
      itemId: itemId,
      itemType: next.itemType == 'unknown' ? itemType : next.itemType,
      text: next.text.isEmpty ? text : next.text,
      output: next.output.isEmpty ? output : next.output,
      raw: next.raw.isEmpty ? raw : next.raw,
    );
  }
}

String? _stringValue(Object? value) => value is String ? value : null;
