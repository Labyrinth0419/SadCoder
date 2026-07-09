import 'package:flutter/material.dart';

import 'src/app/sadcoder_app.dart';
import 'src/ssh/flutter_secure_storage_ssh_credential_store.dart';
import 'src/ssh/secure_ssh_profile_store.dart';
import 'src/ssh/shared_preferences_ssh_profile_store.dart';

void main() {
  runApp(
    const SadCoderApp(
      profileStore: SecureSshProfileStore(
        metadataStore: SharedPreferencesSshProfileStore(),
        credentialStore: FlutterSecureStorageSshCredentialStore(),
      ),
    ),
  );
}
