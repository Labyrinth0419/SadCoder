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
    expect(requests.single.params?['clientInfo'], {
      'name': 'sadcoder-mobile',
      'version': '1.0.0',
    });
    expect(requests.single.params?['capabilities'], {'experimentalApi': true});
    expect(notifications.single['method'], 'initialized');

    await subscription.cancel();
  });

  test('initialize accepts explicit client info', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });

    final client = CodexAppServerClient(transport);
    await client.initialize(
      clientName: 'custom-client',
      clientVersion: '2.3.4',
      experimentalApi: false,
    );

    expect(requests.single.method, 'initialize');
    expect(requests.single.params?['clientInfo'], {
      'name': 'custom-client',
      'version': '2.3.4',
    });
    expect(requests.single.params?['capabilities'], {'experimentalApi': false});
  });

  test('requestRaw forwards unknown app-server methods', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'ok': true, 'echoMethod': request.method};
    });

    final client = CodexAppServerClient(transport);
    final result = await client.requestRaw(
      method: ' experimental/newMethod ',
      params: {'threadId': 'thr_1', 'feature': 'future-schema'},
    );

    expect(result, {'ok': true, 'echoMethod': 'experimental/newMethod'});
    expect(requests.single.method, 'experimental/newMethod');
    expect(requests.single.params, {
      'threadId': 'thr_1',
      'feature': 'future-schema',
    });
  });

  test('requestRaw rejects blank method names', () async {
    final transport = MemoryJsonRpcTransport((_) => {});
    final client = CodexAppServerClient(transport);

    expect(
      () => client.requestRaw(method: '  '),
      throwsA(isA<ArgumentError>()),
    );
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
    await client.readPlugin(
      pluginName: ' plugins~linear ',
      remoteMarketplaceName: ' openai-curated-remote ',
    );
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
    await client.steerTurn(
      threadId: 'thr_1',
      turnId: 'turn_1',
      text: 'Adjust plan',
    );
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
      'turn/steer',
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
      'remoteMarketplaceName': 'openai-curated-remote',
      'pluginName': 'plugins~linear',
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
    expect(requests[34].params, {
      'threadId': 'thr_1',
      'expectedTurnId': 'turn_1',
      'input': [
        {'type': 'text', 'text': 'Adjust plan', 'text_elements': <Object?>[]},
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

  test(
    'updateThreadSettings omits ordinary blank fields during clears',
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
          model: '',
          effort: '',
          cwd: '',
          personality: '',
          serviceTier: '',
        ),
      );

      expect(requests.single.method, 'thread/settings/update');
      expect(requests.single.params, {
        'threadId': 'thr_1',
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

  test('readConfigRequirements uses parameterless app-server method', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'requirements': null};
    });

    final client = CodexAppServerClient(transport);
    await client.readConfigRequirements();

    expect(requests.single.method, 'configRequirements/read');
    expect(requests.single.params, isNull);
  });

  test('readModelProviderCapabilities uses official empty params', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'namespaceTools': true,
        'imageGeneration': false,
        'webSearch': true,
      };
    });
    addTearDown(transport.close);

    final client = CodexAppServerClient(transport);
    await client.readModelProviderCapabilities();

    expect(requests.single.method, 'modelProvider/capabilities/read');
    expect(requests.single.params, isEmpty);
  });

  test('writeSkillConfig uses exactly one normalized selector', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'effectiveEnabled': request.params?['enabled']};
    });
    addTearDown(transport.close);

    final client = CodexAppServerClient(transport);
    await client.writeSkillConfig(path: ' /skill/SKILL.md ', enabled: false);
    await client.writeSkillConfig(name: ' review ', enabled: true);

    expect(requests.map((request) => request.method), [
      'skills/config/write',
      'skills/config/write',
    ]);
    expect(requests[0].params, {'path': '/skill/SKILL.md', 'enabled': false});
    expect(requests[1].params, {'name': 'review', 'enabled': true});
    expect(
      () => client.writeSkillConfig(enabled: true),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => client.writeSkillConfig(
        path: '/skill/SKILL.md',
        name: 'review',
        enabled: true,
      ),
      throwsA(isA<ArgumentError>()),
    );
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
    await client.installPlugin(
      pluginName: ' linear ',
      marketplacePath: ' /repo/.agents/plugins/marketplace.json ',
    );
    await client.uninstallPlugin(pluginId: ' linear@team-tools ');

    expect(requests.map((request) => request.method), [
      'plugin/install',
      'plugin/uninstall',
    ]);
    expect(requests.map((request) => request.params), [
      {
        'marketplacePath': '/repo/.agents/plugins/marketplace.json',
        'pluginName': 'linear',
      },
      {'pluginId': 'linear@team-tools'},
    ]);
  });

  test('plugin read and install require exactly one catalog source', () {
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) => const <String, Object?>{}),
    );

    expect(() => client.readPlugin(pluginName: 'linear'), throwsArgumentError);
    expect(
      () => client.readPlugin(
        pluginName: 'linear',
        marketplacePath: '/local/marketplace.json',
        remoteMarketplaceName: 'remote',
      ),
      throwsArgumentError,
    );
    expect(
      () => client.installPlugin(
        pluginName: ' ',
        marketplacePath: '/local/marketplace.json',
      ),
      throwsArgumentError,
    );
    expect(
      () => client.installPlugin(
        pluginName: 'linear',
        remoteMarketplaceName: ' ',
      ),
      throwsArgumentError,
    );
  });

  test('readPluginSkill uses stable remote catalog parameters', () async {
    final requests = <JsonRpcRequest>[];
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {'contents': '# Review'};
      }),
    );

    final result = await client.readPluginSkill(
      remoteMarketplaceName: ' openai-curated-remote ',
      remotePluginId: ' plugins~reviewer ',
      skillName: ' review ',
    );

    expect(result['contents'], '# Review');
    expect(requests.single.method, 'plugin/skill/read');
    expect(requests.single.params, {
      'remoteMarketplaceName': 'openai-curated-remote',
      'remotePluginId': 'plugins~reviewer',
      'skillName': 'review',
    });
  });

  test('thread and turn start omit unset overrides', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });

    final client = CodexAppServerClient(transport);
    await client.startThread();
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

    const overrideKeys = {
      'model',
      'effort',
      'summary',
      'approvalPolicy',
      'permissions',
      'cwd',
      'personality',
      'serviceTier',
      'sandboxPolicy',
    };
    expect(requests[0].method, 'thread/start');
    expect(requests[0].params, isEmpty);
    expect(requests[1].method, 'turn/start');
    expect(requests[1].params, {
      'threadId': 'thr_1',
      'input': [
        {
          'type': 'text',
          'text': 'Use server defaults',
          'text_elements': <Object?>[],
        },
      ],
    });
    expect(
      requests[1].params!.keys.toSet().intersection(overrideKeys),
      isEmpty,
    );
    expect(requests[2].params, {
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
  });

  test('turn steer sends expected turn id and text elements', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'turnId': 'turn_1'};
    });

    final client = CodexAppServerClient(transport);
    await client.steerTurn(
      threadId: 'thr_1',
      turnId: 'turn_1',
      text: '@lib/main.dart refine',
      textElements: const [TurnTextElement(start: 0, end: 14)],
    );

    expect(requests.single.method, 'turn/steer');
    expect(requests.single.params, {
      'threadId': 'thr_1',
      'expectedTurnId': 'turn_1',
      'input': [
        {
          'type': 'text',
          'text': '@lib/main.dart refine',
          'text_elements': [
            {
              'byte_range': {'start': 0, 'end': 14},
            },
          ],
        },
      ],
    });
  });

  test(
    'ordinary thread and turn overrides never write server config values',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {};
      });

      final client = CodexAppServerClient(transport);
      await client.startTurn(
        threadId: 'thr_1',
        text: 'Use a one-turn override',
        overrides: const CodexConfigOverrides(
          model: 'gpt-5-codex',
          effort: 'high',
          cwd: '/repo',
        ),
      );
      await client.updateThreadSettings(
        threadId: 'thr_1',
        overrides: const CodexConfigOverrides(
          model: 'gpt-5-codex',
          personality: 'concise',
          serviceTier: 'priority',
        ),
      );

      final methods = requests.map((request) => request.method).toList();
      expect(methods, ['turn/start', 'thread/settings/update']);
      expect(methods, isNot(contains('config/value/write')));
      expect(methods, isNot(contains('config/batchWrite')));
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
    await client.agentLogs(tailBytes: 8192);
    await client.agentSchema();
    await client.agentSchema(refresh: true, experimental: true);
    await client.agentSnapshot();
    await client.agentSnapshot(sinceCursor: ' event-7 ');
    await client.agentSlashCommandsList();
    await client.agentRestartBackend();
    await client.agentStopBackend();
    await client.agentPing();

    expect(requests.map((request) => request.method), [
      'agent/hello',
      'agent/health',
      'agent/logs',
      'agent/schema',
      'agent/schema',
      'agent/snapshot',
      'agent/snapshot',
      'agent/slashCommands/list',
      'agent/restartBackend',
      'agent/stopBackend',
      'agent/ping',
    ]);
    expect(requests.map((request) => request.params), [
      null,
      null,
      {'tailBytes': 8192},
      null,
      {'refresh': true, 'experimental': true},
      null,
      {'sinceCursor': 'event-7'},
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

  test(
    'experimental feature and config mutation methods use wire shapes',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {};
      });
      final client = CodexAppServerClient(transport);

      await client.listExperimentalFeatures(
        cursor: ' cursor-1 ',
        limit: 20,
        threadId: ' thread-1 ',
      );
      await client.batchWriteConfig(
        edits: const [
          {
            'keyPath': 'features.network_proxy',
            'value': true,
            'mergeStrategy': 'upsert',
          },
        ],
        expectedVersion: ' v1 ',
        reloadUserConfig: true,
      );

      expect(requests.map((request) => request.method), [
        'experimentalFeature/list',
        'config/batchWrite',
      ]);
      expect(requests.first.params, {
        'cursor': 'cursor-1',
        'limit': 20,
        'threadId': 'thread-1',
      });
      expect(requests.last.params, {
        'edits': const [
          {
            'keyPath': 'features.network_proxy',
            'value': true,
            'mergeStrategy': 'upsert',
          },
        ],
        'expectedVersion': 'v1',
        'reloadUserConfig': true,
      });
    },
  );

  test(
    'collaboration mode catalog uses the official empty params shape',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {'data': const <Object?>[]};
      });
      addTearDown(transport.close);
      final client = CodexAppServerClient(transport);

      await client.listCollaborationModes();

      expect(requests.single.method, 'collaborationMode/list');
      expect(requests.single.params, isEmpty);
    },
  );

  test(
    'remote environment methods normalize parameters and wire names',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {};
      });
      final client = CodexAppServerClient(transport);

      await client.addEnvironment(
        environmentId: ' env-1 ',
        execServerUrl: ' ws://exec.example/ws ',
        connectTimeoutMs: 5000,
      );
      await client.readEnvironmentInfo(environmentId: ' env-1 ');
      await client.readEnvironmentStatus(environmentId: ' env-1 ');

      expect(requests.map((request) => request.method), [
        'environment/add',
        'environment/info',
        'environment/status',
      ]);
      expect(requests[0].params, {
        'environmentId': 'env-1',
        'execServerUrl': 'ws://exec.example/ws',
        'connectTimeoutMs': 5000,
      });
      expect(requests[1].params, {'environmentId': 'env-1'});
      expect(requests[2].params, {'environmentId': 'env-1'});
    },
  );

  test('remote environment methods reject blank identifiers', () async {
    final client = CodexAppServerClient(MemoryJsonRpcTransport((_) => {}));

    expect(
      () => client.addEnvironment(
        environmentId: ' ',
        execServerUrl: 'ws://exec.example/ws',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => client.readEnvironmentInfo(environmentId: ' '),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => client.readEnvironmentStatus(environmentId: ' '),
      throwsA(isA<ArgumentError>()),
    );
  });

  test(
    'filesystem mutation methods use structured v2 names and params',
    () async {
      final requests = <JsonRpcRequest>[];
      final client = CodexAppServerClient(
        MemoryJsonRpcTransport((request) {
          requests.add(request);
          return {};
        }),
      );

      await client.fsCreateDirectory(path: ' /repo/new ', recursive: false);
      await client.fsRemove(path: ' /repo/old ', recursive: true, force: false);
      await client.fsCopy(
        sourcePath: ' /repo/a ',
        destinationPath: ' /repo/b ',
        recursive: true,
      );

      expect(requests.map((request) => request.method), [
        'fs/createDirectory',
        'fs/remove',
        'fs/copy',
      ]);
      expect(requests[0].params, {'path': '/repo/new', 'recursive': false});
      expect(requests[1].params, {
        'path': '/repo/old',
        'recursive': true,
        'force': false,
      });
      expect(requests[2].params, {
        'sourcePath': '/repo/a',
        'destinationPath': '/repo/b',
        'recursive': true,
      });
    },
  );
}
