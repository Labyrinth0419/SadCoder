import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('initialize sends initialized notification after request', () async {
    final requests = <JsonRpcRequest>[];
    final notifications = <Map<String, Object?>>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'userAgent': 'SadCoder test'};
    });
    final subscription = transport.notifications.listen(notifications.add);

    final client = CodexAppServerClient(transport);
    final result = await client.initialize();

    expect(result['userAgent'], 'SadCoder test');
    expect(requests.single.method, 'initialize');
    expect(requests.single.params?['capabilities'], {'experimentalApi': true});
    expect(notifications.single['method'], 'initialized');

    await subscription.cancel();
  });

  test('model and thread methods use app-server method names', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });

    final client = CodexAppServerClient(transport);
    await client.listModels();
    await client.listThreads(limit: 5);

    expect(requests.map((request) => request.method), [
      'model/list',
      'thread/list',
    ]);
    expect(requests.first.params, isEmpty);
    expect(requests.last.params?['limit'], 5);
  });
}
