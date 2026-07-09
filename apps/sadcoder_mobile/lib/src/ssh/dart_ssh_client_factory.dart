import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import 'known_host_verifier.dart';
import 'remote_command_runner.dart';
import 'shared_preferences_known_host_store.dart';
import 'ssh_profile.dart';

class DartSshClientFactory {
  const DartSshClientFactory({
    this.connectTimeout = const Duration(seconds: 15),
    this.keepAliveInterval = const Duration(seconds: 20),
    this.knownHostVerifier = const KnownHostVerifier(
      store: SharedPreferencesKnownHostStore(),
    ),
  });

  final Duration connectTimeout;
  final Duration? keepAliveInterval;
  final KnownHostVerifier? knownHostVerifier;

  Future<SSHClient> connect(SshProfile profile) async {
    final identities = switch (profile.authType) {
      SshAuthType.privateKey => _privateKeyIdentities(profile),
      SshAuthType.password => null,
    };

    final socket = await SSHSocket.connect(
      profile.host,
      profile.port,
      timeout: connectTimeout,
    );

    KnownHostVerificationException? hostKeyFailure;
    final client = SSHClient(
      socket,
      username: profile.username,
      identities: identities,
      onPasswordRequest: profile.password == null
          ? null
          : () => profile.password,
      onVerifyHostKey: _hostKeyVerifier(
        profile,
        onFailure: (error) => hostKeyFailure = error,
      ),
      keepAliveInterval: keepAliveInterval,
    );
    try {
      await client.authenticated;
    } on Object {
      client.close();
      await client.done.catchError((_) {});
      final failure = hostKeyFailure;
      if (failure != null) {
        throw failure;
      }
      rethrow;
    }
    return client;
  }

  SSHHostkeyVerifyHandler? _hostKeyVerifier(
    SshProfile profile, {
    required void Function(KnownHostVerificationException error) onFailure,
  }) {
    final verifier = knownHostVerifier;
    if (verifier == null) {
      return null;
    }
    return (keyType, fingerprintBytes) async {
      try {
        return await verifier.verifyHostKey(
          profile,
          keyType: keyType,
          fingerprintSha256: utf8.decode(fingerprintBytes),
        );
      } on KnownHostVerificationException catch (error) {
        onFailure(error);
        return false;
      }
    };
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
