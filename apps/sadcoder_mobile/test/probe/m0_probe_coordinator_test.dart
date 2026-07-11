import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/agent/agent_remote_service.dart';
import 'package:sadcoder_mobile/src/agent/agent_status.dart';
import 'package:sadcoder_mobile/src/probe/m0_probe_coordinator.dart';
import 'package:sadcoder_mobile/src/ssh/known_host.dart';
import 'package:sadcoder_mobile/src/ssh/known_host_verifier.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_proxy_connector.dart';

void main() {
  test(
    'run validates status and app-server methods over line transport',
    () async {
      final connector = _LineServerProxyConnector();
      final coordinator = _coordinator(
        statusReader: _FakeStatusReader(_readyStatus),
        proxyConnector: connector,
      );

      final report = await coordinator.run(_profile);

      expect(report.ok, true);
      expect(report.agentStatus?.codexAvailable, true);
      expect(report.steps.map((step) => step.step), [
        M0ProbeStep.tcpConnect,
        M0ProbeStep.sshHandshake,
        M0ProbeStep.hostKey,
        M0ProbeStep.auth,
        M0ProbeStep.remoteShell,
        M0ProbeStep.agentStatus,
        M0ProbeStep.codexVersion,
        M0ProbeStep.proxyConnect,
        M0ProbeStep.agentHello,
        M0ProbeStep.initialize,
        M0ProbeStep.accountRead,
        M0ProbeStep.modelList,
        M0ProbeStep.configRead,
        M0ProbeStep.permissionProfileList,
        M0ProbeStep.threadList,
      ]);
      expect(connector.methods, [
        'agent/hello',
        'initialize',
        'initialized',
        'account/read',
        'model/list',
        'config/read',
        'permissionProfile/list',
        'thread/list',
      ]);
      expect(connector.paramsByMethod['thread/list'], {'limit': 1});
      expect(connector.closed, true);
    },
  );

  test('run starts a not-started backend before proxy connect', () async {
    final connector = _LineServerProxyConnector();
    final starter = _FakeStartRunner(_readyServiceStatus);
    final coordinator = _coordinator(
      statusReader: _FakeStatusReader(_notStartedServiceStatus),
      startRunner: starter,
      proxyConnector: connector,
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, true);
    expect(report.agentStatus, _readyServiceStatus);
    expect(starter.startedProfiles, [_profile]);
    expect(report.steps.map((step) => step.step), [
      M0ProbeStep.tcpConnect,
      M0ProbeStep.sshHandshake,
      M0ProbeStep.hostKey,
      M0ProbeStep.auth,
      M0ProbeStep.remoteShell,
      M0ProbeStep.agentStatus,
      M0ProbeStep.codexVersion,
      M0ProbeStep.agentStart,
      M0ProbeStep.proxyConnect,
      M0ProbeStep.agentHello,
      M0ProbeStep.initialize,
      M0ProbeStep.accountRead,
      M0ProbeStep.modelList,
      M0ProbeStep.configRead,
      M0ProbeStep.permissionProfileList,
      M0ProbeStep.threadList,
    ]);
    expect(connector.connectCount, 1);
  });

  test('run stops before proxy when backend start fails', () async {
    final connector = _LineServerProxyConnector();
    final coordinator = _coordinator(
      statusReader: _FakeStatusReader(_notStartedServiceStatus),
      startRunner: const _FailingStartRunner('start failed'),
      proxyConnector: connector,
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, false);
    expect(report.agentStatus, _notStartedServiceStatus);
    expect(report.steps.map((step) => step.step), [
      M0ProbeStep.tcpConnect,
      M0ProbeStep.sshHandshake,
      M0ProbeStep.hostKey,
      M0ProbeStep.auth,
      M0ProbeStep.remoteShell,
      M0ProbeStep.agentStatus,
      M0ProbeStep.codexVersion,
      M0ProbeStep.agentStart,
    ]);
    expect(report.steps.last.detail, contains('start failed'));
    expect(connector.connectCount, 0);
  });

  test('run stops before shell probes when ssh probe fails', () async {
    final connector = _LineServerProxyConnector();
    final coordinator = _coordinator(
      sshProbeRunner: const _FailingSshProbeRunner('network unreachable'),
      statusReader: _FakeStatusReader(_readyStatus),
      proxyConnector: connector,
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, false);
    expect(report.steps.map((step) => step.step), [M0ProbeStep.tcpConnect]);
    expect(report.steps.single.ok, false);
    expect(report.steps.single.suggestion, M0ProbeSuggestion.checkNetwork);
    expect(connector.connectCount, 0);
  });

  test('run stops before agent status when remote shell probe fails', () async {
    final connector = _LineServerProxyConnector();
    final coordinator = _coordinator(
      shellProbeRunner: const _FailingShellProbeRunner('shell disabled'),
      statusReader: _FakeStatusReader(_readyStatus),
      proxyConnector: connector,
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, false);
    expect(report.steps.map((step) => step.step), [
      M0ProbeStep.tcpConnect,
      M0ProbeStep.sshHandshake,
      M0ProbeStep.hostKey,
      M0ProbeStep.auth,
      M0ProbeStep.remoteShell,
    ]);
    expect(report.steps.last.ok, false);
    expect(report.steps.last.suggestion, M0ProbeSuggestion.checkRemoteShell);
    expect(connector.connectCount, 0);
  });

  test('run stops after app-server request failure', () async {
    final connector = _LineServerProxyConnector(failMethod: 'config/read');
    final coordinator = _coordinator(
      statusReader: _FakeStatusReader(_readyStatus),
      proxyConnector: connector,
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, false);
    expect(report.steps.map((step) => step.step), [
      M0ProbeStep.tcpConnect,
      M0ProbeStep.sshHandshake,
      M0ProbeStep.hostKey,
      M0ProbeStep.auth,
      M0ProbeStep.remoteShell,
      M0ProbeStep.agentStatus,
      M0ProbeStep.codexVersion,
      M0ProbeStep.proxyConnect,
      M0ProbeStep.agentHello,
      M0ProbeStep.initialize,
      M0ProbeStep.accountRead,
      M0ProbeStep.modelList,
      M0ProbeStep.configRead,
    ]);
    expect(report.steps.last.ok, false);
    expect(connector.methods, [
      'agent/hello',
      'initialize',
      'initialized',
      'account/read',
      'model/list',
      'config/read',
    ]);
    expect(connector.closed, true);
  });

  test('run stops when agent status fails', () async {
    final coordinator = _coordinator(
      statusReader: const _FailingStatusReader('status unavailable'),
      proxyConnector: _LineServerProxyConnector(),
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, false);
    expect(report.agentStatus, isNull);
    expect(report.steps.map((step) => step.step), [
      M0ProbeStep.tcpConnect,
      M0ProbeStep.sshHandshake,
      M0ProbeStep.hostKey,
      M0ProbeStep.auth,
      M0ProbeStep.remoteShell,
      M0ProbeStep.agentStatus,
    ]);
    expect(report.steps.last.detail, contains('status unavailable'));
  });

  test('run uses agent status as the Codex availability source', () async {
    final connector = _LineServerProxyConnector();
    final coordinator = _coordinator(
      statusReader: _FakeStatusReader(_missingCodexStatus),
      proxyConnector: connector,
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, false);
    expect(report.agentStatus, _missingCodexStatus);
    expect(report.steps.map((step) => step.step), [
      M0ProbeStep.tcpConnect,
      M0ProbeStep.sshHandshake,
      M0ProbeStep.hostKey,
      M0ProbeStep.auth,
      M0ProbeStep.remoteShell,
      M0ProbeStep.agentStatus,
      M0ProbeStep.codexVersion,
    ]);
    expect(report.steps.last.ok, false);
    expect(
      report.steps.last.detail,
      'runtime-not-found: node: SyntaxError: Unexpected token',
    );
    expect(report.steps.last.suggestion, M0ProbeSuggestion.installCodex);
    expect(connector.connectCount, 0);
  });

  test('run reports proxy connection failure after status succeeds', () async {
    final coordinator = _coordinator(
      statusReader: _FakeStatusReader(_readyStatus),
      proxyConnector: const _FailingProxyConnector('proxy failed'),
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, false);
    expect(report.agentStatus, _readyStatus);
    expect(report.steps.map((step) => step.step), [
      M0ProbeStep.tcpConnect,
      M0ProbeStep.sshHandshake,
      M0ProbeStep.hostKey,
      M0ProbeStep.auth,
      M0ProbeStep.remoteShell,
      M0ProbeStep.agentStatus,
      M0ProbeStep.codexVersion,
      M0ProbeStep.proxyConnect,
    ]);
    expect(report.steps.last.ok, false);
    expect(report.steps.last.detail, contains('proxy failed'));
  });

  test('run stops when agent hello over proxy fails', () async {
    final connector = _LineServerProxyConnector(failMethod: 'agent/hello');
    final coordinator = _coordinator(
      statusReader: _FakeStatusReader(_readyStatus),
      proxyConnector: connector,
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, false);
    expect(report.steps.map((step) => step.step), [
      M0ProbeStep.tcpConnect,
      M0ProbeStep.sshHandshake,
      M0ProbeStep.hostKey,
      M0ProbeStep.auth,
      M0ProbeStep.remoteShell,
      M0ProbeStep.agentStatus,
      M0ProbeStep.codexVersion,
      M0ProbeStep.proxyConnect,
      M0ProbeStep.agentHello,
    ]);
    expect(connector.methods, ['agent/hello']);
    expect(connector.closed, true);
  });

  test('run rethrows known-host challenges from status checks', () async {
    final coordinator = _coordinator(
      statusReader: const _KnownHostStatusReader(),
      proxyConnector: _LineServerProxyConnector(),
    );

    await expectLater(
      coordinator.run(_profile),
      throwsA(isA<UnknownHostKeyException>()),
    );
  });

  test('run rethrows known-host challenges from proxy connect', () async {
    final coordinator = _coordinator(
      statusReader: _FakeStatusReader(_readyStatus),
      proxyConnector: const _KnownHostProxyConnector(),
    );

    await expectLater(
      coordinator.run(_profile),
      throwsA(isA<UnknownHostKeyException>()),
    );
  });
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

M0ProbeCoordinator _coordinator({
  SshConnectionProbeRunner sshProbeRunner = const _PassingSshProbeRunner(),
  RemoteShellProbeRunner shellProbeRunner = const _PassingShellProbeRunner(),
  required AgentStatusReader statusReader,
  AgentStartRunner? startRunner,
  required AgentProxyConnector proxyConnector,
}) {
  return M0ProbeCoordinator(
    sshProbeRunner: sshProbeRunner,
    shellProbeRunner: shellProbeRunner,
    statusReader: statusReader,
    startRunner: startRunner,
    proxyConnector: proxyConnector,
  );
}

class _PassingSshProbeRunner implements SshConnectionProbeRunner {
  const _PassingSshProbeRunner();

  @override
  Future<List<M0ProbeStepResult>> probe(SshProfile profile) async {
    return const [
      M0ProbeStepResult(step: M0ProbeStep.tcpConnect, ok: true),
      M0ProbeStepResult(step: M0ProbeStep.sshHandshake, ok: true),
      M0ProbeStepResult(step: M0ProbeStep.hostKey, ok: true),
      M0ProbeStepResult(step: M0ProbeStep.auth, ok: true),
    ];
  }
}

class _FailingSshProbeRunner implements SshConnectionProbeRunner {
  const _FailingSshProbeRunner(this.message);

  final String message;

  @override
  Future<List<M0ProbeStepResult>> probe(SshProfile profile) async {
    return [
      M0ProbeStepResult(
        step: M0ProbeStep.tcpConnect,
        ok: false,
        detail: message,
        suggestion: M0ProbeSuggestion.checkNetwork,
      ),
    ];
  }
}

class _PassingShellProbeRunner implements RemoteShellProbeRunner {
  const _PassingShellProbeRunner();

  @override
  Future<void> probeShell(SshProfile profile) async {}
}

class _FailingShellProbeRunner implements RemoteShellProbeRunner {
  const _FailingShellProbeRunner(this.message);

  final String message;

  @override
  Future<void> probeShell(SshProfile profile) async {
    throw StateError(message);
  }
}

const _readyStatus = AgentStatus(
  agentVersion: '0.1.0',
  platformOs: 'linux',
  platformArch: 'x86_64',
  codexPath: 'codex',
  codexAvailable: true,
  codexVersion: 'codex-cli 0.142.5',
  backendKind: BackendKind.codexAppServerStdio,
  backendState: BackendState.ready,
);

const _notStartedServiceStatus = AgentStatus(
  agentVersion: '0.1.0',
  platformOs: 'linux',
  platformArch: 'x86_64',
  codexPath: 'codex',
  codexAvailable: true,
  codexVersion: 'codex-cli 0.142.5',
  backendKind: BackendKind.sadcoderAgentService,
  backendState: BackendState.notStarted,
  backendDetail: 'SadCoder service is not running; run sadcoder-agent start',
);

const _readyServiceStatus = AgentStatus(
  agentVersion: '0.1.0',
  platformOs: 'linux',
  platformArch: 'x86_64',
  codexPath: 'codex',
  codexAvailable: true,
  codexVersion: 'codex-cli 0.142.5',
  backendKind: BackendKind.sadcoderAgentService,
  backendState: BackendState.ready,
  backendDetail: 'SadCoder service is listening',
);

const _missingCodexStatus = AgentStatus(
  agentVersion: '0.1.0',
  platformOs: 'linux',
  platformArch: 'x86_64',
  codexPath: 'codex',
  codexAvailable: false,
  codexFailure: AgentCodexFailure(
    kind: 'runtime-not-found',
    detail: 'node: SyntaxError: Unexpected token',
  ),
  backendKind: BackendKind.unknown,
  backendState: BackendState.unavailable,
);

class _FakeStatusReader implements AgentStatusReader {
  const _FakeStatusReader(this.status);

  final AgentStatus status;

  @override
  Future<AgentStatus> readStatus(SshProfile profile) async {
    return status;
  }
}

class _FailingStatusReader implements AgentStatusReader {
  const _FailingStatusReader(this.message);

  final String message;

  @override
  Future<AgentStatus> readStatus(SshProfile profile) async {
    throw StateError(message);
  }
}

class _KnownHostStatusReader implements AgentStatusReader {
  const _KnownHostStatusReader();

  @override
  Future<AgentStatus> readStatus(SshProfile profile) async {
    throw const UnknownHostKeyException(_hostKeyChallenge);
  }
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

class _FailingStartRunner implements AgentStartRunner {
  const _FailingStartRunner(this.message);

  final String message;

  @override
  Future<AgentStatus> start(SshProfile profile) async {
    throw StateError(message);
  }
}

class _FailingProxyConnector implements AgentProxyConnector {
  const _FailingProxyConnector(this.message);

  final String message;

  @override
  Future<AgentProxyConnection> connect(SshProfile profile) async {
    throw StateError(message);
  }
}

class _KnownHostProxyConnector implements AgentProxyConnector {
  const _KnownHostProxyConnector();

  @override
  Future<AgentProxyConnection> connect(SshProfile profile) async {
    throw const UnknownHostKeyException(_hostKeyChallenge);
  }
}

const _hostKeyChallenge = SshHostKeyChallenge(
  host: 'srv.dev',
  port: 22,
  keyType: 'ssh-ed25519',
  fingerprintSha256: 'SHA256:first',
);

class _LineServerProxyConnector implements AgentProxyConnector {
  _LineServerProxyConnector({this.failMethod});

  final String? failMethod;
  final methods = <String>[];
  final paramsByMethod = <String, Map<String, Object?>>{};
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
    final method = request['method'] as String;
    methods.add(method);
    final params = request['params'];
    if (params is Map) {
      paramsByMethod[method] = Map<String, Object?>.from(params);
    }

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
    'account/read' => {'account': null, 'requiresOpenaiAuth': false},
    'model/list' => {
      'models': ['gpt-5'],
    },
    'config/read' => {'config': <String, Object?>{}},
    'permissionProfile/list' => {'data': <Object?>[]},
    'thread/list' => {'threads': <Object?>[]},
    _ => {},
  };
}
