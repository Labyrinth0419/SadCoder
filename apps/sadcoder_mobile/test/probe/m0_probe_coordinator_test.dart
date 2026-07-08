import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/agent/agent_remote_service.dart';
import 'package:sadcoder_mobile/src/agent/agent_status.dart';
import 'package:sadcoder_mobile/src/probe/m0_probe_coordinator.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_proxy_connector.dart';

void main() {
  test(
    'run validates status and app-server methods over line transport',
    () async {
      final connector = _LineServerProxyConnector();
      final coordinator = M0ProbeCoordinator(
        statusReader: _FakeStatusReader(_readyStatus),
        proxyConnector: connector,
      );

      final report = await coordinator.run(_profile);

      expect(report.ok, true);
      expect(report.agentStatus?.codexAvailable, true);
      expect(report.steps.map((step) => step.step), [
        M0ProbeStep.agentStatus,
        M0ProbeStep.proxyConnect,
        M0ProbeStep.initialize,
        M0ProbeStep.modelList,
        M0ProbeStep.threadList,
      ]);
      expect(connector.methods, [
        'initialize',
        'initialized',
        'model/list',
        'thread/list',
      ]);
      expect(connector.closed, true);
    },
  );

  test('run stops after app-server request failure', () async {
    final connector = _LineServerProxyConnector(failMethod: 'model/list');
    final coordinator = M0ProbeCoordinator(
      statusReader: _FakeStatusReader(_readyStatus),
      proxyConnector: connector,
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, false);
    expect(report.steps.map((step) => step.step), [
      M0ProbeStep.agentStatus,
      M0ProbeStep.proxyConnect,
      M0ProbeStep.initialize,
      M0ProbeStep.modelList,
    ]);
    expect(report.steps.last.ok, false);
    expect(connector.methods, ['initialize', 'initialized', 'model/list']);
    expect(connector.closed, true);
  });

  test('run stops when agent status fails', () async {
    final coordinator = M0ProbeCoordinator(
      statusReader: const _FailingStatusReader('status unavailable'),
      proxyConnector: _LineServerProxyConnector(),
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, false);
    expect(report.agentStatus, isNull);
    expect(report.steps.map((step) => step.step), [M0ProbeStep.agentStatus]);
    expect(report.steps.single.detail, contains('status unavailable'));
  });

  test('run reports proxy connection failure after status succeeds', () async {
    final coordinator = M0ProbeCoordinator(
      statusReader: _FakeStatusReader(_readyStatus),
      proxyConnector: const _FailingProxyConnector('proxy failed'),
    );

    final report = await coordinator.run(_profile);

    expect(report.ok, false);
    expect(report.agentStatus, _readyStatus);
    expect(report.steps.map((step) => step.step), [
      M0ProbeStep.agentStatus,
      M0ProbeStep.proxyConnect,
    ]);
    expect(report.steps.last.ok, false);
    expect(report.steps.last.detail, contains('proxy failed'));
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
  codexVersion: 'codex-cli 0.142.5',
  backendKind: BackendKind.codexAppServerStdio,
  backendState: BackendState.ready,
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

class _FailingProxyConnector implements AgentProxyConnector {
  const _FailingProxyConnector(this.message);

  final String message;

  @override
  Future<AgentProxyConnection> connect(SshProfile profile) async {
    throw StateError(message);
  }
}

class _LineServerProxyConnector implements AgentProxyConnector {
  _LineServerProxyConnector({this.failMethod});

  final String? failMethod;
  final methods = <String>[];
  bool closed = false;

  @override
  Future<AgentProxyConnection> connect(SshProfile profile) async {
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
    'initialize' => {'serverInfo': 'test'},
    'model/list' => {
      'models': ['gpt-5'],
    },
    'thread/list' => {'threads': <Object?>[]},
    _ => {},
  };
}
