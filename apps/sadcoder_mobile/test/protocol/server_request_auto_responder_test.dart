import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/protocol/server_request_auto_responder.dart';

void main() {
  test('responds to currentTime/read with whole Unix seconds', () async {
    final transport = MemoryJsonRpcTransport((_) async => {});
    final responder = ServerRequestAutoResponder(
      transport: transport,
      currentUnixTimeProvider: () => 1762865600,
    );
    addTearDown(responder.close);
    addTearDown(transport.close);

    transport.emitServerRequest(
      const JsonRpcServerRequest(
        id: 'time-1',
        method: currentTimeReadMethod,
        params: {'threadId': 'thr_1'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(transport.responses.single.toJson(), {
      'jsonrpc': '2.0',
      'id': 'time-1',
      'result': {'currentTimeAt': 1762865600},
    });
  });

  test('ignores server requests owned by other handlers', () async {
    final transport = MemoryJsonRpcTransport((_) async => {});
    final responder = ServerRequestAutoResponder(
      transport: transport,
      currentUnixTimeProvider: () => 1762865600,
    );
    addTearDown(responder.close);
    addTearDown(transport.close);

    transport.emitServerRequest(
      const JsonRpcServerRequest(id: 7, method: 'future/request'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(transport.responses, isEmpty);
  });

  test(
    'rejects known unsupported server requests with explicit errors',
    () async {
      final transport = MemoryJsonRpcTransport((_) async => {});
      final responder = ServerRequestAutoResponder(transport: transport);
      addTearDown(responder.close);
      addTearDown(transport.close);

      const methods = [
        dynamicToolCallMethod,
        chatgptAuthTokensRefreshMethod,
        attestationGenerateMethod,
        legacyApplyPatchApprovalMethod,
        legacyExecCommandApprovalMethod,
      ];

      for (var index = 0; index < methods.length; index += 1) {
        final method = methods[index];
        transport.emitServerRequest(
          JsonRpcServerRequest(
            id: 'unsupported-$index',
            method: method,
            params: const {'threadId': 'thr_1'},
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);

      expect(transport.responses, hasLength(methods.length));
      for (var index = 0; index < transport.responses.length; index += 1) {
        final response = transport.responses[index];
        expect(response.toJson(), {
          'jsonrpc': '2.0',
          'id': 'unsupported-$index',
          'error': {
            'code': unsupportedServerRequestErrorCode,
            'message': unsupportedServerRequestMessage(methods[index]),
            'data': {'method': methods[index]},
          },
        });
      }
    },
  );

  test('identifies auto-handled server request methods', () {
    expect(
      isAutoHandledServerRequest(
        const JsonRpcServerRequest(id: 'time-1', method: currentTimeReadMethod),
      ),
      true,
    );
    expect(
      isAutoHandledServerRequest(
        const JsonRpcServerRequest(id: 'tool-1', method: dynamicToolCallMethod),
      ),
      true,
    );
    expect(
      isAutoHandledServerRequest(
        const JsonRpcServerRequest(id: 'future-1', method: 'future/request'),
      ),
      false,
    );
  });
}
