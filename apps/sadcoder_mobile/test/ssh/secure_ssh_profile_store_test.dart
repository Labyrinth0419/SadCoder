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
        password: 'secret',
      ),
    );

    expect(metadataStore.savedProfile?.password, 'secret');
    expect(credentialStore.savedProfileIds, ['manual']);
    expect(credentialStore.savedSecrets.single.password, 'secret');
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

class _FakeCredentialStore implements SshCredentialStore {
  _FakeCredentialStore({this.initialSecrets = const SshProfileSecrets()});

  final SshProfileSecrets initialSecrets;
  final loadedProfileIds = <String>[];
  final savedProfileIds = <String>[];
  final savedSecrets = <SshProfileSecrets>[];

  @override
  Future<SshProfileSecrets> loadSecrets(String profileId) async {
    loadedProfileIds.add(profileId);
    return initialSecrets;
  }

  @override
  Future<void> saveSecrets(String profileId, SshProfile profile) async {
    savedProfileIds.add(profileId);
    savedSecrets.add(SshProfileSecrets(password: profile.password));
  }
}
