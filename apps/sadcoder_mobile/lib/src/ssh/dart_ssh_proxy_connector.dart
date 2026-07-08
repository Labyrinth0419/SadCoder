import 'package:dartssh2/dartssh2.dart';

import 'dart_ssh_client_factory.dart';
import 'ssh_profile.dart';
import 'ssh_proxy_connector.dart';

class DartSshProxyConnector implements AgentProxyConnector {
  const DartSshProxyConnector({
    this.clientFactory = const DartSshClientFactory(),
  });

  final DartSshClientFactory clientFactory;

  @override
  Future<AgentProxyConnection> connect(SshProfile profile) async {
    final client = await clientFactory.connect(profile);
    final session = await client.execute('${profile.agentCommand} proxy');
    return AgentProxyConnection(
      input: session.stdout,
      output: session.stdin,
      close: () => _close(client, session),
    );
  }

  Future<void> _close(SSHClient client, SSHSession session) async {
    await session.stdin.close();
    client.close();
    await client.done.catchError((_) {});
  }
}
