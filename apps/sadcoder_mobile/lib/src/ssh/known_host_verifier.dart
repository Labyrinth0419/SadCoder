import 'known_host.dart';
import 'ssh_profile.dart';

class KnownHostVerifier {
  const KnownHostVerifier({required this.store, this.clock = DateTime.now});

  final KnownHostStore store;
  final DateTime Function() clock;

  Future<bool> verifyHostKey(
    SshProfile profile, {
    required String keyType,
    required String fingerprintSha256,
  }) async {
    final challenge = SshHostKeyChallenge(
      host: profile.host,
      port: profile.port,
      keyType: keyType.trim(),
      fingerprintSha256: fingerprintSha256.trim(),
    );
    final known = await store.readKnownHost(
      host: challenge.host,
      port: challenge.port,
      keyType: challenge.keyType,
    );
    if (known != null) {
      if (!known.matches(challenge)) {
        throw HostKeyChangedException(expected: known, received: challenge);
      }
      return true;
    }
    final knownEndpoint = await store.readKnownHostForEndpoint(
      host: challenge.host,
      port: challenge.port,
    );
    if (knownEndpoint != null) {
      throw HostKeyChangedException(
        expected: knownEndpoint,
        received: challenge,
      );
    }
    throw UnknownHostKeyException(challenge);
  }

  Future<void> trustHostKey(SshHostKeyChallenge challenge) {
    return store.saveKnownHost(challenge.toKnownHostEntry(clock()));
  }
}

sealed class KnownHostVerificationException implements Exception {
  const KnownHostVerificationException();
}

class UnknownHostKeyException extends KnownHostVerificationException {
  const UnknownHostKeyException(this.challenge);

  final SshHostKeyChallenge challenge;

  @override
  String toString() {
    return 'Unknown SSH host key for ${challenge.endpoint}: '
        '${challenge.keyType} ${challenge.fingerprintSha256}';
  }
}

class HostKeyChangedException extends KnownHostVerificationException {
  const HostKeyChangedException({
    required this.expected,
    required this.received,
  });

  final KnownHostEntry expected;
  final SshHostKeyChallenge received;

  @override
  String toString() {
    return 'SSH host key changed for ${received.endpoint}: expected '
        '${expected.keyType} ${expected.fingerprintSha256}, received '
        '${received.keyType} ${received.fingerprintSha256}';
  }
}
