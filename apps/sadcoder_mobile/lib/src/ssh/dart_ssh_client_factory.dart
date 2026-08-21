import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import 'known_host_verifier.dart';
import 'remote_command_runner.dart';
import 'shared_preferences_known_host_store.dart';
import 'ssh_profile.dart';

class SshConnectionObserver {
  const SshConnectionObserver({
    this.onTcpConnected,
    this.onHostKeyReceived,
    this.onHostKeyVerified,
    this.onAuthenticated,
  });

  final void Function()? onTcpConnected;
  final void Function(String keyType, String fingerprintSha256)?
  onHostKeyReceived;
  final void Function(String keyType, String fingerprintSha256)?
  onHostKeyVerified;
  final void Function()? onAuthenticated;
}

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

  Future<SSHClient> connect(
    SshProfile profile, {
    SshConnectionObserver? observer,
  }) async {
    final identities = switch (profile.authType) {
      SshAuthType.privateKey => _privateKeyIdentities(profile),
      SshAuthType.password => null,
    };

    final socket = await SSHSocket.connect(
      profile.host,
      profile.port,
      timeout: connectTimeout,
    );
    observer?.onTcpConnected?.call();

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
        observer: observer,
        onFailure: (error) => hostKeyFailure = error,
      ),
      keepAliveInterval: keepAliveInterval,
    );
    try {
      await client.authenticated;
      observer?.onAuthenticated?.call();
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
    required SshConnectionObserver? observer,
    required void Function(KnownHostVerificationException error) onFailure,
  }) {
    final verifier = knownHostVerifier;
    if (verifier == null) {
      return null;
    }
    return (keyType, fingerprintBytes) async {
      final fingerprintSha256 = utf8.decode(fingerprintBytes);
      observer?.onHostKeyReceived?.call(keyType, fingerprintSha256);
      try {
        final verified = await verifier.verifyHostKey(
          profile,
          keyType: keyType,
          fingerprintSha256: fingerprintSha256,
        );
        if (verified) {
          observer?.onHostKeyVerified?.call(keyType, fingerprintSha256);
        }
        return verified;
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
    return parseSshPrivateKey(privateKeyPem, profile.passphrase);
  }
}

@visibleForTesting
List<SSHKeyPair> parseSshPrivateKey(
  String privateKeyPem,
  String? passphrase,
) {
  final normalizedPassphrase = passphrase?.isEmpty == true ? null : passphrase;
  return SSHKeyPair.fromPem(privateKeyPem, normalizedPassphrase);
}
