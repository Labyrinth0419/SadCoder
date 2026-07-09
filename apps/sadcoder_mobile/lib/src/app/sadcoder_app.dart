import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../appearance/app_appearance_controller.dart';
import '../approvals/approval_state_controller.dart';
import '../i18n/app_localizations.dart';
import '../session/codex_session_state_controller.dart';
import '../ssh/ssh_profile_store.dart';
import 'app_shell.dart';

class SadCoderApp extends StatefulWidget {
  const SadCoderApp({
    super.key,
    this.locale,
    this.appearanceController,
    this.approvalController,
    this.sessionController,
    this.profileStore,
  });

  final Locale? locale;
  final AppAppearanceController? appearanceController;
  final ApprovalStateController? approvalController;
  final CodexSessionStateController? sessionController;
  final SshProfileStore? profileStore;

  @override
  State<SadCoderApp> createState() => _SadCoderAppState();
}

class _SadCoderAppState extends State<SadCoderApp> {
  late AppAppearanceController _appearanceController;
  late bool _ownsAppearanceController;

  @override
  void initState() {
    super.initState();
    _setAppearanceController(widget.appearanceController);
  }

  @override
  void didUpdateWidget(SadCoderApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearanceController != widget.appearanceController) {
      if (_ownsAppearanceController) {
        _appearanceController.dispose();
      }
      _setAppearanceController(widget.appearanceController);
    }
  }

  @override
  void dispose() {
    if (_ownsAppearanceController) {
      _appearanceController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E);

    return AnimatedBuilder(
      animation: _appearanceController,
      builder: (context, _) {
        return MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          locale: widget.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          themeMode: _appearanceController.themeMode,
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
            appearanceController: _appearanceController,
            approvalController: widget.approvalController,
            sessionController: widget.sessionController,
            profileStore: widget.profileStore,
          ),
        );
      },
    );
  }

  void _setAppearanceController(AppAppearanceController? controller) {
    _ownsAppearanceController = controller == null;
    _appearanceController = controller ?? AppAppearanceController();
  }
}
