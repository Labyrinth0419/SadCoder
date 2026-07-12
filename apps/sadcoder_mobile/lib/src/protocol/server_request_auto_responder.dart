import 'dart:async';

import 'json_rpc.dart';

const currentTimeReadMethod = 'currentTime/read';
const dynamicToolCallMethod = 'item/tool/call';
const attestationGenerateMethod = 'attestation/generate';
const legacyApplyPatchApprovalMethod = 'applyPatchApproval';
const legacyExecCommandApprovalMethod = 'execCommandApproval';
const unsupportedServerRequestErrorCode = -32000;

typedef CurrentUnixTimeProvider = int Function();

bool isAutoHandledServerRequest(JsonRpcServerRequest request) {
  return request.method == currentTimeReadMethod ||
      unsupportedServerRequestMessage(request.method) != null;
}

String? unsupportedServerRequestMessage(String method) {
  return _unsupportedServerRequestMessages[method];
}

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
    if (request.method == currentTimeReadMethod) {
      unawaited(_respondCurrentTime(request).catchError((Object _) {}));
      return;
    }
    final unsupportedMessage = unsupportedServerRequestMessage(request.method);
    if (unsupportedMessage != null) {
      unawaited(
        _respondUnsupported(
          request,
          unsupportedMessage,
        ).catchError((Object _) {}),
      );
    }
  }

  Future<void> _respondCurrentTime(JsonRpcServerRequest request) {
    return _transport.respond(
      JsonRpcResponseMessage(
        id: request.id,
        result: {'currentTimeAt': _currentUnixTimeProvider()},
      ),
    );
  }

  Future<void> _respondUnsupported(
    JsonRpcServerRequest request,
    String message,
  ) {
    return _transport.respond(
      JsonRpcResponseMessage(
        id: request.id,
        error: {
          'code': unsupportedServerRequestErrorCode,
          'message': message,
          'data': {'method': request.method},
        },
      ),
    );
  }
}

int _defaultCurrentUnixTimeProvider() {
  return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
}

const _unsupportedServerRequestMessages = {
  dynamicToolCallMethod:
      'Dynamic tool calls are not available in SadCoder mobile yet.',
  attestationGenerateMethod:
      'Attestation generation is not available in SadCoder mobile.',
  legacyApplyPatchApprovalMethod:
      'Legacy patch approval requests are not available in SadCoder mobile.',
  legacyExecCommandApprovalMethod:
      'Legacy command approval requests are not available in SadCoder mobile.',
};
