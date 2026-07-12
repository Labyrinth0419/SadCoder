import '../protocol/json_rpc.dart';

class AgentSnapshot {
  const AgentSnapshot({
    required this.schemaVersion,
    required this.pendingApprovals,
    required this.recentEvents,
    this.deliveredCursor,
    this.retainedCursorFloor,
    this.cursorGap = false,
  });

  factory AgentSnapshot.fromJson(Map<String, Object?> json) {
    return AgentSnapshot(
      schemaVersion: _intField(json, ['schemaVersion', 'schema_version']) ?? 1,
      pendingApprovals:
          _listOfMaps(
                _valueField(json, ['pendingApprovals', 'pending_approvals']),
              )
              .map(
                (approval) => JsonRpcServerRequest(
                  id: approval['id'] ?? '',
                  method: approval['method'] as String? ?? '',
                  params: approval['params'],
                ),
              )
              .where((approval) => approval.method.isNotEmpty)
              .toList(growable: false),
      recentEvents: _listOfMaps(
        _valueField(json, ['recentEvents', 'recent_events']),
      ).map(AgentCachedEvent.fromJson).toList(growable: false),
      deliveredCursor: _stringField(json, [
        'deliveredCursor',
        'delivered_cursor',
      ]),
      retainedCursorFloor: _stringField(json, [
        'retainedCursorFloor',
        'retained_cursor_floor',
      ]),
      cursorGap: _boolField(json, ['cursorGap', 'cursor_gap']) ?? false,
    );
  }

  final int schemaVersion;
  final List<JsonRpcServerRequest> pendingApprovals;
  final List<AgentCachedEvent> recentEvents;
  final String? deliveredCursor;
  final String? retainedCursorFloor;
  final bool cursorGap;
}

class AgentCachedEvent {
  const AgentCachedEvent({required this.method, this.params, this.cursor});

  factory AgentCachedEvent.fromJson(Map<String, Object?> json) {
    return AgentCachedEvent(
      method: json['method'] as String? ?? '',
      params: json['params'],
      cursor: _stringField(json, ['cursor']),
    );
  }

  final String method;
  final Object? params;
  final String? cursor;

  Map<String, Object?> toNotification() {
    return {'method': method, if (params != null) 'params': params};
  }
}

List<Map<String, Object?>> _listOfMaps(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((entry) => Map<String, Object?>.from(entry))
      .toList(growable: false);
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

int? _intField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _intValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

String? _stringField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

bool? _boolField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) {
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
