import 'package:flutter/foundation.dart';

class ThreadTokenUsageController extends ChangeNotifier {
  final Map<String, ThreadTokenUsageSnapshot> _snapshotsByThread = {};
  ThreadTokenUsageSnapshot? _latest;

  Map<String, ThreadTokenUsageSnapshot> get snapshotsByThread =>
      Map.unmodifiable(_snapshotsByThread);

  ThreadTokenUsageSnapshot? get latest => _latest;

  ThreadTokenUsageSnapshot? latestForThread(String? threadId) {
    final normalizedThreadId = threadId?.trim();
    if (normalizedThreadId == null || normalizedThreadId.isEmpty) {
      return null;
    }
    return _snapshotsByThread[normalizedThreadId];
  }

  void ingestTokenUsageUpdated(Map<String, Object?> payload) {
    final snapshot = ThreadTokenUsageSnapshot.fromJson(payload);
    if (snapshot == null) {
      return;
    }
    _snapshotsByThread[snapshot.threadId] = snapshot;
    _latest = snapshot;
    notifyListeners();
  }
}

class ThreadTokenUsageSnapshot {
  const ThreadTokenUsageSnapshot({
    required this.threadId,
    required this.turnId,
    required this.usage,
    required this.raw,
  });

  static ThreadTokenUsageSnapshot? fromJson(Map<String, Object?> json) {
    final threadId = _stringField(json, ['threadId', 'thread_id']);
    final turnId = _stringField(json, ['turnId', 'turn_id']);
    final usage = ThreadTokenUsage.fromJson(
      _valueField(json, ['tokenUsage', 'token_usage']),
    );
    if (threadId == null || turnId == null || usage == null) {
      return null;
    }
    return ThreadTokenUsageSnapshot(
      threadId: threadId,
      turnId: turnId,
      usage: usage,
      raw: Map.unmodifiable(json),
    );
  }

  final String threadId;
  final String turnId;
  final ThreadTokenUsage usage;
  final Map<String, Object?> raw;
}

class ThreadTokenUsage {
  const ThreadTokenUsage({
    required this.last,
    required this.total,
    this.modelContextWindow,
  });

  static ThreadTokenUsage? fromJson(Object? value) {
    final map = _objectMap(value);
    if (map.isEmpty) {
      return null;
    }
    final last = TokenUsageBreakdown.fromJson(map['last']);
    final total = TokenUsageBreakdown.fromJson(map['total']);
    if (last == null || total == null) {
      return null;
    }
    return ThreadTokenUsage(
      last: last,
      total: total,
      modelContextWindow: _intField(map, [
        'modelContextWindow',
        'model_context_window',
      ]),
    );
  }

  final TokenUsageBreakdown last;
  final TokenUsageBreakdown total;
  final int? modelContextWindow;
}

class TokenUsageBreakdown {
  const TokenUsageBreakdown({
    required this.cachedInputTokens,
    required this.inputTokens,
    required this.outputTokens,
    required this.reasoningOutputTokens,
    required this.totalTokens,
  });

  static TokenUsageBreakdown? fromJson(Object? value) {
    final map = _objectMap(value);
    if (map.isEmpty) {
      return null;
    }
    final cachedInputTokens = _intField(map, [
      'cachedInputTokens',
      'cached_input_tokens',
    ]);
    final inputTokens = _intField(map, ['inputTokens', 'input_tokens']);
    final outputTokens = _intField(map, ['outputTokens', 'output_tokens']);
    final reasoningOutputTokens = _intField(map, [
      'reasoningOutputTokens',
      'reasoning_output_tokens',
    ]);
    final totalTokens = _intField(map, ['totalTokens', 'total_tokens']);
    if (cachedInputTokens == null ||
        inputTokens == null ||
        outputTokens == null ||
        reasoningOutputTokens == null ||
        totalTokens == null) {
      return null;
    }
    return TokenUsageBreakdown(
      cachedInputTokens: cachedInputTokens,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      reasoningOutputTokens: reasoningOutputTokens,
      totalTokens: totalTokens,
    );
  }

  final int cachedInputTokens;
  final int inputTokens;
  final int outputTokens;
  final int reasoningOutputTokens;
  final int totalTokens;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    final result = <String, Object?>{};
    value.forEach((key, mapValue) {
      result[key.toString()] = mapValue;
    });
    return Map.unmodifiable(result);
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String? _stringField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _stringValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

int? _intField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _intValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

Object? _valueField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value != null) {
      return value;
    }
  }
  return null;
}
