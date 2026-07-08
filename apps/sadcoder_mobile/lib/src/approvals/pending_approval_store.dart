import 'dart:collection';

import '../protocol/json_rpc.dart';
import 'approval_request_mapper.dart';
import 'pending_approval.dart';

const serverRequestResolvedMethod = 'serverRequest/resolved';

class PendingApprovalStore {
  PendingApprovalStore({
    Iterable<PendingApproval> initialApprovals = const [],
  }) {
    for (final approval in initialApprovals) {
      upsert(approval);
    }
  }

  final LinkedHashMap<Object, PendingApproval> _byRequestId = LinkedHashMap();

  int get length => _byRequestId.length;

  bool get isEmpty => _byRequestId.isEmpty;

  bool get isNotEmpty => _byRequestId.isNotEmpty;

  List<PendingApproval> get approvals => List.unmodifiable(_byRequestId.values);

  PendingApproval? byRequestId(Object requestId) => _byRequestId[requestId];

  PendingApproval upsert(PendingApproval approval) {
    _byRequestId[approval.requestId] = approval;
    return approval;
  }

  PendingApproval ingestServerRequest(JsonRpcServerRequest request) {
    return upsert(pendingApprovalFromServerRequest(request));
  }

  PendingApproval? resolveRequest(Object requestId) {
    return _byRequestId.remove(requestId);
  }

  PendingApproval? applyNotification(Map<String, Object?> notification) {
    if (notification['method'] != serverRequestResolvedMethod) {
      return null;
    }

    final params = _stringKeyedMap(notification['params']);
    final requestId = params['requestId'];
    if (requestId == null) {
      return null;
    }

    return resolveRequest(requestId);
  }

  void clear() {
    _byRequestId.clear();
  }
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
