import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/background_terminals/codex_thread_background_terminal_runner.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('ThreadBackgroundTerminalPage parses list responses', () {
    final page = ThreadBackgroundTerminalPage.fromJson({
      'data': [
        {
          'itemId': 'item_1',
          'processId': 'proc_1',
          'command': 'python3 -m http.server',
          'cwd': '/repo',
          'osPid': 1234,
          'cpuPercent': 12.5,
          'rssKb': 2048,
        },
        {'processId': 'missing_item'},
      ],
      'nextCursor': 'cursor_2',
    });

    expect(page.terminals, hasLength(1));
    expect(page.terminals.single.itemId, 'item_1');
    expect(page.terminals.single.processId, 'proc_1');
    expect(page.terminals.single.command, 'python3 -m http.server');
    expect(page.terminals.single.cwd, '/repo');
    expect(page.terminals.single.osPid, 1234);
    expect(page.terminals.single.cpuPercent, 12.5);
    expect(page.terminals.single.rssKb, 2048);
    expect(page.nextCursor, 'cursor_2');
  });

  test('CodexThreadBackgroundTerminalRunner calls list and clean', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      if (request.method == 'thread/backgroundTerminals/list') {
        return {
          'data': [
            {
              'itemId': 'item_1',
              'processId': 'proc_1',
              'command': 'tail -f app.log',
              'cwd': '/repo',
              'osPid': null,
              'cpuPercent': null,
              'rssKb': null,
            },
          ],
          'nextCursor': null,
        };
      }
      return {};
    });
    final runner = CodexThreadBackgroundTerminalRunner(
      CodexAppServerClient(transport),
    );

    final page = await runner.listTerminals(
      threadId: 'thr_1',
      cursor: 'cursor_1',
      limit: 10,
    );
    await runner.cleanTerminals(threadId: 'thr_1');

    expect(page.terminals.single.command, 'tail -f app.log');
    expect(requests[0].method, 'thread/backgroundTerminals/list');
    expect(requests[0].params, {
      'threadId': 'thr_1',
      'cursor': 'cursor_1',
      'limit': 10,
    });
    expect(requests[1].method, 'thread/backgroundTerminals/clean');
    expect(requests[1].params, {'threadId': 'thr_1'});
  });
}
