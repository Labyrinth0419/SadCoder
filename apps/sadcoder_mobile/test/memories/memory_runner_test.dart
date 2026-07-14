import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/memories/codex_memory_runner.dart';
import 'package:sadcoder_mobile/src/memories/memory_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test(
    'sets thread mode and resets global memory through app-server',
    () async {
      final requests = <JsonRpcRequest>[];
      final runner = CodexMemoryRunner(
        CodexAppServerClient(
          MemoryJsonRpcTransport((request) {
            requests.add(request);
            return {};
          }),
        ),
      );

      await runner.setThreadMemoryMode(
        threadId: ' thread-1 ',
        mode: ThreadMemoryMode.enabled,
      );
      await runner.resetMemory();

      expect(requests.map((request) => request.method), [
        'thread/memoryMode/set',
        'memory/reset',
      ]);
      expect(requests.first.params, {
        'threadId': 'thread-1',
        'mode': 'enabled',
      });
      expect(requests.last.params, isNull);
    },
  );

  test('parses memory mode from current and legacy thread shapes', () {
    expect(
      threadMemoryModeFromRaw(const {'memoryMode': 'enabled'}),
      ThreadMemoryMode.enabled,
    );
    expect(
      threadMemoryModeFromRaw(const {
        'memory': {'memory_mode': 'disabled'},
      }),
      ThreadMemoryMode.disabled,
    );
    expect(threadMemoryModeFromRaw(const {}), isNull);
  });
}
