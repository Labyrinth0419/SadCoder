import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../approvals/approval_state_controller.dart';
import '../i18n/app_localizations.dart';
import '../session/codex_session_state_controller.dart';
import 'app_shell.dart';

class SadCoderApp extends StatelessWidget {
  const SadCoderApp({
    super.key,
    this.locale,
    this.approvalController,
    this.sessionController,
  });

  final Locale? locale;
  final ApprovalStateController? approvalController;
  final CodexSessionStateController? sessionController;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E);

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
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
      home: AppShell(
        approvalController: approvalController,
        sessionController: sessionController,
      ),
    );
  }
}
