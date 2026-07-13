import 'flutter_secure_storage_ssh_credential_store.dart';
import 'secure_ssh_profile_store.dart';
import 'shared_preferences_ssh_profile_store.dart';
import 'ssh_profile_store.dart';

const SshProfileListStore defaultSshProfileStore = SecureSshProfileStore(
  metadataStore: SharedPreferencesSshProfileStore(),
  credentialStore: FlutterSecureStorageSshCredentialStore(),
);
