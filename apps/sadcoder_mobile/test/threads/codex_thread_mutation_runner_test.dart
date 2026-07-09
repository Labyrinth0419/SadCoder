import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/threads/codex_thread_mutation_runner.dart';

void main() {
  test(
    'forkThread returns the forked thread from app-server response',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {
          'thread': {
            'id': 'thr_fork',
            'sessionId': 'sess_1',
            'preview': 'Forked work',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'forkedFromId': 'thr_source',
            'turns': <Object?>[],
          },
        };
      });
      final runner = CodexThreadMutationRunner(CodexAppServerClient(transport));

      final thread = await runner.forkThread(threadId: 'thr_source');

      expect(thread.id, 'thr_fork');
      expect(thread.forkedFromId, 'thr_source');
      expect(requests.single.method, 'thread/fork');
      expect(requests.single.params, {'threadId': 'thr_source'});
    },
  );

  test('compactThread starts server compaction for the thread', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });
    final runner = CodexThreadMutationRunner(CodexAppServerClient(transport));

    await runner.compactThread(threadId: 'thr_1');

    expect(requests.single.method, 'thread/compact/start');
    expect(requests.single.params, {'threadId': 'thr_1'});
  });
}
