import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc_diagnostic_log.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/protocol/line_json_rpc_transport.dart';
import 'package:sadcoder_mobile/src/security/log_redactor.dart';

void main() {
  test(
    'request writes a JSON line and completes from matching response',
    () async {
      final input = StreamController<List<int>>();
      final output = StreamController<Uint8List>();
      final outgoing = <Map<String, Object?>>[];
      output.stream.listen((bytes) {
        outgoing.add(jsonDecode(utf8.decode(bytes)) as Map<String, Object?>);
      });
      final transport = LineJsonRpcTransport(
        input: input.stream,
        output: output.sink,
      );

      final future = transport.request(
        JsonRpcRequest(id: 7, method: 'thread/list', params: {'limit': 1}),
      );
      await Future<void>.delayed(Duration.zero);
      input.add(
        utf8.encode('{"jsonrpc":"2.0","id":7,"result":{"threads":[]}}\n'),
      );

      final response = await future;

      expect(outgoing.single['method'], 'thread/list');
      expect(outgoing.single['params'], {'limit': 1});
      expect(response, {'threads': []});

      await transport.close();
    },
  );

  test('request rejects non-object results', () async {
    final input = StreamController<List<int>>();
    final output = StreamController<Uint8List>();
    output.stream.listen((_) {});
    final transport = LineJsonRpcTransport(
      input: input.stream,
      output: output.sink,
    );

    final future = transport.request(
      JsonRpcRequest(id: 7, method: 'thread/list', params: {'limit': 1}),
    );
    await Future<void>.delayed(Duration.zero);
    input.add(utf8.encode('{"jsonrpc":"2.0","id":7,"result":true}\n'));

    await expectLater(future, throwsA(isA<FormatException>()));

    await transport.close();
  });

  test('notifications are routed separately from responses', () async {
    final input = StreamController<List<int>>();
    final output = StreamController<Uint8List>();
    output.stream.listen((_) {});
    final transport = LineJsonRpcTransport(
      input: input.stream,
      output: output.sink,
    );
    final notification = transport.notifications.first;

    input.add(utf8.encode('{"jsonrpc":"2.0","method":"thread/started"}\n'));

    expect((await notification)['method'], 'thread/started');

    await transport.close();
  });

  test('server requests are routed separately and can be answered', () async {
    final input = StreamController<List<int>>();
    final output = StreamController<Uint8List>();
    final outgoing = <Map<String, Object?>>[];
    output.stream.listen((bytes) {
      outgoing.add(jsonDecode(utf8.decode(bytes)) as Map<String, Object?>);
    });
    final transport = LineJsonRpcTransport(
      input: input.stream,
      output: output.sink,
    );
    final serverRequest = transport.serverRequests.first;

    input.add(
      utf8.encode(
        '{"jsonrpc":"2.0","id":"approval-1","method":"item/commandExecution/requestApproval","params":{"command":"cargo test"}}\n',
      ),
    );

    final request = await serverRequest;
    expect(request.id, 'approval-1');
    expect(request.method, 'item/commandExecution/requestApproval');
    expect(request.params, {'command': 'cargo test'});

    await transport.respond(
      const JsonRpcResponseMessage(
        id: 'approval-1',
        result: {'decision': 'accept'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(outgoing.single, {
      'jsonrpc': '2.0',
      'id': 'approval-1',
      'result': {'decision': 'accept'},
    });

    await transport.close();
  });

  test('response error completes request with JsonRpcRemoteException', () async {
    final input = StreamController<List<int>>();
    final output = StreamController<Uint8List>();
    output.stream.listen((_) {});
    final transport = LineJsonRpcTransport(
      input: input.stream,
      output: output.sink,
    );

    final future = transport.request(
      JsonRpcRequest(id: 'a', method: 'model/list', params: {}),
    );
    input.add(
      utf8.encode(
        '{"jsonrpc":"2.0","id":"a","error":{"code":-32600,"message":"bad"}}\n',
      ),
    );

    await expectLater(future, throwsA(isA<JsonRpcRemoteException>()));

    await transport.close();
  });

  test(
    'diagnostic log sink records redacted inbound and outbound messages',
    () async {
      final input = StreamController<List<int>>();
      final output = StreamController<Uint8List>();
      output.stream.listen((_) {});
      final entries = <JsonRpcDiagnosticLogEntry>[];
      final transport = LineJsonRpcTransport(
        input: input.stream,
        output: output.sink,
        diagnosticLogSink: RedactingJsonRpcDiagnosticLogSink(
          onEntry: entries.add,
          clock: () => DateTime.fromMillisecondsSinceEpoch(1, isUtc: true),
          redactor: const LogRedactor(redactionVersion: 7),
        ),
      );

      final future = transport.request(
        JsonRpcRequest(
          id: 'login',
          method: 'account/login',
          params: {'password': 'hunter2', 'path': '/repo'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      input.add(
        utf8.encode(
          '{"jsonrpc":"2.0","id":"login","result":{"accessToken":"secret-token","path":"/repo"}}\n',
        ),
      );
      await future;

      expect(entries.map((entry) => entry.direction), [
        JsonRpcDiagnosticLogDirection.outgoing,
        JsonRpcDiagnosticLogDirection.incoming,
      ]);
      expect(entries.map((entry) => entry.redactionVersion), [7, 7]);
      expect(
        (entries.first.redactedJson['params'] as Map)['password'],
        '[REDACTED]',
      );
      expect((entries.first.redactedJson['params'] as Map)['path'], '/repo');
      expect(
        (entries.last.redactedJson['result'] as Map)['accessToken'],
        '[REDACTED]',
      );
      expect((entries.last.redactedJson['result'] as Map)['path'], '/repo');

      await transport.close();
    },
  );
}
