import 'package:dartssh2/dartssh2.dart';

import 'remote_command_runner.dart';
import 'ssh_profile.dart';

class DartSshClientFactory {
  const DartSshClientFactory({
    this.connectTimeout = const Duration(seconds: 15),
  });

  final Duration connectTimeout;

  Future<SSHClient> connect(SshProfile profile) async {
    final socket = await SSHSocket.connect(
      profile.host,
      profile.port,
      timeout: connectTimeout,
    );

    final identities = switch (profile.authType) {
      SshAuthType.privateKey => _privateKeyIdentities(profile),
      SshAuthType.password => null,
    };

    final client = SSHClient(
      socket,
      username: profile.username,
      identities: identities,
      onPasswordRequest: profile.password == null
          ? null
          : () => profile.password,
    );
    await client.authenticated;
    return client;
  }

  List<SSHKeyPair>? _privateKeyIdentities(SshProfile profile) {
    final privateKeyPem = profile.privateKeyPem;
    if (privateKeyPem == null || privateKeyPem.trim().isEmpty) {
      throw const RemoteCommandException(
        'Private key authentication requires a key.',
      );
    }
    return SSHKeyPair.fromPem(privateKeyPem, profile.passphrase);
  }
}
