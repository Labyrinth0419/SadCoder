class ThreadGoal {
  const ThreadGoal({
    required this.threadId,
    required this.objective,
    required this.status,
    required this.tokensUsed,
    required this.timeUsedSeconds,
    required this.createdAtSeconds,
    required this.updatedAtSeconds,
    required this.raw,
    this.tokenBudget,
  });

  static ThreadGoal? fromJson(Object? value) {
    final map = _objectMap(value);
    final threadId = _stringValue(map['threadId']);
    final objective = _stringValue(map['objective']);
    if (threadId == null || objective == null) {
      return null;
    }
    return ThreadGoal(
      threadId: threadId,
      objective: objective,
      status: _stringValue(map['status']) ?? 'active',
      tokenBudget: _intValue(map['tokenBudget']),
      tokensUsed: _intValue(map['tokensUsed']) ?? 0,
      timeUsedSeconds: _intValue(map['timeUsedSeconds']) ?? 0,
      createdAtSeconds: _intValue(map['createdAt']) ?? 0,
      updatedAtSeconds: _intValue(map['updatedAt']) ?? 0,
      raw: map,
    );
  }

  final String threadId;
  final String objective;
  final String status;
  final int? tokenBudget;
  final int tokensUsed;
  final int timeUsedSeconds;
  final int createdAtSeconds;
  final int updatedAtSeconds;
  final Map<String, Object?> raw;
}

class ThreadGoalSetResult {
  const ThreadGoalSetResult({required this.goal});

  factory ThreadGoalSetResult.fromJson(Map<String, Object?> json) {
    final goal = ThreadGoal.fromJson(json['goal']);
    if (goal == null) {
      throw const FormatException('thread/goal/set response missing goal.');
    }
    return ThreadGoalSetResult(goal: goal);
  }

  final ThreadGoal goal;
}

class ThreadGoalGetResult {
  const ThreadGoalGetResult({this.goal});

  factory ThreadGoalGetResult.fromJson(Map<String, Object?> json) {
    return ThreadGoalGetResult(goal: ThreadGoal.fromJson(json['goal']));
  }

  final ThreadGoal? goal;
}

class ThreadGoalClearResult {
  const ThreadGoalClearResult({required this.cleared});

  factory ThreadGoalClearResult.fromJson(Map<String, Object?> json) {
    return ThreadGoalClearResult(cleared: json['cleared'] == true);
  }

  final bool cleared;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return Map.unmodifiable(value);
  }
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
