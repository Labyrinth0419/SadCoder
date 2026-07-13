import 'package:flutter/material.dart';

import 'src/app/sadcoder_app.dart';
import 'src/appearance/persisted_app_appearance_controller.dart';
import 'src/background/background_connection_preferences_store.dart';
import 'src/background/android_background_notification_router.dart';
import 'src/background/android_foreground_connection_keeper.dart';
import 'src/config/codex_config_override_store.dart';
import 'src/ssh/default_ssh_profile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appearanceController = await PersistedAppAppearanceController.load();
  final backgroundConnectionPreferences =
      await PersistedBackgroundConnectionPreferences.load();
  final configOverrideController =
      await PersistedCodexConfigOverrideController.load();
  runApp(
    SadCoderApp(
      appearanceController: appearanceController,
      backgroundConnectionPreferences: backgroundConnectionPreferences,
      configOverrideController: configOverrideController,
      profileStore: defaultSshProfileStore,
      backgroundConnectionKeeper: const AndroidForegroundConnectionKeeper(),
      backgroundNotificationRouter: AndroidBackgroundNotificationRouter(),
    ),
  );
}
