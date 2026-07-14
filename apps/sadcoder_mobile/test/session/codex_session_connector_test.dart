import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/agent/agent_remote_service.dart';
import 'package:sadcoder_mobile/src/agent/agent_status.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/command_exec/command_exec_runner.dart';
import 'package:sadcoder_mobile/src/environments/environment_runner.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_list_reader.dart';
import 'package:sadcoder_mobile/src/realtime/realtime_runner.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_proxy_connector.dart';
import 'package:sadcoder_mobile/src/windows_sandbox/windows_sandbox_runner.dart';

void main() {
  test('connect initializes app-server and exposes session client', () async {
    final proxyConnector = _LineServerProxyConnector();
    final connector = CodexSessionConnector(proxyConnector: proxyConnector);

    final connection = await connector.connect(_profile);
    addTearDown(connection.close);
    final snapshotReader =
        (connection as AgentSnapshotConnectionHandle).agentSnapshotReader!;
    final snapshot = await snapshotReader.readSnapshot(_profile);
    await connection.modelListReader.listModels();
    await connection.permissionProfileListReader.listPermissionProfiles();
    await connection.skillListReader.listSkills();
    final skillMutationRunner =
        (connection as SkillMutationConnectionHandle).skillMutationRunner;
    await skillMutationRunner.setSkillEnabled(
      path: '/repo/.codex/skills/review/SKILL.md',
      enabled: false,
    );
    await connection.pluginListReader.listPlugins();
    final pluginTarget = PluginListPage.fromJson({
      'marketplaces': [
        {
          'name': 'openai-curated-remote',
          'plugins': [
            {
              'id': 'linear@openai-curated-remote',
              'remotePluginId': 'plugins~linear',
              'name': 'linear',
              'source': {'type': 'remote'},
            },
          ],
        },
      ],
    }).resolveTarget('linear');
    await connection.pluginDetailReader.readPlugin(target: pluginTarget);
    await connection.pluginMutationRunner.installPlugin(target: pluginTarget);
    await connection.pluginMutationRunner.uninstallPlugin(pluginId: 'linear');
    final marketplaceMutationRunner =
        (connection as MarketplaceMutationConnectionHandle)
            .marketplaceMutationRunner;
    await marketplaceMutationRunner.addMarketplace(
      source: 'https://example.com/team-tools.git',
      refName: 'main',
      sparsePaths: const ['plugins'],
    );
    await marketplaceMutationRunner.removeMarketplace(
      marketplaceName: 'team-tools',
    );
    await marketplaceMutationRunner.upgradeMarketplaces(
      marketplaceName: 'openai-curated',
    );
    final processRunner = (connection as ProcessConnectionHandle).processRunner;
    final processSession = await processRunner.start(
      const CommandExecRequest(
        command: ['echo', 'hello'],
        cwd: '/repo',
        size: CommandExecTerminalSize(rows: 24, cols: 80),
      ),
    );
    await processSession.write(utf8.encode('input\n'));
    await processSession.resize(
      const CommandExecTerminalSize(rows: 40, cols: 120),
    );
    await processSession.terminate();
    proxyConnector.emitNotification('process/exited', {
      'processHandle': processSession.processId,
      'exitCode': 0,
      'stdout': '',
      'stdoutCapReached': false,
      'stderr': '',
      'stderrCapReached': false,
    });
    expect((await processSession.done).exitCode, 0);
    await connection.hookListReader.listHooks();
    final hookMutationRunner =
        (connection as HookMutationConnectionHandle).hookMutationRunner;
    await hookMutationRunner.setHookEnabled(hookKey: 'hook-1', enabled: false);
    await hookMutationRunner.trustHook(
      hookKey: 'hook-1',
      currentHash: 'hash-1',
    );
    await connection.appListReader.listApps();
    await connection.mcpServerOAuthRunner.startOAuthLogin(serverName: 'github');
    await connection.accountSnapshotReader.readAccount();
    await connection.accountLogoutRunner.logout();
    await connection.feedbackUploadRunner.uploadFeedback(
      classification: 'bug',
      reason: 'Authorization: Bearer upload-secret path=/repo',
    );
    final windowsSandboxRunner =
        (connection as WindowsSandboxConnectionHandle).windowsSandboxRunner;
    expect(
      await windowsSandboxRunner.readReadiness(),
      WindowsSandboxReadiness.notConfigured,
    );
    expect(
      (await windowsSandboxRunner.startSetup(
        mode: WindowsSandboxSetupMode.elevated,
        cwd: r'C:\repo',
      )).started,
      isTrue,
    );
    final environmentRunner =
        (connection as EnvironmentConnectionHandle).environmentRunner;
    await environmentRunner.addEnvironment(
      environmentId: 'env-1',
      execServerUrl: 'ws://exec.example/ws',
    );
    final environmentInfo = await environmentRunner.readEnvironmentInfo(
      environmentId: 'env-1',
    );
    expect(environmentInfo.shell.name, 'bash');
    final environmentStatus = await environmentRunner.readEnvironmentStatus(
      environmentId: 'env-1',
    );
    expect(environmentStatus.status, EnvironmentStatusKind.ready);
    final externalAgentConfigRunner =
        (connection as ExternalAgentConfigConnectionHandle)
            .externalAgentConfigRunner;
    final migrationItems = await externalAgentConfigRunner.detect(
      cwds: ['/repo'],
    );
    await externalAgentConfigRunner.startImport(
      items: migrationItems.items,
      source: 'claude',
    );
    await externalAgentConfigRunner.readImportHistories();
    await connection.gitDiffReader.readDiff();
    await connection.fileSearchReader.searchFiles(
      query: 'main',
      roots: ['/repo'],
    );
    await connection.threadTurnListReader.listTurns(
      threadId: 'thr_1',
      limit: 5,
      itemsView: 'summary',
    );
    await connection.threadItemListReader.listItems(
      threadId: 'thr_1',
      turnId: 'turn_1',
      limit: 10,
    );
    final realtimeRunner =
        (connection as RealtimeConnectionHandle).realtimeRunner;
    await realtimeRunner.listVoices();
    await realtimeRunner.startText(threadId: 'thr_1');
    await realtimeRunner.appendText(threadId: 'thr_1', text: 'hello');
    await realtimeRunner.appendAudio(
      threadId: 'thr_1',
      audio: const RealtimeAudioFrame(
        data: 'AA==',
        sampleRate: 24000,
        numChannels: 1,
      ),
    );
    await realtimeRunner.appendSpeech(threadId: 'thr_1', text: 'hello');
    await realtimeRunner.stop(threadId: 'thr_1');
    await connection.turnRunner.startThread();
    await connection.turnRunner.startTurn(threadId: 'thr_1', text: 'Fix bug');
    await connection.turnRunner.steerTurn(
      threadId: 'thr_1',
      turnId: 'turn_1',
      text: 'Adjust plan',
    );
    await connection.turnRunner.interruptTurn(
      threadId: 'thr_1',
      turnId: 'turn_1',
    );

    expect(proxyConnector.methods, [
      'agent/hello',
      'initialize',
      'initialized',
      'agent/snapshot',
      'model/list',
      'permissionProfile/list',
      'skills/list',
      'skills/config/write',
      'plugin/list',
      'plugin/read',
      'plugin/install',
      'plugin/uninstall',
      'marketplace/add',
      'marketplace/remove',
      'marketplace/upgrade',
      'process/spawn',
      'process/writeStdin',
      'process/resizePty',
      'process/kill',
      'hooks/list',
      'config/batchWrite',
      'config/batchWrite',
      'app/list',
      'mcpServer/oauth/login',
      'account/read',
      'account/logout',
      'feedback/upload',
      'windowsSandbox/readiness',
      'windowsSandbox/setupStart',
      'environment/add',
      'environment/info',
      'environment/status',
      'externalAgentConfig/detect',
      'externalAgentConfig/import',
      'externalAgentConfig/import/readHistories',
      'command/exec',
      'fuzzyFileSearch',
      'thread/turns/list',
      'thread/items/list',
      'thread/realtime/listVoices',
      'thread/realtime/start',
      'thread/realtime/appendText',
      'thread/realtime/appendAudio',
      'thread/realtime/appendSpeech',
      'thread/realtime/stop',
      'thread/start',
      'turn/start',
      'turn/steer',
      'turn/interrupt',
    ]);
    final initializeRequest = proxyConnector.requests.singleWhere(
      (request) => request['method'] == 'initialize',
    );
    final initializeParams =
        initializeRequest['params'] as Map<String, Object?>;
    expect(initializeParams['clientInfo'], {
      'name': 'sadcoder-mobile',
      'version': '1.0.0',
    });
    expect(connection.profile, _profile);
    expect(snapshot.pendingApprovals.single.id, 'approval-proxy');
    final feedbackLog = connection.diagnosticLogs.lastWhere(
      (entry) => entry.redactedJson['method'] == 'feedback/upload',
    );
    final params = feedbackLog.redactedJson['params'] as Map<Object?, Object?>;
    expect(params['reason'], 'Authorization: Bearer [REDACTED] path=/repo');
    expect(params['reason'], isNot(contains('upload-secret')));
  });

  test(
    'close does not send turn interrupt and keeps external approvals',
    () async {
      final proxyConnector = _LineServerProxyConnector();
      final connector = CodexSessionConnector(proxyConnector: proxyConnector);
      final approvalController = ApprovalStateController(
        initialApprovals: const [
          PendingApproval(
            requestId: 'approval-1',
            method: commandExecutionApprovalMethod,
            kind: PendingApprovalKind.commandExecution,
            rawParams: {},
          ),
        ],
      );
      addTearDown(approvalController.dispose);

      final connection = await connector.connect(
        _profile,
        approvalController: approvalController,
      );
      await connection.close();

      expect(proxyConnector.closed, true);
      expect(proxyConnector.methods, [
        'agent/hello',
        'initialize',
        'initialized',
      ]);
      expect(proxyConnector.methods, isNot(contains('turn/interrupt')));
      expect(approvalController.approvals.single.requestId, 'approval-1');
      expect(approvalController.canRespond, false);
    },
  );

  test('failed initialize closes proxy without sending interrupt', () async {
    final proxyConnector = _LineServerProxyConnector(failMethod: 'initialize');
    final connector = CodexSessionConnector(proxyConnector: proxyConnector);

    await expectLater(connector.connect(_profile), throwsA(anything));

    expect(proxyConnector.closed, true);
    expect(proxyConnector.methods, ['agent/hello', 'initialize']);
    expect(proxyConnector.methods, isNot(contains('turn/interrupt')));
  });

  test('failed agent handshake closes proxy before initialize', () async {
    final proxyConnector = _LineServerProxyConnector(failMethod: 'agent/hello');
    final connector = CodexSessionConnector(proxyConnector: proxyConnector);

    await expectLater(connector.connect(_profile), throwsA(anything));

    expect(proxyConnector.closed, true);
    expect(proxyConnector.methods, ['agent/hello']);
    expect(proxyConnector.methods, isNot(contains('initialize')));
    expect(proxyConnector.methods, isNot(contains('turn/interrupt')));
  });

  test('connect starts a not-started backend before opening proxy', () async {
    final proxyConnector = _LineServerProxyConnector();
    final starter = _FakeStartRunner(_readyStatus);
    final connector = CodexSessionConnector(
      proxyConnector: proxyConnector,
      statusReader: const _FakeStatusReader(_notStartedStatus),
      startRunner: starter,
    );

    final connection = await connector.connect(_profile);
    addTearDown(connection.close);

    expect(starter.startedProfiles, [_profile]);
    expect(proxyConnector.connectCount, 1);
    expect(proxyConnector.methods, [
      'agent/hello',
      'initialize',
      'initialized',
    ]);
  });

  test('connect fails before proxy when backend is unavailable', () async {
    final proxyConnector = _LineServerProxyConnector();
    final connector = CodexSessionConnector(
      proxyConnector: proxyConnector,
      statusReader: const _FakeStatusReader(_unavailableStatus),
    );

    await expectLater(
      connector.connect(_profile),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Codex is unavailable: runtime-not-found: node 12'),
        ),
      ),
    );

    expect(proxyConnector.connectCount, 0);
    expect(proxyConnector.methods, isEmpty);
  });

  test('connect rejects ready backend when Codex is unavailable', () async {
    final proxyConnector = _LineServerProxyConnector();
    final connector = CodexSessionConnector(
      proxyConnector: proxyConnector,
      statusReader: const _FakeStatusReader(_unavailableReadyStatus),
    );

    await expectLater(
      connector.connect(_profile),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Codex is unavailable: configured-path-missing'),
        ),
      ),
    );

    expect(proxyConnector.connectCount, 0);
    expect(proxyConnector.methods, isEmpty);
  });
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

