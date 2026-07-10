import '../protocol/json_rpc.dart';

class AgentSnapshot {
  const AgentSnapshot({
    required this.schemaVersion,
    required this.pendingApprovals,
    required this.recentEvents,
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
    );
  }

  final int schemaVersion;
  final List<JsonRpcServerRequest> pendingApprovals;
  final List<AgentCachedEvent> recentEvents;
}

class AgentCachedEvent {
  const AgentCachedEvent({required this.method, this.params});

  factory AgentCachedEvent.fromJson(Map<String, Object?> json) {
    return AgentCachedEvent(
      method: json['method'] as String? ?? '',
      params: json['params'],
    );
  }

  final String method;
  final Object? params;

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

Object? _valueField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value != null) {
      return value;
    }
  }
  return null;
}
