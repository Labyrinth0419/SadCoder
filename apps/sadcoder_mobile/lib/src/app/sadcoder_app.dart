import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../accounts/account_snapshot_controller.dart';
import '../appearance/app_appearance_controller.dart';
import '../approvals/approval_state_controller.dart';
import '../background/background_connection_policy.dart';
import '../background/background_notification_router.dart';
import '../commands/slash_command_manifest_reader.dart';
import '../config/codex_config_override_controller.dart';
import '../i18n/app_localizations.dart';
import '../mcp/mcp_server_status_controller.dart';
import '../session/codex_session_state_controller.dart';
import '../session/host_session_manager.dart';
import '../ssh/ssh_profile_store.dart';
import '../threads/thread_cache_store.dart';
import '../threads/thread_item_cache_store.dart';
import '../threads/thread_timeline_cursor_store.dart';
import '../theme/sadcoder_theme.dart';
import '../usage/account_usage_snapshot_controller.dart';
import '../usage/thread_token_usage_controller.dart';
import 'app_shell.dart';

class SadCoderApp extends StatefulWidget {
  const SadCoderApp({
    super.key,
    this.locale,
    this.appearanceController,
    this.approvalController,
    this.sessionController,
    this.hostSessionManager,
    this.configOverrideController,
    this.backgroundConnectionPreferences,
    this.backgroundConnectionKeeper,
    this.backgroundNotificationRouter,
    this.profileStore,
    this.slashCommandManifestReader,
    this.accountSnapshotController,
    this.accountUsageSnapshotController,
    this.mcpServerStatusController,
    this.threadTokenUsageController,
    this.threadCacheStore,
    this.threadItemCacheStore,
    this.threadTimelineCursorStore,
  });

  final Locale? locale;
  final AppAppearanceController? appearanceController;
  final ApprovalStateController? approvalController;
  final CodexSessionStateController? sessionController;
  final HostSessionManager? hostSessionManager;
  final CodexConfigOverrideController? configOverrideController;
  final BackgroundConnectionPreferences? backgroundConnectionPreferences;
  final BackgroundConnectionKeeper? backgroundConnectionKeeper;
  final BackgroundNotificationRouter? backgroundNotificationRouter;
  final SshProfileStore? profileStore;
  final SlashCommandManifestReader? slashCommandManifestReader;
  final AccountSnapshotController? accountSnapshotController;
  final AccountUsageSnapshotController? accountUsageSnapshotController;
  final McpServerStatusController? mcpServerStatusController;
  final ThreadTokenUsageController? threadTokenUsageController;
  final ThreadCacheStore? threadCacheStore;
  final ThreadItemCacheStore? threadItemCacheStore;
  final ThreadTimelineCursorStore? threadTimelineCursorStore;

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
        final fontSize = _appearanceController.fontSize;
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
            fontSize: fontSize,
          ),
          darkTheme: sadCoderThemeData(
            colorPalette: colorPalette,
            brightness: Brightness.dark,
            fontSize: fontSize,
          ),
          home: AppShell(
            appearanceController: _appearanceController,
            approvalController: widget.approvalController,
            sessionController: widget.sessionController,
            hostSessionManager: widget.hostSessionManager,
            configOverrideController: widget.configOverrideController,
            backgroundConnectionPreferences:
                widget.backgroundConnectionPreferences,
            backgroundConnectionKeeper: widget.backgroundConnectionKeeper,
            backgroundNotificationRouter: widget.backgroundNotificationRouter,
            profileStore: widget.profileStore,
            slashCommandManifestReader: widget.slashCommandManifestReader,
            accountSnapshotController: widget.accountSnapshotController,
            accountUsageSnapshotController:
                widget.accountUsageSnapshotController,
            mcpServerStatusController: widget.mcpServerStatusController,
            threadTokenUsageController: widget.threadTokenUsageController,
            threadCacheStore: widget.threadCacheStore,
            threadItemCacheStore: widget.threadItemCacheStore,
            threadTimelineCursorStore: widget.threadTimelineCursorStore,
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
