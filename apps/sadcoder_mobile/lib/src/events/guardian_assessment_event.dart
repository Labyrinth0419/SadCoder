class GuardianAssessmentEvent {
  const GuardianAssessmentEvent({
    required this.id,
    required this.threadId,
    required this.turnId,
    required this.startedAtMs,
    required this.status,
    required this.action,
    this.targetItemId,
    this.completedAtMs,
    this.riskLevel,
    this.userAuthorization,
    this.rationale,
    this.decisionSource,
  });

  factory GuardianAssessmentEvent.fromAutoReviewNotification(
    Map<String, Object?> params,
  ) {
    final review = _stringKeyedMap(params['review']);
    final action = _normalizeAction(_stringKeyedMap(params['action']));
    return GuardianAssessmentEvent(
      id: _requiredString(params['reviewId'], 'reviewId'),
      threadId: _requiredString(params['threadId'], 'threadId'),
      turnId: _requiredString(params['turnId'], 'turnId'),
      targetItemId: _stringValue(params['targetItemId']),
      startedAtMs: _intValue(params['startedAtMs']) ?? 0,
      completedAtMs: _intValue(params['completedAtMs']),
      status: _normalizeStatus(_requiredString(review['status'], 'status')),
      riskLevel: _normalizeLowercase(_stringValue(review['riskLevel'])),
      userAuthorization: _normalizeLowercase(
        _stringValue(review['userAuthorization']),
      ),
      rationale: _stringValue(review['rationale']),
      decisionSource: _normalizeDecisionSource(
        _stringValue(params['decisionSource']),
      ),
      action: action,
    );
  }

  final String id;
  final String threadId;
  final String turnId;
  final String? targetItemId;
  final int startedAtMs;
  final int? completedAtMs;
  final String status;
  final String? riskLevel;
  final String? userAuthorization;
  final String? rationale;
  final String? decisionSource;
  final Map<String, Object?> action;

  bool get isDenied => status == 'denied';

  Map<String, Object?> toJson() {
    return {
      'id': id,
      if (targetItemId != null) 'target_item_id': targetItemId,
      'turn_id': turnId,
      'started_at_ms': startedAtMs,
      if (completedAtMs != null) 'completed_at_ms': completedAtMs,
      'status': status,
      if (riskLevel != null) 'risk_level': riskLevel,
      if (userAuthorization != null) 'user_authorization': userAuthorization,
      if (rationale != null) 'rationale': rationale,
      if (decisionSource != null) 'decision_source': decisionSource,
      'action': action,
    };
  }
}

class RecentAutoReviewDenials {
  RecentAutoReviewDenials({this.maxEntries = 10});

  final int maxEntries;
  final List<GuardianAssessmentEvent> _entries = [];

  List<GuardianAssessmentEvent> get entries => List.unmodifiable(_entries);

  void ingest(GuardianAssessmentEvent event) {
    if (!event.isDenied) {
      return;
    }
    _entries.removeWhere((entry) => entry.id == event.id);
    _entries.insert(0, event);
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
  }

  GuardianAssessmentEvent? latest({String? threadId}) {
    for (final entry in _entries) {
      if (threadId == null || entry.threadId == threadId) {
        return entry;
      }
    }
    return null;
  }

  bool remove(String id) {
    final before = _entries.length;
    _entries.removeWhere((entry) => entry.id == id);
    return _entries.length != before;
  }

  void clear() {
    _entries.clear();
  }
}

Map<String, Object?> _normalizeAction(Map<String, Object?> action) {
  final normalized = _snakeCaseMap(action);
  final type = normalized['type'];
  if (type is String) {
    normalized['type'] = _camelToSnake(type);
  }
  final source = normalized['source'];
  if (source is String) {
    normalized['source'] = _camelToSnake(source);
  }
  return Map.unmodifiable(normalized);
}

Map<String, Object?> _snakeCaseMap(Map<String, Object?> value) {
  return value.map(
    (key, value) => MapEntry(_camelToSnake(key), _normalizeJsonValue(value)),
  );
}

Object? _normalizeJsonValue(Object? value) {
  if (value is Map<String, Object?>) {
    return _snakeCaseMap(value);
  }
  if (value is Map) {
    return _snakeCaseMap(
      value.map((key, value) => MapEntry(key.toString(), value as Object?)),
    );
  }
  if (value is List) {
    return value.map(_normalizeJsonValue).toList(growable: false);
  }
  return value;
}

String _camelToSnake(String value) {
  return value.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9])[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  );
}

String _normalizeStatus(String value) => _camelToSnake(value);

String? _normalizeLowercase(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return _camelToSnake(value.trim());
}

String? _normalizeDecisionSource(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return _camelToSnake(value.trim());
}

Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }
  return const {};
}

String _requiredString(Object? value, String fieldName) {
  final string = _stringValue(value);
  if (string == null || string.isEmpty) {
    throw FormatException('Missing guardian assessment field: $fieldName');
  }
  return string;
}

String? _stringValue(Object? value) => value is String ? value : null;

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return null;
}
