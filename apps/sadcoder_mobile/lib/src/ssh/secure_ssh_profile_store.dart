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
    await metadataStore.saveLastProfile(_metadataOnly(profile));
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
    final metadataProfile = _metadataOnly(profile);
    if (metadata is SshProfileListStore) {
      await metadata.saveProfile(metadataProfile);
    } else {
      await metadata.saveLastProfile(metadataProfile);
    }
    await credentialStore.saveSecrets(profile.id, profile);
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    final metadata = metadataStore;
    if (metadata is SshProfileListStore) {
      await metadata.deleteProfile(profileId);
    }
    await credentialStore.deleteSecrets(profileId);
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

SshProfile _metadataOnly(SshProfile profile) {
  return SshProfile(
    id: profile.id,
    name: profile.name,
    host: profile.host,
    port: profile.port,
    username: profile.username,
    authType: profile.authType,
    agentCommand: profile.agentCommand,
    defaultCwd: profile.defaultCwd,
  );
}
