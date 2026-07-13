import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sadcoder_mobile/src/ssh/default_ssh_profile_store.dart';
import 'package:sadcoder_mobile/src/ssh/flutter_secure_storage_ssh_credential_store.dart';
import 'package:sadcoder_mobile/src/ssh/secure_ssh_profile_store.dart';
import 'package:sadcoder_mobile/src/ssh/shared_preferences_ssh_profile_store.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_credential_store.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile_store.dart';

void main() {
  test('default store keeps metadata and secrets in separate backends', () {
    expect(defaultSshProfileStore, isA<SecureSshProfileStore>());
    final store = defaultSshProfileStore as SecureSshProfileStore;

    expect(store.metadataStore, isA<SharedPreferencesSshProfileStore>());
    expect(
      store.credentialStore,
      isA<FlutterSecureStorageSshCredentialStore>(),
    );
  });

  test('combines profile metadata with securely stored secrets', () async {
    final metadataStore = _FakeProfileStore(
      initialProfile: const SshProfile(
        id: 'manual',
        name: 'Dev',
        host: 'srv.dev',
        username: 'alice',
        password: 'stale-metadata-secret',
        privateKeyPem: 'stale-metadata-key',
        passphrase: 'stale-metadata-passphrase',
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
    expect(profile?.privateKeyPem, isNull);
    expect(profile?.passphrase, isNull);
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

  test(
    'SharedPreferences metadata does not contain imported secrets',
    () async {
      SharedPreferences.setMockInitialValues({});
      const importedPrivateKey = '''-----BEGIN OPENSSH PRIVATE KEY-----
private-key-body
-----END OPENSSH PRIVATE KEY-----''';
      final credentialStore = _FakeCredentialStore();
      final store = SecureSshProfileStore(
        metadataStore: const SharedPreferencesSshProfileStore(),
        credentialStore: credentialStore,
      );

      await store.saveProfile(
        const SshProfile(
          id: 'alice@srv.dev:22#Dev',
          name: 'Dev',
          host: 'srv.dev',
          username: 'alice',
          authType: SshAuthType.privateKey,
          password: 'password-secret',
          privateKeyPem: importedPrivateKey,
          passphrase: 'passphrase-secret',
        ),
      );

      final preferences = await SharedPreferences.getInstance();
      final rawMetadata = [
        for (final key in preferences.getKeys()) '$key=${preferences.get(key)}',
      ].join('\n');

      expect(rawMetadata, contains('srv.dev'));
      expect(rawMetadata, isNot(contains('password-secret')));
      expect(rawMetadata, isNot(contains('PRIVATE KEY')));
      expect(rawMetadata, isNot(contains('passphrase-secret')));

      final reloadedStore = SecureSshProfileStore(
        metadataStore: const SharedPreferencesSshProfileStore(),
        credentialStore: credentialStore,
      );
      final loadedProfiles = await reloadedStore.loadProfiles();

      expect(loadedProfiles.single.privateKeyPem, importedPrivateKey);
      expect(loadedProfiles.single.password, 'password-secret');
      expect(loadedProfiles.single.passphrase, 'passphrase-secret');
    },
  );
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
    Map<String, SshProfileSecrets> secretsByProfileId = const {},
  }) : _secretsByProfileId = Map.of(secretsByProfileId);

  final SshProfileSecrets initialSecrets;
  final Map<String, SshProfileSecrets> _secretsByProfileId;
  final loadedProfileIds = <String>[];
  final savedProfileIds = <String>[];
  final savedSecrets = <SshProfileSecrets>[];
  final deletedProfileIds = <String>[];

  @override
  Future<SshProfileSecrets> loadSecrets(String profileId) async {
    loadedProfileIds.add(profileId);
    return _secretsByProfileId[profileId] ?? initialSecrets;
  }

  @override
  Future<void> saveSecrets(String profileId, SshProfile profile) async {
    savedProfileIds.add(profileId);
    final secrets = SshProfileSecrets(
      password: profile.password,
      privateKeyPem: profile.privateKeyPem,
      passphrase: profile.passphrase,
    );
    savedSecrets.add(secrets);
    _secretsByProfileId[profileId] = secrets;
  }

  @override
  Future<void> deleteSecrets(String profileId) async {
    deletedProfileIds.add(profileId);
    _secretsByProfileId.remove(profileId);
  }
}
