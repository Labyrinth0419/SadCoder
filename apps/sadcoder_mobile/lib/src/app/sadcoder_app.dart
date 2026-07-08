import 'package:flutter/material.dart';

import 'app_shell.dart';

class SadCoderApp extends StatelessWidget {
  const SadCoderApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E);

    return MaterialApp(
      title: 'SadCoder',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      home: const AppShell(),
    );
  }
}
