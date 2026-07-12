import 'dart:async';

import 'json_rpc.dart';

const currentTimeReadMethod = 'currentTime/read';

typedef CurrentUnixTimeProvider = int Function();

class ServerRequestAutoResponder {
  ServerRequestAutoResponder({
    required JsonRpcTransport transport,
    CurrentUnixTimeProvider? currentUnixTimeProvider,
  }) : _transport = transport,
       _currentUnixTimeProvider =
           currentUnixTimeProvider ?? _defaultCurrentUnixTimeProvider {
    _subscription = _transport.serverRequests.listen(_handleServerRequest);
  }

  final JsonRpcTransport _transport;
  final CurrentUnixTimeProvider _currentUnixTimeProvider;
  late final StreamSubscription<JsonRpcServerRequest> _subscription;

  Future<void> close() => _subscription.cancel();

  void _handleServerRequest(JsonRpcServerRequest request) {
    if (request.method != currentTimeReadMethod) {
      return;
    }
    unawaited(_respondCurrentTime(request).catchError((Object _) {}));
  }

  Future<void> _respondCurrentTime(JsonRpcServerRequest request) {
    return _transport.respond(
      JsonRpcResponseMessage(
        id: request.id,
        result: {'currentTimeAt': _currentUnixTimeProvider()},
      ),
    );
  }
}

int _defaultCurrentUnixTimeProvider() {
  return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
}
