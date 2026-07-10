import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ssh_credential_store.dart';
import 'ssh_profile.dart';

class FlutterSecureStorageSshCredentialStore implements SshCredentialStore {
  const FlutterSecureStorageSshCredentialStore({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;

  @override
  Future<SshProfileSecrets> loadSecrets(String profileId) async {
    return SshProfileSecrets(
      password: await storage.read(key: _key(profileId, 'password')),
      privateKeyPem: await storage.read(key: _key(profileId, 'privateKeyPem')),
      passphrase: await storage.read(key: _key(profileId, 'passphrase')),
    );
  }

  @override
  Future<void> saveSecrets(String profileId, SshProfile profile) async {
    await _writeOrDelete(_key(profileId, 'password'), profile.password);
    await _writeOrDelete(
      _key(profileId, 'privateKeyPem'),
      profile.privateKeyPem,
    );
    await _writeOrDelete(_key(profileId, 'passphrase'), profile.passphrase);
  }

  @override
  Future<void> deleteSecrets(String profileId) async {
    await storage.delete(key: _key(profileId, 'password'));
    await storage.delete(key: _key(profileId, 'privateKeyPem'));
    await storage.delete(key: _key(profileId, 'passphrase'));
  }

  Future<void> _writeOrDelete(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await storage.delete(key: key);
      return;
    }
    await storage.write(key: key, value: value);
  }

  String _key(String profileId, String field) =>
      'sadcoder.ssh.$profileId.$field';
}