const _readyStatus = AgentStatus(
  agentVersion: '0.1.0',
  platformOs: 'linux',
  platformArch: 'x86_64',
  codexPath: 'codex',
  codexAvailable: true,
  backendKind: BackendKind.sadcoderAgentService,
  backendState: BackendState.ready,
  backendDetail: 'SadCoder service ready',
);

const _notStartedStatus = AgentStatus(
  agentVersion: '0.1.0',
  platformOs: 'linux',
  platformArch: 'x86_64',
  codexPath: 'codex',
  codexAvailable: true,
  backendKind: BackendKind.sadcoderAgentService,
  backendState: BackendState.notStarted,
  backendDetail: 'SadCoder service not started',
);

const _unavailableStatus = AgentStatus(
  agentVersion: '0.1.0',
  platformOs: 'linux',
  platformArch: 'x86_64',
  codexPath: 'codex',
  codexAvailable: false,
  codexFailure: AgentCodexFailure(kind: 'runtime-not-found', detail: 'node 12'),
  backendKind: BackendKind.unknown,
  backendState: BackendState.unavailable,
  backendDetail: 'codex missing',
);

const _unavailableReadyStatus = AgentStatus(
  agentVersion: '0.1.0',
  platformOs: 'linux',
  platformArch: 'x86_64',
  codexPath: '/missing/codex',
  codexAvailable: false,
  codexFailure: AgentCodexFailure(
    kind: 'configured-path-missing',
    detail: '/missing/codex does not exist',
  ),
  backendKind: BackendKind.codexAppServerStdio,
  backendState: BackendState.ready,
  backendDetail: 'legacy fallback status',
);

