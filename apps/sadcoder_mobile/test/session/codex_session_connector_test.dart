import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/agent/agent_remote_service.dart';
import 'package:sadcoder_mobile/src/agent/agent_status.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_proxy_connector.dart';

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
    await connection.pluginListReader.listPlugins();
    await connection.pluginDetailReader.readPlugin(pluginId: 'linear');
    await connection.pluginMutationRunner.installPlugin(pluginId: 'linear');
    await connection.pluginMutationRunner.uninstallPlugin(pluginId: 'linear');
    await connection.hookListReader.listHooks();
    await connection.appListReader.listApps();
    await connection.mcpServerOAuthRunner.startOAuthLogin(serverName: 'github');
    await connection.accountSnapshotReader.readAccount();
    await connection.accountLogoutRunner.logout();
    await connection.feedbackUploadRunner.uploadFeedback(
      classification: 'bug',
      reason: 'Authorization: Bearer upload-secret path=/repo',
    );
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
      'plugin/list',
      'plugin/read',
      'plugin/install',
      'plugin/uninstall',
      'hooks/list',
      'app/list',
      'mcpServer/oauth/login',
      'account/read',
      'account/logout',
      'feedback/upload',
      'command/exec',
      'fuzzyFileSearch',
      'thread/turns/list',
      'thread/items/list',
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

  @override
  Future<AgentProxyConnection> connect(SshProfile profile) async {
    connectCount++;
    final input = StreamController<Uint8List>();
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
    'skills/list' => {'data': <Object?>[]},
    'plugin/list' => {'marketplaces': <Object?>[]},
    'plugin/read' => {
      'plugin': {
        'id': 'linear',
        'name': 'linear',
        'source': {'type': 'remote'},
      },
    },
    'plugin/install' => {'pluginId': 'linear'},
    'plugin/uninstall' => {'pluginId': 'linear'},
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
