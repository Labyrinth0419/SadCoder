import 'ssh_credential_store.dart';
import 'ssh_profile.dart';
import 'ssh_profile_store.dart';

class SecureSshProfileStore implements SshProfileListStore {
  const SecureSshProfileStore({
    required this.metadataStore,
    required this.credentialStore,
  });

  final SshProfileStore metadataStore;
  final SshCredentialStore credentialStore;

  @override
  Future<SshProfile?> loadLastProfile() async {
    final profile = await metadataStore.loadLastProfile();
    if (profile == null) {
      return null;
    }
    return _withSecrets(profile);
  }

  @override
  Future<void> saveLastProfile(SshProfile profile) async {
    await metadataStore.saveLastProfile(profile);
    await credentialStore.saveSecrets(profile.id, profile);
  }

  @override
  Future<List<SshProfile>> loadProfiles() async {
    final metadata = metadataStore;
    final List<SshProfile> profiles;
    if (metadata is SshProfileListStore) {
      profiles = await metadata.loadProfiles();
    } else {
      final profile = await metadata.loadLastProfile();
      profiles = profile == null ? const [] : [profile];
    }
    return Future.wait([for (final profile in profiles) _withSecrets(profile)]);
  }

  @override
  Future<void> saveProfile(SshProfile profile) async {
    final metadata = metadataStore;
    if (metadata is SshProfileListStore) {
      await metadata.saveProfile(profile);
    } else {
      await metadata.saveLastProfile(profile);
    }
    await credentialStore.saveSecrets(profile.id, profile);
  }

  Future<SshProfile> _withSecrets(SshProfile profile) async {
    final secrets = await credentialStore.loadSecrets(profile.id);
    if (secrets.isEmpty) {
      return profile;
    }
    return profile.copyWith(
      password: secrets.password,
      privateKeyPem: secrets.privateKeyPem,
      passphrase: secrets.passphrase,
    );
  }
}
