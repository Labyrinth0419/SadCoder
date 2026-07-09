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
    await client.listPermissionProfiles(cwd: '/repo', cursor: '2', limit: 25);
    await client.readAccount();
    await client.listThreads(limit: 5);
    await client.readConfig(cwd: '/repo');
    await client.readThread(threadId: 'thr_1');
    await client.startThread();
    await client.resumeThread(threadId: 'thr_1');
    await client.setThreadName(threadId: 'thr_1', name: 'Renamed thread');
    await client.archiveThread(threadId: 'thr_1');
    await client.deleteThread(threadId: 'thr_1');
    await client.startTurn(threadId: 'thr_1', text: 'Fix bug');
    await client.interruptTurn(threadId: 'thr_1', turnId: 'turn_1');

    expect(requests.map((request) => request.method), [
      'model/list',
      'permissionProfile/list',
      'account/read',
      'thread/list',
      'config/read',
      'thread/read',
      'thread/start',
      'thread/resume',
      'thread/name/set',
      'thread/archive',
      'thread/delete',
      'turn/start',
      'turn/interrupt',
    ]);
    expect(requests.first.params, isEmpty);
    expect(requests[1].params, {'cursor': '2', 'limit': 25, 'cwd': '/repo'});
    expect(requests[2].params, {'refreshToken': false});
    expect(requests[3].params?['limit'], 5);
    expect(requests[4].params, {'includeLayers': true, 'cwd': '/repo'});
    expect(requests[5].params, {'threadId': 'thr_1', 'includeTurns': true});
    expect(requests[6].params, isEmpty);
    expect(requests[7].params, {'threadId': 'thr_1'});
    expect(requests[8].params, {'threadId': 'thr_1', 'name': 'Renamed thread'});
    expect(requests[9].params, {'threadId': 'thr_1'});
    expect(requests[10].params, {'threadId': 'thr_1'});
    expect(requests[11].params, {
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
          permissionProfile: ':workspace',
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
        'permissions': ':workspace',
        'cwd': '/repo',
        'personality': 'pragmatic',
      });
    },
  );
}
