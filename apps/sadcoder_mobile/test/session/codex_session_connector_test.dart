import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
    await connection.session.client.listModels();
    await connection.turnRunner.startThread();
    await connection.turnRunner.startTurn(threadId: 'thr_1', text: 'Fix bug');
    await connection.turnRunner.interruptTurn(
      threadId: 'thr_1',
      turnId: 'turn_1',
    );

    expect(proxyConnector.methods, [
      'initialize',
      'initialized',
      'model/list',
      'thread/start',
      'turn/start',
      'turn/interrupt',
    ]);
    expect(connection.profile, _profile);
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
      expect(proxyConnector.methods, ['initialize', 'initialized']);
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
    expect(proxyConnector.methods, ['initialize']);
    expect(proxyConnector.methods, isNot(contains('turn/interrupt')));
  });
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

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
    'model/list' => {'models': <Object?>[]},
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
    _ => {},
  };
}