class _FakeStatusReader implements AgentStatusReader {
  const _FakeStatusReader(this.status);

  final AgentStatus status;

  @override
  Future<AgentStatus> readStatus(SshProfile profile) async => status;
}

class _FakeStartRunner implements AgentStartRunner {
  _FakeStartRunner(this.status);

  final AgentStatus status;
  final startedProfiles = <SshProfile>[];

  @override
  Future<AgentStatus> start(SshProfile profile) async {
    startedProfiles.add(profile);
    return status;
  }
}

class _LineServerProxyConnector implements AgentProxyConnector {
  _LineServerProxyConnector({this.failMethod});

  final String? failMethod;
  final requests = <Map<String, Object?>>[];
  final methods = <String>[];
  bool closed = false;
  int connectCount = 0;
  StreamController<Uint8List>? _input;

  @override
  Future<AgentProxyConnection> connect(SshProfile profile) async {
    connectCount++;
    final input = StreamController<Uint8List>();
    _input = input;
    final output = StreamController<Uint8List>();

    output.stream.listen((bytes) {
      for (final line in const LineSplitter().convert(utf8.decode(bytes))) {
        _handleLine(line, input);
      }
    });

    return AgentProxyConnection(
      input: input.stream,
      output: output.sink,
      close: () async {
        closed = true;
        if (!input.isClosed) {
          await input.close();
        }
        if (!output.isClosed) {
          await output.close();
        }
      },
    );
  }

