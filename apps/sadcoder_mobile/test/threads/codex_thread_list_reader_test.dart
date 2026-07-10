import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/threads/codex_thread_list_reader.dart';

void main() {
  test('listThreads forwards active and archived filters', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'data': <Object?>[]};
    });
    final reader = CodexThreadListReader(CodexAppServerClient(transport));

    await reader.listThreads(limit: 5);
    await reader.listThreads(limit: 10, archived: true);

    expect(requests.map((request) => request.method), [
      'thread/list',
      'thread/list',
    ]);
    expect(requests.map((request) => request.params), [
      {'limit': 5},
      {'limit': 10, 'archived': true},
    ]);
  });
}
