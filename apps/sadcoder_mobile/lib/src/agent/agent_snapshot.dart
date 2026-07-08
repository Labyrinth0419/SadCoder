import '../protocol/json_rpc.dart';

class AgentSnapshot {
  const AgentSnapshot({
    required this.schemaVersion,
    required this.pendingApprovals,
    required this.recentEvents,
  });

  factory AgentSnapshot.fromJson(Map<String, Object?> json) {
    return AgentSnapshot(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      pendingApprovals: _listOfMaps(json['pendingApprovals'])
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
        json['recentEvents'],
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
