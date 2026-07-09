import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
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
    await client.readThread(threadId: 'thr_1');
    await client.startThread();
    await client.resumeThread(threadId: 'thr_1');
    await client.startTurn(threadId: 'thr_1', text: 'Fix bug');
    await client.interruptTurn(threadId: 'thr_1', turnId: 'turn_1');

    expect(requests.map((request) => request.method), [
      'model/list',
      'thread/list',
      'thread/read',
      'thread/start',
      'thread/resume',
      'turn/start',
      'turn/interrupt',
    ]);
    expect(requests.first.params, isEmpty);
    expect(requests[1].params?['limit'], 5);
    expect(requests[2].params, {'threadId': 'thr_1', 'includeTurns': true});
    expect(requests[3].params, isEmpty);
    expect(requests[4].params, {'threadId': 'thr_1'});
    expect(requests[5].params, {
      'threadId': 'thr_1',
      'input': [
        {'type': 'text', 'text': 'Fix bug', 'text_elements': <Object?>[]},
      ],
    });
    expect(requests.last.params, {'threadId': 'thr_1', 'turnId': 'turn_1'});
  });

  test(
    'startTurn omits unset overrides and sends explicit overrides',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {};
      });

      final client = CodexAppServerClient(transport);
      await client.startTurn(threadId: 'thr_1', text: 'Use server defaults');
      await client.startTurn(
        threadId: 'thr_1',
        text: 'Override this turn',
        overrides: const CodexConfigOverrides(
          model: 'gpt-5-codex',
          effort: 'high',
          summary: 'detailed',
          approvalPolicy: 'on-request',
          cwd: '/repo',
          personality: 'pragmatic',
          sandboxPolicy: {'type': 'readOnly', 'networkAccess': false},
        ),
      );

      expect(requests.first.params!.keys, ['threadId', 'input']);
      expect(requests.last.params, {
        'threadId': 'thr_1',
        'input': [
          {
            'type': 'text',
            'text': 'Override this turn',
            'text_elements': <Object?>[],
          },
        ],
        'model': 'gpt-5-codex',
        'effort': 'high',
        'summary': 'detailed',
        'approvalPolicy': 'on-request',
        'sandboxPolicy': {'type': 'readOnly', 'networkAccess': false},
        'cwd': '/repo',
        'personality': 'pragmatic',
      });
    },
  );
}