  void emitNotification(String method, Map<String, Object?> params) {
    final input = _input;
    if (input == null || input.isClosed) {
      throw StateError('proxy is not connected');
    }
    input.add(
      Uint8List.fromList(
        utf8.encode(
          '${jsonEncode({'jsonrpc': '2.0', 'method': method, 'params': params})}\n',
        ),
      ),
    );
  }

  void _handleLine(String line, StreamController<Uint8List> input) {
    final request = Map<String, Object?>.from(jsonDecode(line) as Map);
    requests.add(request);
    final method = request['method'] as String;
    methods.add(method);

    final id = request['id'];
    if (id == null) {
      return;
    }

    final response = <String, Object?>{'jsonrpc': '2.0', 'id': id};
    if (method == failMethod) {
      response['error'] = {'code': -32000, 'message': 'failed'};
    } else {
      response['result'] = _resultFor(method);
    }
    input.add(Uint8List.fromList(utf8.encode('${jsonEncode(response)}\n')));
  }

  Map<String, Object?> _resultFor(String method) => switch (method) {
    'agent/hello' => {'agentVersion': '0.1.0'},
    'initialize' => {'serverInfo': 'test'},
    'model/list' => {'models': <Object?>[]},
    'permissionProfile/list' => {'data': <Object?>[]},
    'windowsSandbox/readiness' => {'status': 'notConfigured'},
    'windowsSandbox/setupStart' => {'started': true},
    'thread/realtime/listVoices' => {
      'voices': {
        'v1': ['alloy'],
        'v2': ['marin'],
        'defaultV1': 'alloy',
        'defaultV2': 'marin',
      },
    },
    'environment/add' => {},
    'environment/info' => {
      'shell': {'name': 'bash', 'path': '/bin/bash'},
      'cwd': 'file:///repo',
    },
    'environment/status' => {'status': 'ready'},
    'skills/list' => {'data': <Object?>[]},
    'skills/config/write' => {'effectiveEnabled': false},
    'plugin/list' => {'marketplaces': <Object?>[]},
    'plugin/read' => {
      'plugin': {
        'marketplaceName': 'openai-curated-remote',
        'summary': {
          'id': 'linear@openai-curated-remote',
          'remotePluginId': 'plugins~linear',
          'name': 'linear',
          'source': {'type': 'remote'},
        },
      },
    },
    'plugin/install' => {'pluginId': 'linear'},
    'plugin/uninstall' => {'pluginId': 'linear'},
    'marketplace/add' => {
      'marketplaceName': 'team-tools',
      'installedRoot': '/marketplaces/team-tools',
      'alreadyAdded': false,
    },
    'marketplace/remove' => {
      'marketplaceName': 'team-tools',
      'installedRoot': '/marketplaces/team-tools',
    },
    'marketplace/upgrade' => {
      'selectedMarketplaces': ['openai-curated'],
      'upgradedRoots': ['/marketplaces/openai-curated'],
      'errors': <Object?>[],
    },
    'hooks/list' => {'data': <Object?>[]},
    'app/list' => {'data': <Object?>[]},
    'mcpServer/oauth/login' => {'serverName': 'github'},
    'agent/snapshot' => {
      'schemaVersion': 1,
      'pendingApprovals': [
        {
          'id': 'approval-proxy',
          'method': 'item/commandExecution/requestApproval',
          'params': {'command': 'cargo test'},
        },
      ],
      'recentEvents': <Object?>[],
    },
    'account/read' => {'account': null, 'requiresOpenaiAuth': false},
    'externalAgentConfig/detect' => {
      'items': [
        {'itemType': 'CONFIG', 'description': 'Import config', 'cwd': null},
      ],
    },
    'externalAgentConfig/import' => {'importId': 'import_1'},
    'externalAgentConfig/import/readHistories' => {'data': <Object?>[]},
    'command/exec' => {'exitCode': 128, 'stdout': '', 'stderr': ''},
    'thread/turns/list' => {'data': <Object?>[]},
    'thread/items/list' => {'data': <Object?>[]},
    'thread/start' => {
      'thread': {
        'id': 'thr_1',
        'sessionId': 'sess_1',
        'preview': 'Thread',
        'ephemeral': false,
        'status': 'idle',
        'cwd': '/repo',
        'updatedAt': 1,
      },
    },
    'turn/start' => {
      'turn': {
        'id': 'turn_1',
        'status': 'inProgress',
        'items': <Object?>[],
        'itemsView': 'notLoaded',
      },
    },
    'turn/steer' => {'turnId': 'turn_1'},
    _ => {},
  };
}
