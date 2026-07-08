import 'dart:async';
import 'dart:typed_data';

import '../protocol/json_rpc.dart';
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
  });

  final Stream<Uint8List> input;
  final StreamSink<Uint8List> output;
  final Future<void> Function() close;

  JsonRpcTransport asJsonRpcTransport() {
    return LineJsonRpcTransport(input: input, output: output);
  }
}
