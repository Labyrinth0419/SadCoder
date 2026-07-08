import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import 'remote_command_runner.dart';
import 'ssh_profile.dart';

class DartSshRemoteCommandRunner implements RemoteCommandRunner {
  const DartSshRemoteCommandRunner({
    this.connectTimeout = const Duration(seconds: 15),
  });

  final Duration connectTimeout;

  @override
  Future<RemoteCommandResult> run(
    SshProfile profile,
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final client = await _connect(profile).timeout(connectTimeout);
    try {
      final result = await client.runWithResult(command).timeout(timeout);
      return RemoteCommandResult(
        exitCode: result.exitCode,
        stdout: utf8.decode(result.stdout, allowMalformed: true),
        stderr: utf8.decode(result.stderr, allowMalformed: true),
      );
    } finally {
      client.close();
      await client.done.catchError((_) {});
    }
  }

  Future<SSHClient> _connect(SshProfile profile) async {
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
