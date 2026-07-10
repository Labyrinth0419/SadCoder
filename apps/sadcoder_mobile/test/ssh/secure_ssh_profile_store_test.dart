import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/ssh/secure_ssh_profile_store.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_credential_store.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile_store.dart';

void main() {
  test('combines profile metadata with securely stored secrets', () async {
    final metadataStore = _FakeProfileStore(
      initialProfile: const SshProfile(
        id: 'manual',
        name: 'Dev',
        host: 'srv.dev',
        username: 'alice',
      ),
    );
    final credentialStore = _FakeCredentialStore(
      initialSecrets: const SshProfileSecrets(password: 'secret'),
    );
    final store = SecureSshProfileStore(
      metadataStore: metadataStore,
      credentialStore: credentialStore,
    );

    final profile = await store.loadLastProfile();

    expect(profile?.host, 'srv.dev');
    expect(profile?.password, 'secret');
    expect(credentialStore.loadedProfileIds, ['manual']);
  });

  test('saves metadata and secrets to separate stores', () async {
    final metadataStore = _FakeProfileStore();
    final credentialStore = _FakeCredentialStore();
    final store = SecureSshProfileStore(
      metadataStore: metadataStore,
      credentialStore: credentialStore,
    );

    await store.saveLastProfile(
      const SshProfile(
        id: 'manual',
        name: 'Dev',
        host: 'srv.dev',
        username: 'alice',
        authType: SshAuthType.privateKey,
        password: 'secret',
        privateKeyPem: 'private-key',
        passphrase: 'passphrase',
        defaultCwd: '/repo',
      ),
    );

    expect(metadataStore.savedProfile?.password, isNull);
    expect(metadataStore.savedProfile?.privateKeyPem, isNull);
    expect(metadataStore.savedProfile?.passphrase, isNull);
    expect(metadataStore.savedProfile?.authType, SshAuthType.privateKey);
    expect(metadataStore.savedProfile?.defaultCwd, '/repo');
    expect(credentialStore.savedProfileIds, ['manual']);
    expect(credentialStore.savedSecrets.single.password, 'secret');
    expect(credentialStore.savedSecrets.single.privateKeyPem, 'private-key');
    expect(credentialStore.savedSecrets.single.passphrase, 'passphrase');
  });

  test('loads and saves profile lists with secure secrets', () async {
    final metadataStore = _FakeProfileListStore(
      initialProfiles: const [
        SshProfile(
          id: 'alice@srv.dev:22',
          name: 'Dev',
          host: 'srv.dev',
          username: 'alice',
        ),
        SshProfile(
          id: 'root@prod.dev:2200',
          name: 'Prod',
          host: 'prod.dev',
          port: 2200,
          username: 'root',
        ),
      ],
    );
    final credentialStore = _FakeCredentialStore(
      secretsByProfileId: const {
        'alice@srv.dev:22': SshProfileSecrets(password: 'alice-secret'),
        'root@prod.dev:2200': SshProfileSecrets(password: 'root-secret'),
      },
    );
    final store = SecureSshProfileStore(
      metadataStore: metadataStore,
      credentialStore: credentialStore,
    );

    final profiles = await store.loadProfiles();
    await store.saveProfile(
      const SshProfile(
        id: 'bob@srv.dev:22',
        name: 'Bob',
        host: 'srv.dev',
        username: 'bob',
        password: 'bob-secret',
      ),
    );

    expect(profiles.map((profile) => profile.password), [
      'alice-secret',
      'root-secret',
    ]);
    expect(credentialStore.loadedProfileIds, [
      'alice@srv.dev:22',
      'root@prod.dev:2200',
    ]);
    expect(metadataStore.savedProfile?.id, 'bob@srv.dev:22');
    expect(metadataStore.savedProfile?.password, isNull);
    expect(credentialStore.savedProfileIds.last, 'bob@srv.dev:22');
    expect(credentialStore.savedSecrets.last.password, 'bob-secret');

    await store.deleteProfile('bob@srv.dev:22');

    expect(metadataStore.deletedProfileIds, ['bob@srv.dev:22']);
    expect(credentialStore.deletedProfileIds, ['bob@srv.dev:22']);
  });
}

class _FakeProfileStore implements SshProfileStore {
  _FakeProfileStore({this.initialProfile});

  final SshProfile? initialProfile;
  SshProfile? savedProfile;

  @override
  Future<SshProfile?> loadLastProfile() async => initialProfile;

  @override
  Future<void> saveLastProfile(SshProfile profile) async {
    savedProfile = profile;
  }
}

class _FakeProfileListStore implements SshProfileListStore {
  _FakeProfileListStore({required this.initialProfiles});

  final List<SshProfile> initialProfiles;
  SshProfile? savedProfile;

  @override
  Future<SshProfile?> loadLastProfile() async {
    return initialProfiles.isEmpty ? null : initialProfiles.first;
  }

  @override
  Future<void> saveLastProfile(SshProfile profile) async {
    savedProfile = profile;
  }

  @override
  Future<List<SshProfile>> loadProfiles() async => initialProfiles;

  @override
  Future<void> saveProfile(SshProfile profile) async {
    savedProfile = profile;
  }

  final deletedProfileIds = <String>[];

  @override
  Future<void> deleteProfile(String profileId) async {
    deletedProfileIds.add(profileId);
  }
}

class _FakeCredentialStore implements SshCredentialStore {
  _FakeCredentialStore({
    this.initialSecrets = const SshProfileSecrets(),
    this.secretsByProfileId = const {},
  });

  final SshProfileSecrets initialSecrets;
  final Map<String, SshProfileSecrets> secretsByProfileId;
  final loadedProfileIds = <String>[];
  final savedProfileIds = <String>[];
  final savedSecrets = <SshProfileSecrets>[];
  final deletedProfileIds = <String>[];

  @override
  Future<SshProfileSecrets> loadSecrets(String profileId) async {
    loadedProfileIds.add(profileId);
    return secretsByProfileId[profileId] ?? initialSecrets;
  }

  @override
  Future<void> saveSecrets(String profileId, SshProfile profile) async {
    savedProfileIds.add(profileId);
    savedSecrets.add(
      SshProfileSecrets(
        password: profile.password,
        privateKeyPem: profile.privateKeyPem,
        passphrase: profile.passphrase,
      ),
    );
  }

  @override
  Future<void> deleteSecrets(String profileId) async {
    deletedProfileIds.add(profileId);
  }
}
