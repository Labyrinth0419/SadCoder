import 'ssh_profile.dart';

class SshProfileSecrets {
  const SshProfileSecrets({this.password, this.privateKeyPem, this.passphrase});

  final String? password;
  final String? privateKeyPem;
  final String? passphrase;

  bool get isEmpty =>
      !_hasText(password) && !_hasText(privateKeyPem) && !_hasText(passphrase);
}

abstract interface class SshCredentialStore {
  Future<SshProfileSecrets> loadSecrets(String profileId);

  Future<void> saveSecrets(String profileId, SshProfile profile);
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
