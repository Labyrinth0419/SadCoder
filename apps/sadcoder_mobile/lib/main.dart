import 'package:flutter/material.dart';

import 'src/app/sadcoder_app.dart';
import 'src/ssh/shared_preferences_ssh_profile_store.dart';

void main() {
  runApp(const SadCoderApp(profileStore: SharedPreferencesSshProfileStore()));
}
