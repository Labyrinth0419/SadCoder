import 'package:flutter/material.dart';

import 'src/app/sadcoder_app.dart';
import 'src/appearance/persisted_app_appearance_controller.dart';
import 'src/background/android_background_notification_router.dart';
import 'src/background/android_foreground_connection_keeper.dart';
import 'src/ssh/flutter_secure_storage_ssh_credential_store.dart';
import 'src/ssh/secure_ssh_profile_store.dart';
import 'src/ssh/shared_preferences_ssh_profile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appearanceController = await PersistedAppAppearanceController.load();
  runApp(
    SadCoderApp(
      appearanceController: appearanceController,
      profileStore: const SecureSshProfileStore(
        metadataStore: SharedPreferencesSshProfileStore(),
        credentialStore: FlutterSecureStorageSshCredentialStore(),
      ),
      backgroundConnectionKeeper: const AndroidForegroundConnectionKeeper(),
      backgroundNotificationRouter: AndroidBackgroundNotificationRouter(),
    ),
  );
}
