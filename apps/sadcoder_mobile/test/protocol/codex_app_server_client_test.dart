import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/events/guardian_assessment_event.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/threads/side_conversation.dart';
import 'package:sadcoder_mobile/src/turns/turn_text_element.dart';

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
    await client.listModels(
      cursor: ' model_cursor ',
      limit: 25,
      includeHidden: true,
    );
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
    await client.listThreadTurns(
      threadId: 'thr_1',
      cursor: ' turn_cursor ',
      limit: 10,
      sortDirection: 'desc',
      itemsView: 'summary',
    );
    await client.listThreadItems(
      threadId: 'thr_1',
      turnId: ' turn_1 ',
      cursor: ' item_cursor ',
      limit: 50,
      sortDirection: 'asc',
    );
    await client.startThread();
    await client.resumeThread(threadId: 'thr_1');
    await client.forkThread(
      threadId: 'thr_1',
      lastTurnId: 'turn_1',
      ephemeral: true,
    );
    await client.compactThread(threadId: 'thr_1');
    await client.updateThreadSettings(
      threadId: 'thr_1',
      overrides: CodexConfigOverrides(
        model: 'gpt-5-codex',
        effort: 'high',
        summary: 'detailed',
        approvalPolicy: 'on-request',
        permissionProfile: ':workspace',
        cwd: '/repo',
        personality: 'pragmatic',
        serviceTier: 'flex',
      ),
    );
    await client.listSkills(cwds: [' /repo ', '  '], forceReload: true);
    await client.listPlugins(
      cwds: [' /repo ', '  '],
      marketplaceKinds: ['local', 'workspace-directory'],
    );
    await client.readPlugin(pluginId: ' linear ', cwds: [' /repo ', '  ']);
    await client.listHooks(cwds: [' /repo ', '  ']);
    await client.listApps(
      cursor: ' apps_cursor ',
      limit: 25,
      threadId: ' thr_1 ',
      forceRefetch: true,
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
    await client.unarchiveThread(threadId: 'thr_1');
    await client.deleteThread(threadId: 'thr_1');
    await client.logoutAccount();
    await client.uploadFeedback(
      classification: 'bug',
      reason: ' broken ',
      threadId: ' thr_1 ',
      turnId: ' turn_1 ',
      includeLogs: true,
    );
    await client.execCommand(
      command: ['git', 'diff'],
      cwd: ' /repo ',
      env: {' GIT_CONFIG_COUNT ': '0', '': 'ignored'},
      timeoutMs: 30000,
      outputBytesCap: 1024,
    );
    await client.searchFiles(
      query: 'main',
      roots: [' /repo ', '  '],
      cancellationToken: ' token-1 ',
    );
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
      'thread/turns/list',
      'thread/items/list',
      'thread/start',
      'thread/resume',
      'thread/fork',
      'thread/compact/start',
      'thread/settings/update',
      'skills/list',
      'plugin/list',
      'plugin/read',
      'hooks/list',
      'app/list',
      'thread/goal/get',
      'thread/goal/set',
      'thread/goal/clear',
      'review/start',
      'thread/name/set',
      'thread/archive',
      'thread/unarchive',
      'thread/delete',
      'account/logout',
      'feedback/upload',
      'command/exec',
      'fuzzyFileSearch',
      'turn/start',
      'turn/interrupt',
    ]);
    expect(requests.first.params, {
      'cursor': 'model_cursor',
      'limit': 25,
      'includeHidden': true,
    });
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
    expect(requests[9].params, {
      'threadId': 'thr_1',
      'cursor': 'turn_cursor',
      'limit': 10,
      'sortDirection': 'desc',
      'itemsView': 'summary',
    });
    expect(requests[10].params, {
      'threadId': 'thr_1',
      'turnId': 'turn_1',
      'cursor': 'item_cursor',
      'limit': 50,
      'sortDirection': 'asc',
    });
    expect(requests[11].params, isEmpty);
    expect(requests[12].params, {'threadId': 'thr_1'});
    expect(requests[13].params, {
      'threadId': 'thr_1',
      'lastTurnId': 'turn_1',
      'ephemeral': true,
    });
    expect(requests[14].params, {'threadId': 'thr_1'});
    expect(requests[15].params, {
      'threadId': 'thr_1',
      'model': 'gpt-5-codex',
      'effort': 'high',
      'summary': 'detailed',
      'approvalPolicy': 'on-request',
      'permissions': ':workspace',
      'cwd': '/repo',
      'personality': 'pragmatic',
      'serviceTier': 'flex',
    });
    expect(requests[16].params, {
      'cwds': ['/repo'],
      'forceReload': true,
    });
    expect(requests[17].params, {
      'cwds': ['/repo'],
      'marketplaceKinds': ['local', 'workspace-directory'],
    });
    expect(requests[18].params, {
      'pluginId': 'linear',
      'cwds': ['/repo'],
    });
    expect(requests[19].params, {
      'cwds': ['/repo'],
    });
    expect(requests[20].params, {
      'cursor': 'apps_cursor',
      'limit': 25,
      'threadId': 'thr_1',
      'forceRefetch': true,
    });
    expect(requests[21].params, {'threadId': 'thr_1'});
    expect(requests[22].params, {
      'threadId': 'thr_1',
      'objective': 'Ship goal support',
      'status': 'active',
      'tokenBudget': 5000,
    });
    expect(requests[23].params, {'threadId': 'thr_1'});
    expect(requests[24].params, {
      'threadId': 'thr_1',
      'target': {'type': 'commit', 'sha': 'abc123', 'title': 'Polish colors'},
      'delivery': 'detached',
    });
    expect(requests[25].params, {
      'threadId': 'thr_1',
      'name': 'Renamed thread',
    });
    expect(requests[26].params, {'threadId': 'thr_1'});
    expect(requests[27].params, {'threadId': 'thr_1'});
    expect(requests[28].params, {'threadId': 'thr_1'});
    expect(requests[29].params, isNull);
    expect(requests[30].params, {
      'classification': 'bug',
      'reason': 'broken',
      'threadId': 'thr_1',
      'includeLogs': true,
      'tags': {'turn_id': 'turn_1'},
    });
    expect(requests[31].params, {
      'command': ['git', 'diff'],
      'cwd': '/repo',
      'env': {'GIT_CONFIG_COUNT': '0'},
      'timeoutMs': 30000,
      'outputBytesCap': 1024,
    });
    expect(requests[32].params, {
      'query': 'main',
      'roots': ['/repo'],
      'cancellation_token': 'token-1',
    });
    expect(requests[33].params, {
      'threadId': 'thr_1',
      'input': [
        {'type': 'text', 'text': 'Fix bug', 'text_elements': <Object?>[]},
      ],
    });
    expect(requests.last.params, {'threadId': 'thr_1', 'turnId': 'turn_1'});
  });

  test('updateThreadSettings uses thread/settings/update', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });

    final client = CodexAppServerClient(transport);
    await client.updateThreadSettings(
      threadId: 'thr_1',
      overrides: CodexConfigOverrides(
        model: 'gpt-5.4',
        effort: 'low',
        summary: 'auto',
        approvalPolicy: 'never',
        permissionProfile: ':workspace',
        cwd: '/repo',
        personality: 'concise',
        serviceTier: 'priority',
      ),
    );

    expect(requests.single.method, 'thread/settings/update');
    expect(requests.single.params, {
      'threadId': 'thr_1',
      'model': 'gpt-5.4',
      'effort': 'low',
      'summary': 'auto',
      'approvalPolicy': 'never',
      'permissions': ':workspace',
      'cwd': '/repo',
      'personality': 'concise',
      'serviceTier': 'priority',
    });
  });

  test(
    'updateThreadSettings preserves explicit null service tier clears',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {};
      });

      final client = CodexAppServerClient(transport);
      await client.updateThreadSettings(
        threadId: 'thr_1',
        overrides: const CodexConfigOverrides(
          model: 'gpt-5.4',
          cwd: '',
          serviceTier: '',
        ),
      );

      expect(requests.single.method, 'thread/settings/update');
      expect(requests.single.params, {
        'threadId': 'thr_1',
        'model': 'gpt-5.4',
        'serviceTier': null,
      });
    },
  );

  test('runThreadShellCommand calls thread/shellCommand', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });

    final client = CodexAppServerClient(transport);
    await client.runThreadShellCommand(threadId: 'thr_1', command: 'echo hi');

    expect(requests.single.method, 'thread/shellCommand');
    expect(requests.single.params, {'threadId': 'thr_1', 'command': 'echo hi'});
  });

  test('reloadMcpServers uses app-server method name', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });

    final client = CodexAppServerClient(transport);
    await client.reloadMcpServers();

    expect(requests.single.method, 'config/mcpServer/reload');
    expect(requests.single.params, isNull);
  });

  test('listThreads can request archived threads', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });

    final client = CodexAppServerClient(transport);
    await client.listThreads(limit: 5);
    await client.listThreads(limit: 10, archived: true);

    expect(requests.map((request) => request.method), [
      'thread/list',
      'thread/list',
    ]);
    expect(requests.map((request) => request.params), [
      {'limit': 5},
      {'limit': 10, 'archived': true},
    ]);
  });

  test('startMcpServerOAuthLogin uses app-server method name', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });

    final client = CodexAppServerClient(transport);
    await client.startMcpServerOAuthLogin(serverName: ' github ');

    expect(requests.single.method, 'mcpServer/oauth/login');
    expect(requests.single.params, {'serverName': 'github'});
  });

  test('plugin mutation methods use app-server method names', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });

    final client = CodexAppServerClient(transport);
    await client.installPlugin(pluginId: ' linear ', cwds: [' /repo ', ' ']);
    await client.uninstallPlugin(pluginId: ' linear ', cwds: [' /repo ', ' ']);

    expect(requests.map((request) => request.method), [
      'plugin/install',
      'plugin/uninstall',
    ]);
    expect(requests.map((request) => request.params), [
      {
        'pluginId': 'linear',
        'cwds': ['/repo'],
      },
      {
        'pluginId': 'linear',
        'cwds': ['/repo'],
      },
    ]);
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
      await client.startTurn(
        threadId: 'thr_1',
        text: '@lib/main.dart explain',
        textElements: const [TurnTextElement(start: 0, end: 14)],
      );

      expect(requests.first.params!.keys, ['threadId', 'input']);
      expect(requests[1].params, {
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
      expect(requests.last.params, {
        'threadId': 'thr_1',
        'input': [
          {
            'type': 'text',
            'text': '@lib/main.dart explain',
            'text_elements': [
              {
                'byte_range': {'start': 0, 'end': 14},
              },
            ],
          },
        ],
      });
    },
  );

  test('filesystem methods use app-server request names', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });

    final client = CodexAppServerClient(transport);
    await client.fsReadDirectory(path: ' /repo/lib ');
    await client.fsGetMetadata(path: ' /repo/lib/main.dart ');
    await client.fsReadFile(
      path: ' /repo/lib/main.dart ',
      offset: 1024,
      limitBytes: 4096,
      encoding: ' utf-8 ',
    );
    await client.workspaceDirectoryList(
      root: ' /repo ',
      path: ' lib ',
      limit: 25,
      cursor: ' cursor_1 ',
      includeHidden: true,
    );
    await client.workspaceFileStat(root: ' /repo ', path: ' lib/main.dart ');
    await client.workspaceFileRead(
      root: ' /repo ',
      path: ' lib/main.dart ',
      offset: 1024,
      limitBytes: 4096,
      encoding: ' utf-8 ',
    );

    expect(requests.map((request) => request.method), [
      'fs/readDirectory',
      'fs/getMetadata',
      'fs/readFile',
      'workspace/directoryList',
      'workspace/fileStat',
      'workspace/fileRead',
    ]);
    expect(requests.map((request) => request.params), [
      {'path': '/repo/lib'},
      {'path': '/repo/lib/main.dart'},
      {
        'path': '/repo/lib/main.dart',
        'offset': 1024,
        'limitBytes': 4096,
        'encoding': 'utf-8',
      },
      {
        'root': '/repo',
        'path': 'lib',
        'limit': 25,
        'cursor': 'cursor_1',
        'includeHidden': true,
      },
      {'root': '/repo', 'path': 'lib/main.dart'},
      {
        'root': '/repo',
        'path': 'lib/main.dart',
        'offset': 1024,
        'limitBytes': 4096,
        'encoding': 'utf-8',
      },
    ]);
  });

  test('agent methods use sadcoder agent request names', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });

    final client = CodexAppServerClient(transport);
    await client.agentHello();
    await client.agentHealth();
    await client.agentSnapshot();
    await client.agentSlashCommandsList();
    await client.agentRestartBackend();
    await client.agentPing();

    expect(requests.map((request) => request.method), [
      'agent/hello',
      'agent/health',
      'agent/snapshot',
      'agent/slashCommands/list',
      'agent/restartBackend',
      'agent/ping',
    ]);
    expect(requests.map((request) => request.params), [
      null,
      null,
      null,
      null,
      null,
      null,
    ]);
  });

  test(
    'forkThread sends side conversation fork options when provided',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {};
      });

      final client = CodexAppServerClient(transport);
      await client.forkThread(
        threadId: 'thr_parent',
        ephemeral: true,
        developerInstructions: '  side instructions  ',
      );

      expect(requests.single.method, 'thread/fork');
      expect(requests.single.params, {
        'threadId': 'thr_parent',
        'developerInstructions': 'side instructions',
        'ephemeral': true,
      });
    },
  );

  test('injectThreadItems sends thread injection request', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });
    final item = SideConversationPrompts.boundaryPromptItem();

    final client = CodexAppServerClient(transport);
    await client.injectThreadItems(threadId: 'thr_side', items: [item]);

    expect(requests.single.method, 'thread/inject_items');
    expect(requests.single.params, {
      'threadId': 'thr_side',
      'items': [item],
    });
  });

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

  test('approveGuardianDeniedAction sends serialized guardian event', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });
    final client = CodexAppServerClient(transport);
    const event = GuardianAssessmentEvent(
      id: 'review_1',
      threadId: 'thr_1',
      turnId: 'turn_1',
      targetItemId: 'item_1',
      startedAtMs: 1000,
      completedAtMs: 1042,
      status: 'denied',
      riskLevel: 'high',
      userAuthorization: 'low',
      rationale: 'too risky',
      decisionSource: 'agent',
      action: {
        'type': 'command',
        'source': 'shell',
        'command': 'rm -rf /tmp/test',
        'cwd': '/repo',
      },
    );

    await client.approveGuardianDeniedAction(threadId: 'thr_1', event: event);

    expect(requests.single.method, 'thread/approveGuardianDeniedAction');
    expect(requests.single.params, {
      'threadId': 'thr_1',
      'event': {
        'id': 'review_1',
        'target_item_id': 'item_1',
        'turn_id': 'turn_1',
        'started_at_ms': 1000,
        'completed_at_ms': 1042,
        'status': 'denied',
        'risk_level': 'high',
        'user_authorization': 'low',
        'rationale': 'too risky',
        'decision_source': 'agent',
        'action': {
          'type': 'command',
          'source': 'shell',
          'command': 'rm -rf /tmp/test',
          'cwd': '/repo',
        },
      },
    });
  });
}
