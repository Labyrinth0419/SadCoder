import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sadcoder_mobile/src/ssh/known_host.dart';
import 'package:sadcoder_mobile/src/ssh/known_host_verifier.dart';
import 'package:sadcoder_mobile/src/ssh/shared_preferences_known_host_store.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  test('requires explicit trust for an unknown host key', () async {
    final store = _MemoryKnownHostStore();
    final verifier = KnownHostVerifier(store: store);

    await expectLater(
      verifier.verifyHostKey(
        _profile,
        keyType: 'ssh-ed25519',
        fingerprintSha256: 'SHA256:first',
      ),
      throwsA(
        isA<UnknownHostKeyException>().having(
          (error) => error.challenge.fingerprintSha256,
          'fingerprint',
          'SHA256:first',
        ),
      ),
    );

    expect(store.entries, isEmpty);
  });

  test(
    'trustHostKey saves a host key and allows matching fingerprints',
    () async {
      final store = _MemoryKnownHostStore();
      final verifier = KnownHostVerifier(
        store: store,
        clock: () => DateTime.fromMillisecondsSinceEpoch(42, isUtc: true),
      );
      const challenge = SshHostKeyChallenge(
        host: 'SRV.Dev',
        port: 2200,
        keyType: 'ssh-ed25519',
        fingerprintSha256: 'SHA256:first',
      );

      await verifier.trustHostKey(challenge);
      final allowed = await verifier.verifyHostKey(
        const SshProfile(
          id: 'dev',
          name: 'Dev',
          host: 'srv.dev',
          port: 2200,
          username: 'alice',
        ),
        keyType: 'ssh-ed25519',
        fingerprintSha256: 'SHA256:first',
      );

      expect(allowed, true);
      expect(store.entries.single.host, 'srv.dev');
      expect(store.entries.single.verifiedAt.millisecondsSinceEpoch, 42);
    },
  );

  test('blocks changed host key fingerprints', () async {
    final store = _MemoryKnownHostStore();
    final verifier = KnownHostVerifier(store: store);
    await verifier.trustHostKey(
      const SshHostKeyChallenge(
        host: 'srv.dev',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprintSha256: 'SHA256:first',
      ),
    );

    await expectLater(
      verifier.verifyHostKey(
        _profile,
        keyType: 'ssh-ed25519',
        fingerprintSha256: 'SHA256:changed',
      ),
      throwsA(
        isA<HostKeyChangedException>()
            .having(
              (error) => error.expected.fingerprintSha256,
              'expected fingerprint',
              'SHA256:first',
            )
            .having(
              (error) => error.received.fingerprintSha256,
              'received fingerprint',
              'SHA256:changed',
            ),
      ),
    );
  });

  test('blocks host key changes even when the key type changes', () async {
    final store = _MemoryKnownHostStore();
    final verifier = KnownHostVerifier(store: store);
    await verifier.trustHostKey(
      const SshHostKeyChallenge(
        host: 'srv.dev',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprintSha256: 'SHA256:first',
      ),
    );

    await expectLater(
      verifier.verifyHostKey(
        _profile,
        keyType: 'rsa-sha2-512',
        fingerprintSha256: 'SHA256:changed',
      ),
      throwsA(
        isA<HostKeyChangedException>()
            .having(
              (error) => error.expected.keyType,
              'expected key type',
              'ssh-ed25519',
            )
            .having(
              (error) => error.received.keyType,
              'received key type',
              'rsa-sha2-512',
            ),
      ),
    );
  });

  test(
    'SharedPreferencesKnownHostStore persists entries by endpoint and key type',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesKnownHostStore();

      await store.saveKnownHost(
        KnownHostEntry(
          host: 'srv.dev',
          port: 2200,
          keyType: 'ssh-ed25519',
          fingerprintSha256: 'SHA256:first',
          verifiedAt: DateTime.fromMillisecondsSinceEpoch(7, isUtc: true),
        ),
      );

      final loaded = await store.readKnownHost(
        host: 'SRV.DEV',
        port: 2200,
        keyType: 'ssh-ed25519',
      );

      expect(loaded?.host, 'srv.dev');
      expect(loaded?.fingerprintSha256, 'SHA256:first');
      expect(loaded?.verifiedAt.millisecondsSinceEpoch, 7);

      final endpointLoaded = await store.readKnownHostForEndpoint(
        host: 'SRV.DEV',
        port: 2200,
      );

      expect(endpointLoaded?.keyType, 'ssh-ed25519');
      expect(endpointLoaded?.fingerprintSha256, 'SHA256:first');
    },
  );
}

const _profile = SshProfile(
  id: 'dev',
  name: 'Dev',
  host: 'srv.dev',
  username: 'alice',
);

class _MemoryKnownHostStore implements KnownHostStore {
  final entries = <KnownHostEntry>[];

  @override
  Future<KnownHostEntry?> readKnownHost({
    required String host,
    required int port,
    required String keyType,
  }) async {
    final key = knownHostStoreKey(host: host, port: port, keyType: keyType);
    for (final entry in entries) {
      if (knownHostStoreKey(
            host: entry.host,
            port: entry.port,
            keyType: entry.keyType,
          ) ==
          key) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<KnownHostEntry?> readKnownHostForEndpoint({
    required String host,
    required int port,
  }) async {
    final endpointKey = knownHostEndpointKey(host: host, port: port);
    for (final entry in entries) {
      if (knownHostEndpointKey(host: entry.host, port: entry.port) ==
          endpointKey) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<void> saveKnownHost(KnownHostEntry entry) async {
    entries.removeWhere(
      (existing) =>
          knownHostStoreKey(
            host: existing.host,
            port: existing.port,
            keyType: existing.keyType,
          ) ==
          knownHostStoreKey(
            host: entry.host,
            port: entry.port,
            keyType: entry.keyType,
          ),
    );
    entries.add(entry);
  }
}
