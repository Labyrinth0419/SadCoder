import 'ssh_credential_store.dart';
import 'ssh_profile.dart';
import 'ssh_profile_store.dart';

class SecureSshProfileStore implements SshProfileStore {
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

  @override
  Future<void> saveLastProfile(SshProfile profile) async {
    await metadataStore.saveLastProfile(profile);
    await credentialStore.saveSecrets(profile.id, profile);
  }
}
