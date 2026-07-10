import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../appearance/app_appearance_controller.dart';
import '../approvals/approval_state_controller.dart';
import '../background/background_connection_policy.dart';
import '../i18n/app_localizations.dart';
import '../session/codex_session_state_controller.dart';
import '../ssh/ssh_profile_store.dart';
import '../theme/sadcoder_theme.dart';
import 'app_shell.dart';

class SadCoderApp extends StatefulWidget {
  const SadCoderApp({
    super.key,
    this.locale,
    this.appearanceController,
    this.approvalController,
    this.sessionController,
    this.backgroundConnectionPreferences,
    this.backgroundConnectionKeeper,
    this.profileStore,
  });

  final Locale? locale;
  final AppAppearanceController? appearanceController;
  final ApprovalStateController? approvalController;
  final CodexSessionStateController? sessionController;
  final BackgroundConnectionPreferences? backgroundConnectionPreferences;
  final BackgroundConnectionKeeper? backgroundConnectionKeeper;
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
    return AnimatedBuilder(
      animation: _appearanceController,
      builder: (context, _) {
        final colorPalette = _appearanceController.colorPalette;
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
          theme: sadCoderThemeData(
            colorPalette: colorPalette,
            brightness: Brightness.light,
          ),
          darkTheme: sadCoderThemeData(
            colorPalette: colorPalette,
            brightness: Brightness.dark,
          ),
          home: AppShell(
            appearanceController: _appearanceController,
            approvalController: widget.approvalController,
            sessionController: widget.sessionController,
            backgroundConnectionPreferences:
                widget.backgroundConnectionPreferences,
            backgroundConnectionKeeper: widget.backgroundConnectionKeeper,
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
