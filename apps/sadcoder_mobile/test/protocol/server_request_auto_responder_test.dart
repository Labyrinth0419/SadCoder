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
}
