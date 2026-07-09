import 'dart:async';
import 'dart:typed_data';

import '../protocol/json_rpc.dart';
import '../protocol/json_rpc_diagnostic_log.dart';
import '../protocol/line_json_rpc_transport.dart';
import 'ssh_profile.dart';

abstract interface class AgentProxyConnector {
  Future<AgentProxyConnection> connect(SshProfile profile);
}

class AgentProxyConnection {
  AgentProxyConnection({
    required this.input,
    required this.output,
    required this.close,
    Future<void>? done,
  }) : done = done ?? Completer<void>().future;

  final Stream<Uint8List> input;
  final StreamSink<Uint8List> output;
  final Future<void> Function() close;
  final Future<void> done;

  JsonRpcTransport asJsonRpcTransport({
    JsonRpcDiagnosticLogSink? diagnosticLogSink,
  }) {
    return LineJsonRpcTransport(
      input: input,
      output: output,
      diagnosticLogSink: diagnosticLogSink,
    );
  }
}
