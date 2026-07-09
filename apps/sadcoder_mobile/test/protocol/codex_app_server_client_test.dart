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
    await client.listMcpServerStatus(
      threadId: 'thr_1',
      detail: 'toolsAndAuthOnly',
      limit: 25,
      cursor: 'mcp_cursor',
    );
    await client.readAccount();
    await client.readAccountRateLimits();
    await client.readAccountUsage();
    await client.listThreads(limit: 5);
    await client.readConfig(cwd: '/repo');
    await client.readThread(threadId: 'thr_1');
    await client.startThread();
    await client.resumeThread(threadId: 'thr_1');
    await client.forkThread(
      threadId: 'thr_1',
      lastTurnId: 'turn_1',
      ephemeral: true,
    );
    await client.compactThread(threadId: 'thr_1');
    await client.listSkills(cwds: [' /repo ', '  '], forceReload: true);
    await client.listPlugins(
      cwds: [' /repo ', '  '],
      marketplaceKinds: ['local', 'workspace-directory'],
    );
    await client.getThreadGoal(threadId: 'thr_1');
    await client.setThreadGoal(
      threadId: 'thr_1',
      objective: 'Ship goal support',
      status: 'active',
      tokenBudget: 5000,
    );
    await client.clearThreadGoal(threadId: 'thr_1');
    await client.startReview(
      threadId: 'thr_1',
      target: {'type': 'commit', 'sha': 'abc123', 'title': 'Polish colors'},
      delivery: 'detached',
    );
    await client.setThreadName(threadId: 'thr_1', name: 'Renamed thread');
    await client.archiveThread(threadId: 'thr_1');
    await client.deleteThread(threadId: 'thr_1');
    await client.startTurn(threadId: 'thr_1', text: 'Fix bug');
    await client.interruptTurn(threadId: 'thr_1', turnId: 'turn_1');

    expect(requests.map((request) => request.method), [
      'model/list',
      'permissionProfile/list',
      'mcpServerStatus/list',
      'account/read',
      'account/rateLimits/read',
      'account/usage/read',
      'thread/list',
      'config/read',
      'thread/read',
      'thread/start',
      'thread/resume',
      'thread/fork',
      'thread/compact/start',
      'skills/list',
      'plugin/list',
      'thread/goal/get',
      'thread/goal/set',
      'thread/goal/clear',
      'review/start',
      'thread/name/set',
      'thread/archive',
      'thread/delete',
      'turn/start',
      'turn/interrupt',
    ]);
    expect(requests.first.params, isEmpty);
    expect(requests[1].params, {'cursor': '2', 'limit': 25, 'cwd': '/repo'});
    expect(requests[2].params, {
      'threadId': 'thr_1',
      'cursor': 'mcp_cursor',
      'limit': 25,
      'detail': 'toolsAndAuthOnly',
    });
    expect(requests[3].params, {'refreshToken': false});
    expect(requests[4].params, isNull);
    expect(requests[5].params, isNull);
    expect(requests[6].params?['limit'], 5);
    expect(requests[7].params, {'includeLayers': true, 'cwd': '/repo'});
    expect(requests[8].params, {'threadId': 'thr_1', 'includeTurns': true});
    expect(requests[9].params, isEmpty);
    expect(requests[10].params, {'threadId': 'thr_1'});
    expect(requests[11].params, {
      'threadId': 'thr_1',
      'lastTurnId': 'turn_1',
      'ephemeral': true,
    });
    expect(requests[12].params, {'threadId': 'thr_1'});
    expect(requests[13].params, {
      'cwds': ['/repo'],
      'forceReload': true,
    });
    expect(requests[14].params, {
      'cwds': ['/repo'],
      'marketplaceKinds': ['local', 'workspace-directory'],
    });
    expect(requests[15].params, {'threadId': 'thr_1'});
    expect(requests[16].params, {
      'threadId': 'thr_1',
      'objective': 'Ship goal support',
      'status': 'active',
      'tokenBudget': 5000,
    });
    expect(requests[17].params, {'threadId': 'thr_1'});
    expect(requests[18].params, {
      'threadId': 'thr_1',
      'target': {'type': 'commit', 'sha': 'abc123', 'title': 'Polish colors'},
      'delivery': 'detached',
    });
    expect(requests[19].params, {
      'threadId': 'thr_1',
      'name': 'Renamed thread',
    });
    expect(requests[20].params, {'threadId': 'thr_1'});
    expect(requests[21].params, {'threadId': 'thr_1'});
    expect(requests[22].params, {
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

  test('background terminal methods use app-server method names', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return request.method == 'thread/backgroundTerminals/list'
          ? {'data': <Object?>[], 'nextCursor': null}
          : {};
    });
    final client = CodexAppServerClient(transport);

    await client.listThreadBackgroundTerminals(
      threadId: 'thr_1',
      cursor: 'cursor_1',
      limit: 25,
    );
    await client.cleanThreadBackgroundTerminals(threadId: 'thr_1');

    expect(requests.map((request) => request.method), [
      'thread/backgroundTerminals/list',
      'thread/backgroundTerminals/clean',
    ]);
    expect(requests[0].params, {
      'threadId': 'thr_1',
      'cursor': 'cursor_1',
      'limit': 25,
    });
    expect(requests[1].params, {'threadId': 'thr_1'});
  });
}
