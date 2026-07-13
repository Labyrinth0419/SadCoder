import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../accounts/account_snapshot_controller.dart';
import '../../appearance/app_appearance_controller.dart';
import '../../approvals/approval_request_mapper.dart';
import '../../approvals/pending_approval.dart';
import '../../commands/slash_command_action_dispatcher.dart';
import '../../commands/slash_command_registry.dart';
import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../config/codex_config_snapshot_controller.dart';
import '../../files/file_search_reader.dart';
import '../../i18n/app_localizations.dart';
import '../../mcp/mcp_server_status_controller.dart';
import '../../mcp/mcp_server_status_reader.dart';
import '../../models/model_labels.dart';
import '../../models/model_list_controller.dart';
import '../../models/model_list_reader.dart';
import '../../permissions/permission_profile_list_controller.dart';
import '../../permissions/permission_profile_list_reader.dart';
import '../../plugins/plugin_list_reader.dart';
import '../../reviews/thread_review_command.dart';
import '../../security/permission_risk.dart';
import '../../session/codex_session_state_controller.dart';
import '../../session/host_session_summary.dart';
import '../../ssh/ssh_profile.dart';
import '../../ssh/ssh_profile_store.dart';
import '../../theme/sadcoder_theme.dart';
import '../../threads/agent_thread_topology.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_list_controller.dart';
import '../../threads/thread_mutation_runner.dart';
import '../../threads/thread_summary.dart';
import '../../turns/turn_controller.dart';
import '../../turns/turn_text_element.dart';
import '../../usage/account_usage_snapshot_controller.dart';
import '../../usage/thread_token_usage_controller.dart';
import 'raw_rpc_panel.dart';
import '../appearance/app_color_palette_picker.dart';
import '../diffs/diff_text_block.dart';
import '../files/file_search_sheet.dart';
import '../files/workspace_markdown_preview.dart';
import 'chat_apps_summary.dart';
import 'chat_background_terminal_summary.dart';
import 'chat_debug_config_summary.dart';
import 'chat_display_settings_sheets.dart';
import 'chat_diff_summary.dart';
import 'chat_experimental_summary.dart';
import 'chat_hooks_summary.dart';
import 'chat_memories_summary.dart';
import 'chat_plugins_summary.dart';
import 'chat_skills_summary.dart';
import 'chat_status_summary.dart';
import 'chat_timeline_controller.dart';
import 'chat_goal_summary.dart';
import 'chat_mcp_summary.dart';
import 'chat_review_summary.dart';
import 'chat_summary_formatting.dart';
import 'chat_usage_summary.dart';
import 'config_override_controls.dart';
import 'config_override_labels.dart';
import 'session_override_controls.dart';
import 'slash_command_palette.dart';
import 'turn_override_controls.dart';

typedef ChatProfileConnector = Future<void> Function(SshProfile profile);

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.registry = const SlashCommandRegistry(),
    this.sessionController,
    this.threadListController,
    this.threadDetailController,
    this.turnController,
    this.timelineController,
    this.appearanceController,
    this.configOverrideController,
    this.configSnapshotController,
    this.accountSnapshotController,
    this.accountUsageSnapshotController,
    this.mcpServerStatusController,
    this.threadTokenUsageController,
    this.modelListController,
    this.permissionProfileListController,
    this.profileStore,
    this.hostSessions = const [],
    this.profileConnector,
    this.slashCommandDispatcher,
  });

  final SlashCommandRegistry registry;
  final CodexSessionStateController? sessionController;
  final ThreadListController? threadListController;
  final ThreadDetailController? threadDetailController;
  final TurnController? turnController;
  final ChatTimelineController? timelineController;
  final AppAppearanceController? appearanceController;
  final CodexConfigOverrideController? configOverrideController;
  final CodexConfigSnapshotController? configSnapshotController;
  final AccountSnapshotController? accountSnapshotController;
  final AccountUsageSnapshotController? accountUsageSnapshotController;
  final McpServerStatusController? mcpServerStatusController;
  final ThreadTokenUsageController? threadTokenUsageController;
  final ModelListController? modelListController;
  final PermissionProfileListController? permissionProfileListController;
  final SshProfileStore? profileStore;
  final List<HostSessionSummary> hostSessions;
  final ChatProfileConnector? profileConnector;
  final SlashCommandActionDispatcher? slashCommandDispatcher;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  SlashCommandParseResult _slashCommand =
      const SlashCommandParseResult.notSlash();
  final TextEditingController _composerController = TextEditingController();
  final List<_ComposerMention> _composerMentions = [];
  _SideConversation? _sideConversation;
  CodexSessionStatus? _lastSessionStatus;
  String? _slashTextPrompt;
  bool _slashPaletteOpen = false;
  bool _showRawTranscript = false;
  bool _showArchivedThreads = false;
  bool _showThreadSidebar = false;
  List<SshProfile> _savedProfiles = const [];
  String? _selectedProfileId;
  Object? _profileLoadError;

  @override
  void initState() {
    super.initState();
    widget.sessionController?.addListener(_handleSessionChanged);
    widget.turnController?.addListener(_handleTurnChanged);
    widget.appearanceController?.addListener(_handleAppearanceChanged);
    _lastSessionStatus = widget.sessionController?.status;
    unawaited(_loadSavedProfiles());
    _refreshThreadsIfConnected();
  }

  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionController != widget.sessionController) {
      oldWidget.sessionController?.removeListener(_handleSessionChanged);
      widget.sessionController?.addListener(_handleSessionChanged);
      _lastSessionStatus = widget.sessionController?.status;
      _refreshThreadsIfConnected();
    }
    if (oldWidget.turnController != widget.turnController) {
      oldWidget.turnController?.removeListener(_handleTurnChanged);
      widget.turnController?.addListener(_handleTurnChanged);
    }
    if (oldWidget.appearanceController != widget.appearanceController) {
      oldWidget.appearanceController?.removeListener(_handleAppearanceChanged);
      widget.appearanceController?.addListener(_handleAppearanceChanged);
    }
    if (oldWidget.profileStore != widget.profileStore) {
      unawaited(_loadSavedProfiles());
    }
  }

  @override
  void dispose() {
    widget.sessionController?.removeListener(_handleSessionChanged);
    widget.turnController?.removeListener(_handleTurnChanged);
    widget.appearanceController?.removeListener(_handleAppearanceChanged);
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sessionController = widget.sessionController;
    final threadListController = widget.threadListController;
    final threadDetailController = widget.threadDetailController;
    final turnController = widget.turnController;
    final isConnected =
        sessionController?.status == CodexSessionStatus.connected;
    final canSend = _canSubmitComposerText(
      _composerController.text,
      isConnected: isConnected,
      turnController: turnController,
    );
    final composerSendShortcut =
        widget.appearanceController?.composerSendShortcut ??
        AppComposerSendShortcut.enter;
    final sendSlashAsText = _isSlashTextPrompt(
      _composerController.text,
      _slashCommand,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeight = constraints.maxHeight < 240;
        return Column(
          children: [
            if (!compactHeight) ...[
              _ChatActivityStrip(
                sidebarVisible: _showThreadSidebar,
                onToggleSidebar: _toggleThreadSidebar,
                sessionController: sessionController,
                turnController: turnController,
                timelineController: widget.timelineController,
                statusLineParts: _chatStatusLineParts(l10n),
                connectionControls: _ChatConnectionControls(
                  profiles: _headerProfiles(),
                  selectedProfile: _selectedHeaderProfile(),
                  connectedProfile: sessionController?.profile,
                  hostSessions: widget.hostSessions,
                  status: sessionController?.status ?? CodexSessionStatus.idle,
                  connectionLabel: _connectionLabel(
                    l10n,
                    sessionController?.status,
                  ),
                  profileLoadError: _profileLoadError,
                  onProfileSelected:
                      sessionController == null &&
                          widget.profileConnector == null
                      ? null
                      : _selectHeaderProfile,
                ),
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, bodyConstraints) {
                  final overlaySidebar = bodyConstraints.maxWidth < 720;
                  final sidebarVisible = _showThreadSidebar && !compactHeight;
                  final sidebarWidth = _sidebarWidthFor(
                    bodyConstraints.maxWidth,
                  );
                  return Stack(
                    children: [
                      Positioned.fill(
                        left: sidebarVisible && !overlaySidebar
                            ? sidebarWidth
                            : 0,
                        child: _ChatMainConversation(
                          compact: compactHeight,
                          sideConversation: _sideConversation,
                          canReturnToMain:
                              widget.turnController?.canSubmit == true,
                          onReturnToMain: _returnToMainThread,
                          timelineController: widget.timelineController,
                          showRawTranscript: _showRawTranscript,
                        ),
                      ),
                      if (sidebarVisible)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 0,
                          width: sidebarWidth,
                          child: _ChatThreadSidebar(
                            overlay: overlaySidebar,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _ChatSidebarWorkspaceHeader(
                                  workspace: _workspaceSummary(l10n),
                                  onOpenAdvanced:
                                      widget.configOverrideController != null ||
                                          widget.sessionController != null
                                      ? _showAdvancedControlsSheet
                                      : null,
                                ),
                                const SizedBox(height: 10),
                                _ThreadListPanel(
                                  controller: threadListController,
                                  detailController: threadDetailController,
                                  archived: _showArchivedThreads,
                                  onArchivedChanged: _setThreadArchiveView,
                                  onUnarchiveThread: _unarchiveThread,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                key: const ValueKey('chat-composer-chrome'),
                padding: EdgeInsets.fromLTRB(
                  compactHeight ? 8 : 10,
                  compactHeight ? 4 : 8,
                  compactHeight ? 8 : 10,
                  compactHeight ? 4 : 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        key: const ValueKey('chat-composer-command-preview'),
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: _SlashCommandPreview(
                          result: _slashCommand,
                          sendAsText: sendSlashAsText,
                          onSendAsText: _markSlashInputAsText,
                        ),
                      ),
                    ),
                    CallbackShortcuts(
                      bindings: <ShortcutActivator, VoidCallback>{
                        if (composerSendShortcut ==
                            AppComposerSendShortcut.enter)
                          const SingleActivator(LogicalKeyboardKey.enter): () {
                            if (canSend) {
                              unawaited(_sendComposerText());
                            }
                          },
                        if (composerSendShortcut ==
                            AppComposerSendShortcut.ctrlEnter) ...{
                          const SingleActivator(
                            LogicalKeyboardKey.enter,
                            control: true,
                          ): () {
                            if (canSend) {
                              unawaited(_sendComposerText());
                            }
                          },
                          const SingleActivator(
                            LogicalKeyboardKey.enter,
                            meta: true,
                          ): () {
                            if (canSend) {
                              unawaited(_sendComposerText());
                            }
                          },
                        },
                      },
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: compactHeight ? 112 : 172,
                        ),
                        child: TextField(
                          key: const ValueKey('chat-composer-field'),
                          controller: _composerController,
                          onChanged: _handleComposerChanged,
                          keyboardType: TextInputType.multiline,
                          minLines: 1,
                          maxLines: compactHeight ? 3 : null,
                          textAlignVertical: TextAlignVertical.top,
                          scrollPhysics: const ClampingScrollPhysics(),
                          textInputAction: TextInputAction.newline,
                          onSubmitted:
                              composerSendShortcut ==
                                      AppComposerSendShortcut.enter &&
                                  canSend
                              ? (_) => unawaited(_sendComposerText())
                              : null,
                          decoration: InputDecoration(
                            hintText: l10n.connectBeforeTurn,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            prefixIcon: IconButton(
                              key: const ValueKey('chat-slash-command-button'),
                              onPressed: _openSlashCommandPalette,
                              icon: const Icon(Icons.manage_search),
                              tooltip: l10n.slashCommands,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: const ValueKey(
                                    'chat-composer-stop-button',
                                  ),
                                  onPressed:
                                      turnController?.canInterrupt == true
                                      ? _interruptActiveTurn
                                      : null,
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  tooltip: l10n.interruptTurn,
                                ),
                                IconButton(
                                  key: const ValueKey(
                                    'chat-composer-send-button',
                                  ),
                                  onPressed: canSend ? _sendComposerText : null,
                                  icon: const Icon(Icons.send),
                                  tooltip: l10n.send,
                                ),
                              ],
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleThreadSidebar() {
    setState(() => _showThreadSidebar = !_showThreadSidebar);
  }

  void _handleComposerChanged(String value) {
    _pruneComposerMentions(value);
    final result = widget.registry.parseComposerText(value);
    setState(() {
      if (_slashTextPrompt != value) {
        _slashTextPrompt = null;
      }
      _slashCommand = result;
    });
    if (result.kind == SlashCommandParseKind.empty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_openSlashCommandPalette());
        }
      });
    }
  }

  Future<void> _openSlashCommandPalette() async {
    if (_slashPaletteOpen) {
      return;
    }
    _slashPaletteOpen = true;
    try {
      await showSlashCommandPalette(
        context: context,
        registry: widget.registry,
        hasActiveTurn: widget.turnController?.activeTurnId != null,
        isSideConversation: _sideConversation != null,
        showUnavailableCommands:
            widget.appearanceController?.showUnavailableSlashCommands ?? false,
        onSelected: _selectSlashCommand,
      );
    } finally {
      _slashPaletteOpen = false;
    }
  }

  void _selectSlashCommand(SlashCommandSpec command) {
    final text = command.supportsInlineArgs
        ? '${command.slash} '
        : command.slash;
    _composerMentions.clear();
    _slashTextPrompt = null;
    _composerController.text = text;
    _composerController.selection = TextSelection.collapsed(
      offset: text.length,
    );
    _handleComposerChanged(text);
  }

  Future<void> _sendComposerText() async {
    final text = _composerController.text;
    final parsed = widget.registry.parseComposerText(text);
    final sendSlashAsText = _isSlashTextPrompt(text, parsed);
    if (!_canSubmitComposerText(
      text,
      isConnected: widget.sessionController?.isConnected == true,
      turnController: widget.turnController,
    )) {
      return;
    }
    if (_isShellCommandInput(text)) {
      await _sendShellCommand(text);
      return;
    }
    if (parsed.kind != SlashCommandParseKind.notSlash && !sendSlashAsText) {
      await _dispatchSlashCommand(parsed);
      return;
    }

    final turnController = widget.turnController;
    if (turnController == null) {
      return;
    }
    final textElements = _composerTextElements(text);
    final steeringActiveTurn =
        turnController.canSteer && !turnController.canSubmit;
    if (steeringActiveTurn) {
      await turnController.steerActiveTurn(text, textElements: textElements);
    } else {
      await turnController.submitText(text, textElements: textElements);
    }
    if (turnController.status != TurnControllerStatus.failed) {
      _syncActiveTurnToTimeline(submittedText: text);
      if (!steeringActiveTurn) {
        widget.configOverrideController?.clearTurn();
      }
      _composerMentions.clear();
      _slashTextPrompt = null;
      _composerController.clear();
      _handleComposerChanged('');
    }
  }

  Future<void> _sendShellCommand(String text) async {
    final command = _shellCommandFromInput(text);
    final runner = widget.sessionController?.threadShellCommandRunner;
    final threadId = _nonEmptyText(widget.turnController?.activeThreadId);
    if (command == null || runner == null || threadId == null) {
      return;
    }

    try {
      await runner.runShellCommand(threadId: threadId, command: command);
      _composerMentions.clear();
      _slashTextPrompt = null;
      _composerController.clear();
      _handleComposerChanged('');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      _showChatSnackBar(
        context.l10n.messageWithDetail(context.l10n.shellCommandFailed, error),
      );
    }
  }

  void _showChatSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
      ),
    );
  }

  void _markSlashInputAsText() {
    final text = _composerController.text;
    final parsed = widget.registry.parseComposerText(text);
    if (parsed.kind == SlashCommandParseKind.notSlash ||
        parsed.kind == SlashCommandParseKind.empty) {
      return;
    }
    setState(() => _slashTextPrompt = text);
  }

  Future<void> _interruptActiveTurn() async {
    await widget.turnController?.interruptActiveTurn();
  }

  Future<void> _loadSavedProfiles() async {
    final store = widget.profileStore;
    if (store == null) {
      if (mounted) {
        setState(() {
          _savedProfiles = const [];
          _selectedProfileId = widget.sessionController?.profile?.id;
          _profileLoadError = null;
        });
      }
      return;
    }

    try {
      late final List<SshProfile> profiles;
      if (store is SshProfileListStore) {
        profiles = await store.loadProfiles();
      } else {
        final profile = await store.loadLastProfile();
        profiles = [?profile];
      }
      if (!mounted || store != widget.profileStore) {
        return;
      }
      setState(() {
        _savedProfiles = List.unmodifiable(profiles);
        _selectedProfileId = _preferredHeaderProfileId(profiles);
        _profileLoadError = null;
      });
    } on Object catch (error) {
      if (!mounted || store != widget.profileStore) {
        return;
      }
      setState(() {
        _savedProfiles = const [];
        _selectedProfileId = widget.sessionController?.profile?.id;
        _profileLoadError = error;
      });
    }
  }

  String? _preferredHeaderProfileId(List<SshProfile> profiles) {
    final connectedProfile = widget.sessionController?.profile;
    if (connectedProfile != null) {
      return connectedProfile.id;
    }
    final selectedProfileId = _selectedProfileId;
    if (selectedProfileId != null &&
        profiles.any((profile) => profile.id == selectedProfileId)) {
      return selectedProfileId;
    }
    return profiles.isEmpty ? null : profiles.first.id;
  }

  List<SshProfile> _headerProfiles() {
    final connectedProfile = widget.sessionController?.profile;
    final profiles = <SshProfile>[
      ..._savedProfiles,
      for (final session in widget.hostSessions) session.profile,
      ?connectedProfile,
    ];
    final seen = <String>{};
    return List.unmodifiable(
      profiles.where((profile) => seen.add(profile.id)).toList(),
    );
  }

  SshProfile? _selectedHeaderProfile() {
    final selectedId =
        widget.sessionController?.profile?.id ?? _selectedProfileId;
    if (selectedId == null) {
      return null;
    }
    return _profileById(_headerProfiles(), selectedId);
  }

  SshProfile? _profileById(List<SshProfile> profiles, String profileId) {
    for (final profile in profiles) {
      if (profile.id == profileId) {
        return profile;
      }
    }
    return null;
  }

  Future<void> _selectHeaderProfile(SshProfile profile) async {
    setState(() {
      _selectedProfileId = profile.id;
      _profileLoadError = null;
    });

    final connector = widget.profileConnector;
    final sessionController = widget.sessionController;
    if (connector == null && sessionController == null) {
      return;
    }
    if (sessionController?.status == CodexSessionStatus.connected &&
        sessionController?.profile?.id == profile.id) {
      return;
    }

    try {
      if (connector != null) {
        await connector(profile);
      } else {
        await sessionController!.connect(profile);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      _showChatSnackBar(
        context.l10n.messageWithDetail(context.l10n.connectionFailed, error),
      );
    }
  }

  Future<void> _dispatchSlashCommand(SlashCommandParseResult parsed) async {
    final result = await _slashCommandDispatcher().dispatch(
      parsed,
      hasActiveTurn: widget.turnController?.activeTurnId != null,
      isSideConversation: _sideConversation != null,
    );
    if (!mounted) {
      return;
    }
    if (result.outcome == SlashCommandActionOutcome.ignored) {
      return;
    }
    final preservesComposer =
        result.effect == SlashCommandActionEffect.mention ||
        result.effect == SlashCommandActionEffect.ideContext;
    if (result.outcome == SlashCommandActionOutcome.executed &&
        !preservesComposer) {
      _composerMentions.clear();
      _composerController.clear();
      _handleComposerChanged('');
    }
    if (result.outcome == SlashCommandActionOutcome.executed &&
        result.effect == SlashCommandActionEffect.mention) {
      return;
    }
    _showChatSnackBar(_slashCommandResultMessage(context.l10n, result));
  }

  SlashCommandActionDispatcher _slashCommandDispatcher() {
    return widget.slashCommandDispatcher ??
        SlashCommandActionDispatcher(
          disconnect: widget.sessionController?.disconnect,
          clearTranscript: _clearLocalTranscript,
          copyLastResponse: _copyLastResponse,
          showStatus: _buildStatusSummary,
          showUsage: _buildUsageSummary,
          showMcp: _buildMcpSummary,
          showSkills: _buildSkillsSummary,
          showPlugins: _buildPluginsSummary,
          showHooks: _buildHooksSummary,
          showApps: _buildAppsSummary,
          showDebugConfig: _buildDebugConfigSummary,
          showExperimental: _buildExperimentalSummary,
          showMemories: _buildMemoriesSummary,
          showRollout: _buildRolloutSummary,
          testApproval: _testApprovalRequest,
          showDiff: _buildDiffSummary,
          handleGoal: _handleGoalCommand,
          handleReview: _handleReviewCommand,
          approveRecentAutoReviewDenial: _approveRecentAutoReviewDenial,
          showBackgroundTerminals: _buildBackgroundTerminalsSummary,
          cleanBackgroundTerminals: _cleanBackgroundTerminals,
          toggleRawTranscript: _toggleRawTranscript,
          startNewThread: _startNewThread,
          resumeThread: _resumeThread,
          renameThread: _renameThread,
          logout: _logoutAccount,
          submitFeedback: _submitFeedback,
          configureTheme: _configureTheme,
          configureTitleDisplay: _configureTitleDisplay,
          configureStatusLineDisplay: _configureStatusLineDisplay,
          configureKeymap: _configureKeymap,
          toggleComposerVimMode: _toggleComposerVimMode,
          configureTerminalPets: _configureTerminalPets,
          attachIdeContext: _attachIdeContext,
          configurePlanMode: _configurePlanMode,
          mentionFile: _mentionFile,
          startSideConversation: _startSideConversation,
          showAgentTopology: _showAgentTopology,
          forkThread: _forkCurrentThread,
          duplicateThread: _duplicateCurrentThread,
          rewindThread: _rewindCurrentThread,
          compactThread: _compactCurrentThread,
          archiveThread: _archiveCurrentThread,
          deleteThread: _deleteCurrentThread,
          configureModel: _configureModelOverride,
          configurePersonality: _configurePersonalityOverride,
          configurePermissions: _configurePermissionsOverride,
          confirmHighRisk: _confirmHighRiskSlashCommand,
        );
  }

  Future<String> _buildStatusSummary() async {
    final l10n = context.l10n;
    await _refreshStatusSources();
    return buildChatStatusSummary(
      l10n: l10n,
      sessionController: widget.sessionController,
      threadListController: widget.threadListController,
      threadDetailController: widget.threadDetailController,
      turnController: widget.turnController,
      timelineController: widget.timelineController,
      configOverrideController: widget.configOverrideController,
      configSnapshotController: widget.configSnapshotController,
      accountSnapshotController: widget.accountSnapshotController,
      accountUsageSnapshotController: widget.accountUsageSnapshotController,
      threadTokenUsageController: widget.threadTokenUsageController,
    );
  }

  Future<String> _buildUsageSummary() async {
    final l10n = context.l10n;
    final controller = widget.accountUsageSnapshotController;
    if (controller != null) {
      await controller.refresh();
    }
    return buildAccountUsageSummary(
      l10n: l10n,
      controller: controller,
      threadUsage: _currentThreadTokenUsage(),
    );
  }

  Future<String?> _buildMcpSummary(String arguments) async {
    final parts = arguments
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final command = parts.isEmpty ? '' : parts.first.toLowerCase();
    final verbose = parts.length == 1 && command == 'verbose';
    final reload =
        parts.length == 1 && (command == 'reload' || command == 'refresh');
    final oauthLogin =
        parts.length == 2 &&
        (command == 'login' || command == 'oauth' || command == 'auth');
    if (parts.isNotEmpty && !verbose && !reload && !oauthLogin) {
      return null;
    }

    final l10n = context.l10n;
    if (oauthLogin) {
      final runner = widget.sessionController?.mcpServerOAuthRunner;
      if (runner == null) {
        return null;
      }
      final result = await runner.startOAuthLogin(serverName: parts[1]);
      return buildMcpServerOAuthLoginSummary(l10n: l10n, result: result);
    }
    if (reload) {
      final runner = widget.sessionController?.mcpServerConfigRunner;
      if (runner == null) {
        return null;
      }
      await runner.reloadMcpServers();
    }
    final controller = widget.mcpServerStatusController;
    if (controller != null) {
      await controller.refresh(
        threadId: _currentThreadId(),
        limit: 25,
        detail: verbose
            ? McpServerStatusDetail.full
            : McpServerStatusDetail.toolsAndAuthOnly,
      );
    }
    final summary = buildMcpServerStatusSummary(
      l10n: l10n,
      controller: controller,
      verbose: verbose,
    );
    if (reload) {
      return [l10n.mcpServersReloaded, summary].join('\n');
    }
    return summary;
  }

  Future<String?> _buildSkillsSummary(String arguments) async {
    final normalized = arguments.trim().toLowerCase();
    final forceReload = normalized == 'reload' || normalized == 'refresh';
    if (normalized.isNotEmpty && !forceReload) {
      return null;
    }

    final l10n = context.l10n;
    final reader = widget.sessionController?.skillListReader;
    if (reader == null) {
      return [l10n.skillsTitle, l10n.skillsUnavailable].join('\n');
    }

    try {
      final page = await reader.listSkills(
        cwds: _currentWorkspaceCwds(),
        forceReload: forceReload,
      );
      return buildSkillsSummary(l10n: l10n, page: page);
    } on Object catch (error) {
      return [
        l10n.skillsTitle,
        chatSummaryMessageWithOptionalDetail(
          l10n,
          l10n.skillsLoadFailed,
          error,
        ),
      ].join('\n');
    }
  }

  Future<String?> _buildPluginsSummary(String arguments) async {
    final parts = arguments
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final command = parts.isEmpty ? '' : parts.first.toLowerCase();
    final read =
        parts.length == 2 &&
        (command == 'read' || command == 'show' || command == 'detail');
    final install = parts.length == 2 && command == 'install';
    final uninstall =
        parts.length == 2 && (command == 'uninstall' || command == 'remove');
    final marketplaceKinds = _pluginMarketplaceKindsFromArguments(parts);
    if (parts.isNotEmpty &&
        !read &&
        !install &&
        !uninstall &&
        marketplaceKinds == null) {
      return null;
    }

    final l10n = context.l10n;
    final reader = widget.sessionController?.pluginListReader;
    final cwds = _currentWorkspaceCwds();
    if (read) {
      final detailReader = widget.sessionController?.pluginDetailReader;
      if (detailReader == null) {
        return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
      }
      try {
        final detail = await detailReader.readPlugin(
          pluginId: parts[1],
          cwds: cwds,
        );
        return buildPluginDetailSummary(l10n: l10n, detail: detail);
      } on Object catch (error) {
        return [
          l10n.pluginsTitle,
          chatSummaryMessageWithOptionalDetail(
            l10n,
            l10n.pluginsLoadFailed,
            error,
          ),
        ].join('\n');
      }
    }
    if (install || uninstall) {
      final runner = widget.sessionController?.pluginMutationRunner;
      if (runner == null) {
        return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
      }
      try {
        final result = install
            ? await runner.installPlugin(pluginId: parts[1], cwds: cwds)
            : await runner.uninstallPlugin(pluginId: parts[1], cwds: cwds);
        final lines = <String>[
          buildPluginMutationSummary(l10n: l10n, result: result),
        ];
        if (reader != null) {
          final page = await reader.listPlugins(cwds: cwds);
          lines.add(buildPluginsSummary(l10n: l10n, page: page));
        }
        return lines.join('\n');
      } on Object catch (error) {
        return [
          l10n.pluginsTitle,
          chatSummaryMessageWithOptionalDetail(
            l10n,
            l10n.pluginMutationFailed,
            error,
          ),
        ].join('\n');
      }
    }

    if (reader == null) {
      return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
    }

    try {
      final page = await reader.listPlugins(
        cwds: cwds,
        marketplaceKinds: marketplaceKinds ?? const [],
      );
      return buildPluginsSummary(l10n: l10n, page: page);
    } on Object catch (error) {
      return [
        l10n.pluginsTitle,
        chatSummaryMessageWithOptionalDetail(
          l10n,
          l10n.pluginsLoadFailed,
          error,
        ),
      ].join('\n');
    }
  }

  Future<String?> _buildHooksSummary(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }

    final l10n = context.l10n;
    final reader = widget.sessionController?.hookListReader;
    if (reader == null) {
      return [l10n.hooksTitle, l10n.hooksUnavailable].join('\n');
    }

    try {
      final page = await reader.listHooks(cwds: _currentWorkspaceCwds());
      return buildHooksSummary(l10n: l10n, page: page);
    } on Object catch (error) {
      return [
        l10n.hooksTitle,
        chatSummaryMessageWithOptionalDetail(l10n, l10n.hooksLoadFailed, error),
      ].join('\n');
    }
  }

  Future<String?> _buildAppsSummary(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }

    final l10n = context.l10n;
    final reader = widget.sessionController?.appListReader;
    if (reader == null) {
      return [l10n.appsTitle, l10n.appsUnavailable].join('\n');
    }

    try {
      final page = await reader.listApps(
        threadId: _currentThreadId(),
        limit: 25,
      );
      return buildAppsSummary(l10n: l10n, page: page);
    } on Object catch (error) {
      return [
        l10n.appsTitle,
        chatSummaryMessageWithOptionalDetail(l10n, l10n.appsLoadFailed, error),
      ].join('\n');
    }
  }

  Future<String?> _buildDebugConfigSummary(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }

    final l10n = context.l10n;
    final controller = widget.configSnapshotController;
    if (controller != null) {
      final cwds = _currentWorkspaceCwds();
      await controller.refresh(cwd: cwds.isEmpty ? null : cwds.first);
    }
    return buildDebugConfigSummary(l10n: l10n, controller: controller);
  }

  Future<String?> _buildExperimentalSummary(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }

    final l10n = context.l10n;
    final controller = widget.configSnapshotController;
    if (controller != null) {
      final cwds = _currentWorkspaceCwds();
      await controller.refresh(cwd: cwds.isEmpty ? null : cwds.first);
    }
    return buildExperimentalSummary(l10n: l10n, controller: controller);
  }

  Future<String?> _buildMemoriesSummary(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }

    final l10n = context.l10n;
    final controller = widget.configSnapshotController;
    if (controller != null) {
      final cwds = _currentWorkspaceCwds();
      await controller.refresh(cwd: cwds.isEmpty ? null : cwds.first);
    }
    return buildMemoriesSummary(
      l10n: l10n,
      controller: controller,
      threadRaw: widget.threadDetailController?.detail?.thread.raw ?? const {},
    );
  }

  Future<String?> _buildRolloutSummary(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }
    final l10n = context.l10n;
    final rolloutPath = _rolloutPathFromRaw(
      widget.threadDetailController?.detail?.thread.raw ?? const {},
    );
    if (rolloutPath != null) {
      return l10n.slashCommandRolloutCurrentPath(rolloutPath);
    }
    return l10n.slashCommandRolloutPathUnavailable;
  }

  Future<String?> _testApprovalRequest(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }
    final approvalController = widget.sessionController?.approvalController;
    if (approvalController == null) {
      return null;
    }
    final l10n = context.l10n;
    final now = DateTime.now();
    final threadId = _currentThreadId();
    final turnId = widget.turnController?.activeTurnId ?? 'turn-1';
    final reason = l10n.slashCommandTestApprovalReason;
    final rawParams = <String, Object?>{
      'turnId': turnId,
      'startedAtMs': now.millisecondsSinceEpoch,
      'grantRoot': '/tmp',
      'reason': reason,
      'changes': [
        {'path': '/tmp/test.txt', 'kind': 'add', 'content': 'test'},
        {
          'path': '/tmp/test2.txt',
          'kind': 'update',
          'unifiedDiff': '+test\n-test2',
        },
      ],
    };
    if (threadId != null) {
      rawParams['threadId'] = threadId;
    }
    approvalController.upsert(
      PendingApproval(
        requestId: 'debug-test-approval-${now.microsecondsSinceEpoch}',
        method: fileChangeApprovalMethod,
        kind: PendingApprovalKind.fileChange,
        rawParams: rawParams,
        title: '${l10n.approvalKindFileChange}: /tmp',
        threadId: threadId,
        turnId: turnId,
        startedAtMs: now.millisecondsSinceEpoch,
        reason: reason,
        grantRoot: '/tmp',
      ),
    );
    return l10n.slashCommandTestApprovalQueued;
  }

  Future<String?> _buildDiffSummary(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }

    final l10n = context.l10n;
    final reader = widget.sessionController?.gitDiffReader;
    if (reader == null) {
      return [l10n.diffTitle, l10n.diffUnavailable].join('\n');
    }

    try {
      final cwds = _currentWorkspaceCwds();
      final result = await reader.readDiff(
        cwd: cwds.isEmpty ? null : cwds.first,
      );
      return buildGitDiffSummary(l10n: l10n, result: result);
    } on Object catch (error) {
      return [
        l10n.diffTitle,
        chatSummaryMessageWithOptionalDetail(l10n, l10n.diffLoadFailed, error),
      ].join('\n');
    }
  }

  Future<SlashCommandCallbackResult> _mentionFile() async {
    final reader = widget.sessionController?.fileSearchReader;
    final roots = _currentWorkspaceCwds();
    if (reader == null || roots.isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }

    final match = await showModalBottomSheet<FileSearchMatch>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FileSearchSheet(
        reader: reader,
        roots: roots,
        title: context.l10n.mentionCommandTitle,
        searchHint: context.l10n.mentionSearchHint,
      ),
    );
    if (!mounted || match == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    _insertMention(match);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _attachIdeContext(String arguments) async {
    final reader = widget.sessionController?.fileSearchReader;
    final roots = _currentWorkspaceCwds();
    if (reader == null || roots.isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }

    final match = await showModalBottomSheet<FileSearchMatch>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FileSearchSheet(
        reader: reader,
        roots: roots,
        title: context.l10n.ideContextCommandTitle,
        searchHint: context.l10n.ideContextSearchHint,
        initialQuery: arguments.trim(),
      ),
    );
    if (!mounted || match == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    _insertMention(match);
    return SlashCommandCallbackResult.executed;
  }

  void _insertMention(FileSearchMatch match) {
    final token = '@${match.path}';
    final value = _composerController.value;
    final text = value.text;
    final parsed = widget.registry.parseComposerText(text);
    final replaceWholeComposer =
        parsed.kind == SlashCommandParseKind.known &&
        (parsed.command?.command == 'mention' ||
            parsed.command?.command == 'ide');
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: text.length);
    final start = replaceWholeComposer ? 0 : selection.start;
    final end = replaceWholeComposer ? text.length : selection.end;
    final safeStart = start.clamp(0, text.length).toInt();
    final safeEnd = end.clamp(safeStart, text.length).toInt();
    final newText = text.replaceRange(safeStart, safeEnd, token);
    _composerMentions
      ..removeWhere(
        (mention) => mention.start < safeEnd && mention.end > safeStart,
      )
      ..add(
        _ComposerMention(
          token: token,
          start: safeStart,
          end: safeStart + token.length,
        ),
      );
    _composerController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: safeStart + token.length),
    );
    _handleComposerChanged(newText);
  }

  void _pruneComposerMentions(String text) {
    _composerMentions.removeWhere((mention) => !mention.isPresentIn(text));
  }

  List<TurnTextElement> _composerTextElements(String text) {
    return [
      for (final mention in _composerMentions)
        if (mention.isPresentIn(text))
          TurnTextElement.fromCodeUnitRange(
            text: text,
            start: mention.start,
            end: mention.end,
          ),
    ];
  }

  Future<String?> _handleGoalCommand(String arguments) async {
    final runner = widget.sessionController?.threadGoalRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return null;
    }

    final command = _parseGoalCommand(arguments);
    if (command == null) {
      return null;
    }

    final l10n = context.l10n;
    return switch (command) {
      _GoalGetCommand() => buildThreadGoalSummary(
        l10n: l10n,
        goal: (await runner.getGoal(threadId: threadId)).goal,
      ),
      _GoalClearCommand() => buildThreadGoalClearedSummary(
        l10n: l10n,
        cleared: (await runner.clearGoal(threadId: threadId)).cleared,
      ),
      _GoalSetCommand(:final objective, :final status, :final tokenBudget) =>
        buildThreadGoalSummary(
          l10n: l10n,
          goal: (await runner.setGoal(
            threadId: threadId,
            objective: objective,
            status: status,
            tokenBudget: tokenBudget,
          )).goal,
        ),
    };
  }

  Future<String?> _handleReviewCommand(String arguments) async {
    final runner = widget.sessionController?.threadReviewRunner;
    final turnController = widget.turnController;
    final threadId = _currentThreadId();
    if (runner == null || turnController == null || threadId == null) {
      return null;
    }
    if (!turnController.canSubmit) {
      return null;
    }

    final command = parseThreadReviewCommand(arguments);
    if (command == null) {
      return null;
    }

    final l10n = context.l10n;
    final result = await runner.startReview(
      threadId: threadId,
      target: command.target,
      delivery: command.delivery,
    );
    final reviewThreadId = result.reviewThreadId;
    final tracked = turnController.trackStartedTurn(
      threadId: reviewThreadId,
      turn: result.turn,
    );
    if (!tracked) {
      return null;
    }

    widget.timelineController?.showTurn(
      threadId: reviewThreadId,
      turn: result.turn,
    );
    _refreshVisibleThreads();
    unawaited(widget.threadDetailController?.readThread(reviewThreadId));
    return buildThreadReviewStartedSummary(
      l10n: l10n,
      result: result,
      target: command.target,
      delivery: command.delivery,
    );
  }

  Future<SlashCommandCallbackResult> _approveRecentAutoReviewDenial() async {
    final runner = widget.sessionController?.threadMutationRunner;
    final timelineController = widget.timelineController;
    final threadId = _currentThreadId();
    if (runner == null || timelineController == null || threadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final denial = timelineController.latestAutoReviewDenial(
      threadId: threadId,
    );
    if (denial == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    await runner.approveGuardianDeniedAction(threadId: threadId, event: denial);
    timelineController.removeAutoReviewDenial(denial.id);
    return SlashCommandCallbackResult.executed;
  }

  Future<String?> _buildBackgroundTerminalsSummary(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }
    final runner = widget.sessionController?.threadBackgroundTerminalRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return null;
    }
    final l10n = context.l10n;
    final page = await runner.listTerminals(threadId: threadId, limit: 25);
    return buildThreadBackgroundTerminalsSummary(l10n: l10n, page: page);
  }

  Future<String?> _cleanBackgroundTerminals(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }
    final runner = widget.sessionController?.threadBackgroundTerminalRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return null;
    }
    final l10n = context.l10n;
    await runner.cleanTerminals(threadId: threadId);
    return buildThreadBackgroundTerminalsCleanSummary(l10n);
  }

  Future<void> _refreshStatusSources() async {
    final futures = <Future<void>>[];
    final threadId = _currentThreadId();
    final threadDetailController = widget.threadDetailController;
    if (threadId != null && threadDetailController != null) {
      futures.add(
        threadDetailController.readThread(threadId, includeTurns: false),
      );
    }
    final configSnapshotController = widget.configSnapshotController;
    if (configSnapshotController != null) {
      futures.add(
        configSnapshotController.refresh(
          cwd: widget.configOverrideController?.resolved.cwd,
        ),
      );
    }
    final accountSnapshotController = widget.accountSnapshotController;
    if (accountSnapshotController != null) {
      futures.add(accountSnapshotController.refresh());
    }
    final accountUsageSnapshotController =
        widget.accountUsageSnapshotController;
    if (accountUsageSnapshotController != null) {
      futures.add(accountUsageSnapshotController.refresh());
    }
    await Future.wait(futures);
  }

  Future<void> _showAdvancedControlsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ChatAdvancedControlsSheet(
        configOverrideController: widget.configOverrideController,
        rawRpcSender: widget.sessionController?.requestRaw,
        onApplySessionOverrides: _applySessionOverrides,
      ),
    );
  }

  Future<bool> _copyLastResponse() async {
    final markdown = widget.timelineController?.lastAssistantMessageMarkdown();
    if (markdown == null || markdown.isEmpty) {
      return false;
    }
    await Clipboard.setData(ClipboardData(text: markdown));
    return true;
  }

  bool? _toggleRawTranscript(String arguments) {
    final normalized = arguments.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'toggle') {
      setState(() => _showRawTranscript = !_showRawTranscript);
      return _showRawTranscript;
    }
    if (normalized == 'on' || normalized == 'true' || normalized == '1') {
      setState(() => _showRawTranscript = true);
      return true;
    }
    if (normalized == 'off' || normalized == 'false' || normalized == '0') {
      setState(() => _showRawTranscript = false);
      return false;
    }
    return null;
  }

  Future<SlashCommandCallbackResult> _configureModelOverride() async {
    final controller = widget.configOverrideController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    final result = await showModalBottomSheet<_ModelOverrideResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ModelOverrideSheet(
        controller: controller,
        modelListController: widget.modelListController,
      ),
    );
    if (!mounted || result == null) {
      return SlashCommandCallbackResult.cancelled;
    }
    switch (result.scope) {
      case _OverrideScope.turn:
        controller.setTurnModelEffort(
          model: result.model,
          effort: result.effort,
        );
      case _OverrideScope.session:
        controller.setSessionModelEffort(
          model: result.model,
          effort: result.effort,
        );
    }
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _configurePermissionsOverride() async {
    final controller = widget.configOverrideController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    final result = await showModalBottomSheet<_PermissionsOverrideResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PermissionsOverrideSheet(
        controller: controller,
        permissionProfileListController: widget.permissionProfileListController,
      ),
    );
    if (!mounted || result == null) {
      return SlashCommandCallbackResult.cancelled;
    }
    if (_permissionsOverrideIsHighRisk(result)) {
      final confirmed = await _confirmHighRiskPermissionsOverride();
      if (!mounted || !confirmed) {
        return SlashCommandCallbackResult.cancelled;
      }
    }
    switch (result.scope) {
      case _OverrideScope.turn:
        controller.setTurnPermissions(
          approvalPolicy: result.approvalPolicy,
          sandboxPolicy: result.sandboxPolicy,
          permissionProfile: result.permissionProfile,
        );
      case _OverrideScope.session:
        controller.setSessionPermissions(
          approvalPolicy: result.approvalPolicy,
          sandboxPolicy: result.sandboxPolicy,
          permissionProfile: result.permissionProfile,
        );
    }
    return SlashCommandCallbackResult.executed;
  }

  bool _permissionsOverrideIsHighRisk(_PermissionsOverrideResult result) {
    return isHighRiskPermissionState(
      approvalPolicy: result.approvalPolicy,
      sandboxPolicy: result.sandboxPolicy,
      permissionProfile: result.permissionProfile,
    );
  }

  Future<bool> _confirmHighRiskPermissionsOverride() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.permissionsHighRiskConfirmTitle),
        content: Text(l10n.permissionsHighRiskConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.permissionsHighRiskConfirmProceed),
          ),
        ],
      ),
    );
    return mounted && confirmed == true;
  }

  Future<SlashCommandCallbackResult> _configurePersonalityOverride() async {
    final controller = widget.configOverrideController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    final result = await showModalBottomSheet<_PersonalityOverrideResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PersonalityOverrideSheet(controller: controller),
    );
    if (!mounted || result == null) {
      return SlashCommandCallbackResult.cancelled;
    }
    switch (result.scope) {
      case _OverrideScope.turn:
        controller.setTurnPersonality(result.personality);
      case _OverrideScope.session:
        controller.setSessionPersonality(result.personality);
    }
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _configurePlanMode(
    String arguments,
  ) async {
    final controller = widget.configOverrideController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    final prompt = arguments.trim();
    final turnController = widget.turnController;
    if (prompt.isNotEmpty &&
        (turnController == null || !turnController.canSubmit)) {
      return SlashCommandCallbackResult.unavailable;
    }

    final model = await _resolvePlanModeModel();
    if (!mounted || model == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    controller.setTurnCollaborationMode(
      CodexCollaborationModeOverride.plan(model: model),
    );
    if (prompt.isEmpty) {
      return SlashCommandCallbackResult.executed;
    }

    await turnController!.submitText(prompt);
    if (turnController.status == TurnControllerStatus.failed) {
      return SlashCommandCallbackResult.unavailable;
    }
    _syncActiveTurnToTimeline(submittedText: prompt);
    controller.clearTurn();
    return SlashCommandCallbackResult.executed;
  }

  Future<void> _applySessionOverrides(CodexConfigOverrides overrides) async {
    final runner = widget.sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return;
    }
    await runner.updateThreadSettings(threadId: threadId, overrides: overrides);
    _refreshVisibleThreads();
    if (widget.threadDetailController?.selectedThreadId == threadId) {
      unawaited(widget.threadDetailController?.readThread(threadId));
    }
  }

  Future<bool> _startNewThread() async {
    final turnController = widget.turnController;
    if (turnController == null) {
      return false;
    }
    final started = await turnController.startNewThread();
    if (!started) {
      return false;
    }
    _clearSideConversation();
    widget.threadDetailController?.clear();
    widget.timelineController?.selectThread(turnController.activeThreadId);
    _refreshVisibleThreads();
    return true;
  }

  Future<bool> _resumeThread(String threadId) async {
    final turnController = widget.turnController;
    if (turnController == null) {
      return false;
    }
    final resumed = await turnController.resumeThread(threadId);
    if (!resumed) {
      return false;
    }
    final activeThreadId = turnController.activeThreadId;
    if (activeThreadId == null || activeThreadId.isEmpty) {
      return false;
    }
    _clearSideConversation();
    widget.timelineController?.selectThread(activeThreadId);
    unawaited(widget.threadDetailController?.readThread(activeThreadId));
    _refreshVisibleThreads();
    return true;
  }

  Future<bool> _renameThread(String name) async {
    final runner = widget.sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return false;
    }
    await runner.setThreadName(threadId: threadId, name: name);
    _refreshVisibleThreads();
    if (widget.threadDetailController?.selectedThreadId == threadId) {
      unawaited(widget.threadDetailController?.readThread(threadId));
    }
    return true;
  }

  Future<SlashCommandCallbackResult> _forkCurrentThread() async {
    final runner = widget.sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    final turnController = widget.turnController;
    if (runner == null || threadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    if (turnController != null && !turnController.canSubmit) {
      return SlashCommandCallbackResult.unavailable;
    }
    final forked = await runner.forkThread(threadId: threadId);
    return _activateForkedThread(forked);
  }

  Future<SlashCommandCallbackResult> _duplicateCurrentThread() async {
    final runner = widget.sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    final turnController = widget.turnController;
    if (runner == null || threadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    if (turnController != null && !turnController.canSubmit) {
      return SlashCommandCallbackResult.unavailable;
    }
    final duplicated = await runner.duplicateThread(threadId: threadId);
    return _activateForkedThread(duplicated);
  }

  Future<SlashCommandCallbackResult> _rewindCurrentThread(
    String lastTurnId,
  ) async {
    final runner = widget.sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    final checkpoint = lastTurnId.trim();
    final turnController = widget.turnController;
    if (runner == null || threadId == null || checkpoint.isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }
    if (turnController != null && !turnController.canSubmit) {
      return SlashCommandCallbackResult.unavailable;
    }
    final rewound = await runner.rewindThread(
      threadId: threadId,
      lastTurnId: checkpoint,
    );
    return _activateForkedThread(rewound);
  }

  SlashCommandCallbackResult _activateForkedThread(ThreadSummary thread) {
    if (thread.id.trim().isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }
    final activated = widget.turnController?.activateThread(thread.id) ?? true;
    if (!activated) {
      return SlashCommandCallbackResult.unavailable;
    }
    _clearSideConversation();
    widget.timelineController?.showThread(thread);
    unawaited(widget.threadDetailController?.readThread(thread.id));
    _refreshVisibleThreads();
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _startSideConversation(
    String arguments, {
    required bool btw,
  }) async {
    final runner = widget.sessionController?.threadMutationRunner;
    final turnController = widget.turnController;
    final parentThreadId = _currentThreadId();
    if (runner == null || turnController == null || parentThreadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    if (!turnController.canSubmit || _sideConversation != null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final sideThread = await runner.startSideConversation(
      threadId: parentThreadId,
    );
    if (sideThread.id.trim().isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }
    final activated = turnController.activateThread(sideThread.id);
    if (!activated) {
      return SlashCommandCallbackResult.unavailable;
    }

    setState(() {
      _sideConversation = _SideConversation(
        parentThreadId: parentThreadId,
        sideThreadId: sideThread.id,
        slash: btw ? '/btw' : '/side',
      );
    });
    widget.timelineController?.showThread(sideThread);
    unawaited(widget.threadDetailController?.readThread(sideThread.id));
    _refreshVisibleThreads();

    final initialPrompt = arguments.trim();
    if (initialPrompt.isNotEmpty) {
      await turnController.submitText(initialPrompt);
      if (turnController.status != TurnControllerStatus.failed) {
        _syncActiveTurnToTimeline(submittedText: initialPrompt);
      }
    }
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _showAgentTopology({
    required bool subagentsOnly,
  }) async {
    final threadListController = widget.threadListController;
    final turnController = widget.turnController;
    if (threadListController == null || turnController == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    await threadListController.refresh(limit: 100);
    if (!mounted) {
      return SlashCommandCallbackResult.cancelled;
    }
    final activeThreadDetail = await _readActiveThreadForAgentTopology();
    if (!mounted) {
      return SlashCommandCallbackResult.cancelled;
    }
    final topology = AgentThreadTopology.fromThreads(
      _agentTopologyThreads(threadListController.threads, activeThreadDetail),
    );
    final entries = subagentsOnly ? topology.subagentEntries : topology.entries;
    if (entries.isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }

    final selectedThread = await showModalBottomSheet<ThreadSummary>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AgentTopologySheet(
        entries: entries,
        subagentsOnly: subagentsOnly,
        activeThreadId: _currentThreadId(),
      ),
    );
    if (!mounted || selectedThread == null) {
      return SlashCommandCallbackResult.cancelled;
    }
    if (!turnController.canSubmit) {
      return SlashCommandCallbackResult.unavailable;
    }
    final activated = turnController.activateThread(selectedThread.id);
    if (!activated) {
      return SlashCommandCallbackResult.unavailable;
    }

    _clearSideConversation();
    widget.timelineController?.selectThread(selectedThread.id);
    unawaited(widget.threadDetailController?.readThread(selectedThread.id));
    return SlashCommandCallbackResult.executed;
  }

  Future<ThreadSummary?> _readActiveThreadForAgentTopology() async {
    final threadId = _currentThreadId();
    if (threadId == null) {
      return null;
    }
    final cachedThread = widget.threadDetailController?.detail?.thread;
    if (cachedThread?.id == threadId && cachedThread!.turns.isNotEmpty) {
      return cachedThread;
    }
    final reader = widget.sessionController?.threadDetailReader;
    if (reader == null) {
      return cachedThread?.id == threadId ? cachedThread : null;
    }
    try {
      final detail = await reader.readThread(threadId: threadId);
      if (detail.thread.id == threadId) {
        return detail.thread;
      }
      return cachedThread?.id == threadId ? cachedThread : null;
    } on Object {
      return cachedThread?.id == threadId ? cachedThread : null;
    }
  }

  List<ThreadSummary> _agentTopologyThreads(
    List<ThreadSummary> threads,
    ThreadSummary? detailThread,
  ) {
    if (detailThread == null || detailThread.id.trim().isEmpty) {
      return threads;
    }
    final merged = List<ThreadSummary>.from(threads);
    final index = merged.indexWhere((thread) => thread.id == detailThread.id);
    if (index == -1) {
      merged.add(detailThread);
    } else {
      merged[index] = detailThread;
    }
    return merged;
  }

  Future<void> _returnToMainThread() async {
    final sideConversation = _sideConversation;
    final turnController = widget.turnController;
    if (sideConversation == null ||
        turnController == null ||
        !turnController.canSubmit) {
      return;
    }
    final activated = turnController.activateThread(
      sideConversation.parentThreadId,
    );
    if (!activated) {
      return;
    }
    _clearSideConversation();
    widget.timelineController?.selectThread(sideConversation.parentThreadId);
    unawaited(
      widget.threadDetailController?.readThread(
        sideConversation.parentThreadId,
      ),
    );
    if (!mounted) {
      return;
    }
    _showChatSnackBar(context.l10n.slashCommandReturnedToMainThread);
  }

  Future<SlashCommandCallbackResult> _compactCurrentThread() async {
    final runner = widget.sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    await runner.compactThread(threadId: threadId);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _configureTheme() async {
    final controller = widget.appearanceController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final selection = await showModalBottomSheet<_ThemeSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ThemeSheet(
        initialTheme: controller.theme,
        initialColorPalette: controller.colorPalette,
      ),
    );
    if (!mounted || selection == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    controller.setTheme(selection.theme);
    controller.setColorPalette(selection.colorPalette);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _configureTitleDisplay() async {
    final controller = widget.appearanceController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final settings = await showModalBottomSheet<AppTitleDisplaySettings>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          TitleDisplaySheet(initialSettings: controller.titleDisplay),
    );
    if (!mounted || settings == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    controller.setTitleDisplay(settings);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _configureStatusLineDisplay() async {
    final controller = widget.appearanceController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final settings = await showModalBottomSheet<AppStatusLineDisplaySettings>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          StatusLineDisplaySheet(initialSettings: controller.statusLineDisplay),
    );
    if (!mounted || settings == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    controller.setStatusLineDisplay(settings);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _toggleComposerVimMode() async {
    final controller = widget.appearanceController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final nextMode = controller.composerInputMode == AppComposerInputMode.vim
        ? AppComposerInputMode.standard
        : AppComposerInputMode.vim;
    controller.setComposerInputMode(nextMode);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _configureKeymap(String arguments) async {
    final controller = widget.appearanceController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final trimmed = arguments.trim();
    if (trimmed.isNotEmpty) {
      final shortcut = AppComposerSendShortcut.parseCommandValue(trimmed);
      if (shortcut == null) {
        return SlashCommandCallbackResult.unavailable;
      }
      controller.setComposerSendShortcut(shortcut);
      return SlashCommandCallbackResult.executed;
    }

    final shortcut = await showModalBottomSheet<AppComposerSendShortcut>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          ComposerKeymapSheet(initialShortcut: controller.composerSendShortcut),
    );
    if (!mounted || shortcut == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    controller.setComposerSendShortcut(shortcut);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _configureTerminalPets(
    String arguments,
  ) async {
    final controller = widget.appearanceController;
    if (controller == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final trimmed = arguments.trim();
    if (trimmed.isNotEmpty) {
      final preference = AppTerminalPetPreference.parseCommandValue(trimmed);
      if (preference == null) {
        return SlashCommandCallbackResult.unavailable;
      }
      controller.setTerminalPetPreference(preference);
      return SlashCommandCallbackResult.executed;
    }

    final preference = await showModalBottomSheet<AppTerminalPetPreference>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TerminalPetDisplaySheet(
        initialPreference: controller.terminalPetPreference,
      ),
    );
    if (!mounted || preference == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    controller.setTerminalPetPreference(preference);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _submitFeedback() async {
    final runner = widget.sessionController?.feedbackUploadRunner;
    if (runner == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final result = await showModalBottomSheet<_FeedbackFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _FeedbackSheet(),
    );
    if (!mounted || result == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    await runner.uploadFeedback(
      classification: result.category.classification,
      reason: result.note,
      threadId: _currentThreadId(),
      turnId: widget.turnController?.activeTurnId,
      includeLogs: result.includeLogs,
    );
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _logoutAccount() async {
    final runner = widget.sessionController?.accountLogoutRunner;
    if (runner == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logoutAccountTitle),
        content: Text(l10n.logoutAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.logoutAccountConfirm),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return SlashCommandCallbackResult.cancelled;
    }

    await runner.logout();
    await Future.wait([
      if (widget.accountSnapshotController != null)
        widget.accountSnapshotController!.refresh(),
      if (widget.accountUsageSnapshotController != null)
        widget.accountUsageSnapshotController!.refresh(),
    ]);
    return SlashCommandCallbackResult.executed;
  }

  Future<SlashCommandCallbackResult> _archiveCurrentThread() {
    final l10n = context.l10n;
    return _confirmThreadMutation(
      title: l10n.archiveThreadTitle,
      body: l10n.archiveThreadBody,
      confirmLabel: l10n.archiveThreadConfirm,
      mutate: (runner, threadId) => runner.archiveThread(threadId: threadId),
    );
  }

  Future<SlashCommandCallbackResult> _deleteCurrentThread() {
    final l10n = context.l10n;
    return _confirmThreadMutation(
      title: l10n.deleteThreadTitle,
      body: l10n.deleteThreadBody,
      confirmLabel: l10n.deleteThreadConfirm,
      mutate: (runner, threadId) => runner.deleteThread(threadId: threadId),
    );
  }

  Future<void> _unarchiveThread(ThreadSummary thread) async {
    final runner = widget.sessionController?.threadMutationRunner;
    if (runner == null) {
      return;
    }
    await runner.unarchiveThread(threadId: thread.id);
    _refreshVisibleThreads();
    if (!mounted) {
      return;
    }
    _showChatSnackBar(context.l10n.threadUnarchived);
  }

  Future<SlashCommandCallbackResult> _confirmThreadMutation({
    required String title,
    required String body,
    required String confirmLabel,
    required Future<void> Function(ThreadMutationRunner runner, String threadId)
    mutate,
  }) async {
    final runner = widget.sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }
    final cancelLabel = context.l10n.approvalCancel;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return SlashCommandCallbackResult.cancelled;
    }
    await mutate(runner, threadId);
    _clearLocalTranscript();
    _refreshVisibleThreads();
    return SlashCommandCallbackResult.executed;
  }

  Future<bool> _confirmHighRiskSlashCommand(
    SlashCommandSpec command,
    String arguments,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_outlined,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: Text(l10n.slashCommandHighRiskConfirmTitle),
        content: Text(l10n.slashCommandHighRiskConfirmBody(command.slash)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.slashCommandHighRiskConfirmContinue),
          ),
        ],
      ),
    );
    return mounted && confirmed == true;
  }

  String? _currentThreadId() {
    final selectedThreadId = widget.threadDetailController?.selectedThreadId;
    if (selectedThreadId != null && selectedThreadId.trim().isNotEmpty) {
      return selectedThreadId;
    }
    final activeThreadId = widget.turnController?.activeThreadId;
    if (activeThreadId != null && activeThreadId.trim().isNotEmpty) {
      return activeThreadId;
    }
    return null;
  }

  ThreadTokenUsageSnapshot? _currentThreadTokenUsage() {
    final controller = widget.threadTokenUsageController;
    if (controller == null) {
      return null;
    }
    final threadId = _currentThreadId();
    if (threadId != null) {
      return controller.latestForThread(threadId);
    }
    return controller.latest;
  }

  List<String> _currentWorkspaceCwds() {
    final overrideCwd = widget.configOverrideController?.resolved.cwd?.trim();
    if (overrideCwd != null && overrideCwd.isNotEmpty) {
      return [overrideCwd];
    }

    final threadCwd = widget.threadDetailController?.detail?.thread.cwd.trim();
    if (threadCwd != null && threadCwd.isNotEmpty) {
      return [threadCwd];
    }

    return const [];
  }

  List<PluginMarketplaceKind>? _pluginMarketplaceKindsFromArguments(
    List<String> parts,
  ) {
    if (parts.isEmpty) {
      return const [];
    }
    final kind = switch (parts) {
      [final rawKind] => _parsePluginMarketplaceKind(rawKind),
      ['marketplace' || 'marketplaces', final rawKind] =>
        _parsePluginMarketplaceKind(rawKind),
      _ => null,
    };
    return kind == null ? null : [kind];
  }

  PluginMarketplaceKind? _parsePluginMarketplaceKind(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', '-');
    for (final kind in PluginMarketplaceKind.values) {
      final normalizedName = kind.name
          .replaceAllMapped(
            RegExp(r'[A-Z]'),
            (match) => '-${match.group(0)!.toLowerCase()}',
          )
          .toLowerCase();
      if (normalized == kind.wireName || normalized == normalizedName) {
        return kind;
      }
    }
    return null;
  }

  Future<String?> _resolvePlanModeModel() async {
    final current = _currentPlanModeModel();
    if (current != null) {
      return current;
    }

    final configSnapshotController = widget.configSnapshotController;
    if (configSnapshotController == null) {
      return null;
    }
    final cwds = _currentWorkspaceCwds();
    await configSnapshotController.refresh(cwd: cwds.isEmpty ? null : cwds[0]);
    if (!mounted) {
      return null;
    }
    return _currentPlanModeModel();
  }

  String? _currentPlanModeModel() {
    final overrideModel = _normalizedText(
      widget.configOverrideController?.resolved.model,
    );
    if (overrideModel != null) {
      return overrideModel;
    }

    final snapshotModel = _normalizedText(
      widget.configSnapshotController?.snapshot?.displayValueFor('model'),
    );
    if (snapshotModel != null) {
      return snapshotModel;
    }

    final threadModel = _normalizedText(
      widget.threadDetailController?.detail?.thread.raw['model']?.toString(),
    );
    return threadModel;
  }

  void _clearLocalTranscript() {
    _clearSideConversation();
    widget.threadDetailController?.clear();
    widget.timelineController?.clear();
    widget.turnController?.clearLocalConversation();
  }

  String _slashCommandResultMessage(
    AppLocalizations l10n,
    SlashCommandActionResult result,
  ) {
    final message = result.message;
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return switch (result.outcome) {
      SlashCommandActionOutcome.ignored => '',
      SlashCommandActionOutcome.executed => switch (result.effect) {
        SlashCommandActionEffect.disconnect => l10n.slashCommandDisconnected,
        SlashCommandActionEffect.clearTranscript => l10n.slashCommandCleared,
        SlashCommandActionEffect.copy => l10n.slashCommandCopied,
        SlashCommandActionEffect.status => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.usage => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.mcp => l10n.slashCommandExecuted(result.slash),
        SlashCommandActionEffect.skills => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.plugins => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.hooks => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.apps => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.debugConfig => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.experimental => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.memories => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.rollout => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.testApproval => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.diff => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.goal => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.review => l10n.slashCommandExecuted(
          result.slash,
        ),
        SlashCommandActionEffect.backgroundTerminals =>
          l10n.slashCommandExecuted(result.slash),
        SlashCommandActionEffect.backgroundTerminalCleanup =>
          l10n.backgroundTerminalsCleanRequested,
        SlashCommandActionEffect.rawTranscript =>
          _showRawTranscript
              ? l10n.slashCommandRawEnabled
              : l10n.slashCommandRawDisabled,
        SlashCommandActionEffect.newThread => l10n.slashCommandNewThread,
        SlashCommandActionEffect.resumeThread => l10n.slashCommandResumedThread,
        SlashCommandActionEffect.renameThread => l10n.slashCommandRenamedThread,
        SlashCommandActionEffect.forkThread => l10n.slashCommandForkedThread,
        SlashCommandActionEffect.duplicateThread =>
          l10n.slashCommandDuplicatedThread,
        SlashCommandActionEffect.rewindThread => l10n.slashCommandRewoundThread,
        SlashCommandActionEffect.compactThread =>
          l10n.slashCommandCompactionStarted,
        SlashCommandActionEffect.archiveThread =>
          l10n.slashCommandArchivedThread,
        SlashCommandActionEffect.deleteThread => l10n.slashCommandDeletedThread,
        SlashCommandActionEffect.logout => l10n.slashCommandLoggedOut,
        SlashCommandActionEffect.feedback => l10n.slashCommandFeedbackSubmitted,
        SlashCommandActionEffect.approveAutoReviewDenial =>
          l10n.slashCommandAutoReviewApproved,
        SlashCommandActionEffect.theme => l10n.slashCommandThemeUpdated,
        SlashCommandActionEffect.titleDisplay =>
          l10n.slashCommandTitleDisplayUpdated,
        SlashCommandActionEffect.statusLineDisplay =>
          l10n.slashCommandStatusLineDisplayUpdated,
        SlashCommandActionEffect.ideContext =>
          l10n.slashCommandIdeContextInserted,
        SlashCommandActionEffect.keymap => l10n.slashCommandKeymapUpdated,
        SlashCommandActionEffect.composerVimMode =>
          (widget.appearanceController?.composerInputMode ==
                  AppComposerInputMode.vim)
              ? l10n.slashCommandVimModeEnabled
              : l10n.slashCommandVimModeDisabled,
        SlashCommandActionEffect.terminalPets =>
          (widget.appearanceController?.terminalPetPreference ==
                  AppTerminalPetPreference.hidden)
              ? l10n.slashCommandPetsHidden
              : l10n.slashCommandPetsTuiOnly,
        SlashCommandActionEffect.mention => l10n.slashCommandMentionInserted,
        SlashCommandActionEffect.sideConversation =>
          l10n.slashCommandSideConversationStarted,
        SlashCommandActionEffect.agentTopology =>
          l10n.slashCommandAgentThreadSelected,
        SlashCommandActionEffect.appHandoff =>
          l10n.slashCommandAppHandoffUnavailable,
        SlashCommandActionEffect.importFlow =>
          l10n.slashCommandImportUnavailable,
        SlashCommandActionEffect.initFlow => l10n.slashCommandInitUnavailable,
        SlashCommandActionEffect.sandboxSetup =>
          l10n.slashCommandSandboxSetupUnavailable,
        SlashCommandActionEffect.sandboxReadDir =>
          l10n.slashCommandSandboxReadDirUnavailable,
        SlashCommandActionEffect.modelOverride => l10n.slashCommandModelUpdated,
        SlashCommandActionEffect.personalityOverride =>
          l10n.slashCommandPersonalityUpdated,
        SlashCommandActionEffect.permissionsOverride =>
          l10n.slashCommandPermissionsUpdated,
        SlashCommandActionEffect.planMode => l10n.slashCommandPlanModeUpdated,
        SlashCommandActionEffect.none => l10n.slashCommandExecuted(
          result.slash,
        ),
      },
      SlashCommandActionOutcome.cancelled => l10n.slashCommandCancelled(
        result.slash,
      ),
      SlashCommandActionOutcome.unknown => l10n.slashCommandUnknown(
        result.slash,
      ),
      SlashCommandActionOutcome.unsupported => _slashCommandUnsupportedMessage(
        l10n,
        result,
      ),
      SlashCommandActionOutcome.unavailable => l10n.slashCommandUnavailable(
        result.slash,
      ),
      SlashCommandActionOutcome.failed => l10n.slashCommandFailed(
        result.slash,
        result.error?.toString() ?? '',
      ),
    };
  }

  String _slashCommandUnsupportedMessage(
    AppLocalizations l10n,
    SlashCommandActionResult result,
  ) {
    final command = result.command;
    if (command == null) {
      return l10n.slashCommandUnsupported(result.slash);
    }

    final parts = <String>[
      l10n.slashCommandUnsupportedWithStatus(
        result.slash,
        _slashCommandUnsupportedStatus(l10n, command),
      ),
    ];
    final target = command.mappingTarget.trim();
    if (target.isNotEmpty) {
      parts.add(l10n.slashCommandUnsupportedTarget(target));
    }
    if (command.riskLevel != SlashCommandRiskLevel.low) {
      parts.add(l10n.slashCommandUnsupportedRisk(command.riskLevel.name));
    }
    return parts.join(' ');
  }

  String _slashCommandUnsupportedStatus(
    AppLocalizations l10n,
    SlashCommandSpec command,
  ) {
    return switch (command.platformVisibility) {
      SlashPlatformVisibility.desktopOnly =>
        l10n.slashCommandUnsupportedDesktopOnly,
      SlashPlatformVisibility.windowsOnly =>
        l10n.slashCommandUnsupportedWindowsOnly,
      SlashPlatformVisibility.tuiOnly => l10n.slashCommandUnsupportedTuiOnly,
      SlashPlatformVisibility.debugOnly =>
        l10n.slashCommandUnsupportedDebugOnly,
      SlashPlatformVisibility.all => switch (command.mappingType) {
        SlashCommandMappingType.appServer =>
          l10n.slashCommandUnsupportedAppServer,
        SlashCommandMappingType.uiOnly => l10n.slashCommandUnsupportedUiOnly,
        SlashCommandMappingType.agentFallback =>
          l10n.slashCommandUnsupportedAgentFallback,
        SlashCommandMappingType.topology =>
          l10n.slashCommandUnsupportedTopology,
        SlashCommandMappingType.notApplicable =>
          l10n.slashCommandUnsupportedNotApplicable,
        SlashCommandMappingType.debug => l10n.slashCommandUnsupportedDebug,
      },
    };
  }

  bool _canSubmitComposerText(
    String text, {
    required bool isConnected,
    required TurnController? turnController,
  }) {
    if (text.trim().isEmpty) {
      return false;
    }
    if (_isShellCommandInput(text)) {
      return _shellCommandFromInput(text) != null &&
          isConnected &&
          widget.sessionController?.threadShellCommandRunner != null &&
          turnController != null &&
          !turnController.isBusy &&
          _nonEmptyText(turnController.activeThreadId) != null;
    }
    final parsed = widget.registry.parseComposerText(text);
    final canSubmitPrompt =
        isConnected &&
        turnController != null &&
        (turnController.canSubmit || turnController.canSteer);
    if (_isSlashTextPrompt(text, parsed)) {
      return canSubmitPrompt;
    }
    return switch (parsed.kind) {
      SlashCommandParseKind.notSlash => canSubmitPrompt,
      SlashCommandParseKind.empty || SlashCommandParseKind.unknown => false,
      SlashCommandParseKind.known => true,
    };
  }

  bool _isSlashTextPrompt(String text, SlashCommandParseResult parsed) {
    return _slashTextPrompt == text &&
        parsed.kind != SlashCommandParseKind.notSlash &&
        parsed.kind != SlashCommandParseKind.empty;
  }

  bool _isShellCommandInput(String text) => text.startsWith('!');

  String? _shellCommandFromInput(String text) {
    if (!_isShellCommandInput(text)) {
      return null;
    }
    return _nonEmptyText(text.substring(1));
  }

  void _handleSessionChanged() {
    final status = widget.sessionController?.status;
    final profile = widget.sessionController?.profile;
    if (profile != null) {
      _selectedProfileId = profile.id;
    }
    if (_lastSessionStatus != CodexSessionStatus.connected &&
        status == CodexSessionStatus.connected) {
      _refreshVisibleThreads();
    }
    _dropSideConversationIfSessionUnavailable(status);
    _lastSessionStatus = status;
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTurnChanged() {
    final sideConversation = _sideConversation;
    final activeThreadId = widget.turnController?.activeThreadId;
    if (sideConversation != null &&
        activeThreadId != null &&
        activeThreadId != sideConversation.sideThreadId) {
      _sideConversation = null;
    }
    _syncActiveTurnToTimeline();
    if (mounted) {
      setState(() {});
    }
  }

  void _syncActiveTurnToTimeline({String? submittedText}) {
    final timelineController = widget.timelineController;
    final turnController = widget.turnController;
    final activeThreadId = _nonEmptyText(turnController?.activeThreadId);
    if (timelineController == null ||
        turnController == null ||
        activeThreadId == null) {
      return;
    }
    final lastTurn = turnController.lastTurn;
    if (lastTurn != null && lastTurn.id.trim().isNotEmpty) {
      timelineController.showTurn(threadId: activeThreadId, turn: lastTurn);
      final text = _nonEmptyText(submittedText);
      if (text != null) {
        timelineController.showLocalUserMessage(
          threadId: activeThreadId,
          turnId: lastTurn.id,
          text: text,
        );
      }
      return;
    }
    timelineController.selectThread(activeThreadId);
  }

  void _refreshThreadsIfConnected() {
    if (widget.sessionController?.status == CodexSessionStatus.connected) {
      _refreshVisibleThreads();
    }
  }

  void _refreshVisibleThreads({int limit = 20}) {
    unawaited(
      widget.threadListController?.refresh(
        limit: limit,
        archived: _showArchivedThreads,
      ),
    );
  }

  void _setThreadArchiveView(bool archived) {
    if (_showArchivedThreads == archived) {
      return;
    }
    setState(() => _showArchivedThreads = archived);
    _refreshVisibleThreads();
  }

  List<String> _chatStatusLineParts(AppLocalizations l10n) {
    final settings =
        widget.appearanceController?.statusLineDisplay ??
        AppStatusLineDisplaySettings.defaults;
    final parts = <String>[];
    if (settings.showConnection) {
      parts.add(
        '${l10n.connectionStatus}: '
        '${_connectionLabel(l10n, widget.sessionController?.status)}',
      );
    }
    if (settings.showThread) {
      final threadId = _currentThreadId();
      if (threadId != null) {
        parts.add('${l10n.approvalThread}: $threadId');
      }
    }
    final cwd = _currentWorkspaceCwd();
    if (settings.showWorkingDirectory && cwd != null) {
      parts.add('${l10n.approvalWorkingDirectory}: $cwd');
    }
    final overrides = widget.configOverrideController?.resolved;
    final model = _nonEmptyText(overrides?.model);
    if (settings.showModel && model != null) {
      parts.add('${l10n.modelOverride}: $model');
    }
    final effort = _nonEmptyText(overrides?.effort);
    if (settings.showEffort && effort != null) {
      parts.add('${l10n.effortOverride}: $effort');
    }
    return parts;
  }

  String? _currentWorkspaceCwd() {
    final cwds = _currentWorkspaceCwds();
    return cwds.isEmpty ? null : cwds.first;
  }

  String _workspaceSummary(AppLocalizations l10n) {
    final cwd = _currentWorkspaceCwd();
    if (cwd == null) {
      return l10n.workspaceFilesNoCwd;
    }
    return cwd;
  }

  String? _nonEmptyText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _connectionLabel(AppLocalizations l10n, CodexSessionStatus? status) {
    return sessionStatusLabel(l10n, status);
  }

  void _handleAppearanceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearSideConversation() {
    if (_sideConversation == null) {
      return;
    }
    if (mounted) {
      setState(() => _sideConversation = null);
    } else {
      _sideConversation = null;
    }
  }

  void _dropSideConversationIfSessionUnavailable(CodexSessionStatus? status) {
    final shouldDrop = switch (status) {
      CodexSessionStatus.connecting ||
      CodexSessionStatus.disconnecting ||
      CodexSessionStatus.idle ||
      CodexSessionStatus.failed => true,
      CodexSessionStatus.connected ||
      CodexSessionStatus.reconnecting ||
      null => false,
    };
    final sideConversation = _sideConversation;
    if (!shouldDrop || sideConversation == null) {
      return;
    }

    _sideConversation = null;
    widget.threadDetailController?.clear();
    if (widget.turnController?.canSubmit == true &&
        widget.turnController!.activateThread(
          sideConversation.parentThreadId,
        )) {
      widget.timelineController?.selectThread(sideConversation.parentThreadId);
    }
    if (!mounted) {
      return;
    }
    _showChatSnackBar(context.l10n.sideConversationDropped);
  }
}

String? _normalizedText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}

String? _rolloutPathFromRaw(Map<String, Object?> raw) {
  String? fromValue(Object? value) {
    if (value is String) {
      return _normalizedText(value);
    }
    if (value is Map) {
      return fromValue(value['path']);
    }
    return null;
  }

  for (final key in const [
    'rolloutPath',
    'rollout_path',
    'currentRolloutPath',
    'current_rollout_path',
    'rollout',
  ]) {
    final path = fromValue(raw[key]);
    if (path != null) {
      return path;
    }
  }
  return null;
}

class _SideConversation {
  const _SideConversation({
    required this.parentThreadId,
    required this.sideThreadId,
    required this.slash,
  });

  final String parentThreadId;
  final String sideThreadId;
  final String slash;
}

class _SideConversationPanel extends StatelessWidget {
  const _SideConversationPanel({
    required this.conversation,
    required this.canReturn,
    required this.onReturn,
  });

  final _SideConversation conversation;
  final bool canReturn;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      key: const ValueKey('chat-side-conversation-panel'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.34),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: colorScheme.tertiary),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 8, 9),
            child: Row(
              children: [
                Icon(
                  Icons.call_split_outlined,
                  size: 18,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l10n.sideConversationTitle} · ${conversation.slash}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  key: const ValueKey('chat-side-return-main'),
                  onPressed: canReturn ? onReturn : null,
                  tooltip: l10n.returnToMainThread,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size.square(32),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.keyboard_return, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentTopologySheet extends StatelessWidget {
  const _AgentTopologySheet({
    required this.entries,
    required this.subagentsOnly,
    required this.activeThreadId,
  });

  final List<AgentThreadTopologyEntry> entries;
  final bool subagentsOnly;
  final String? activeThreadId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                subagentsOnly
                    ? l10n.subagentTopologyTitle
                    : l10n.agentTopologyTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (context, index) => _AgentTopologyTile(
                  entry: entries[index],
                  active: entries[index].thread.id == activeThreadId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentTopologyTile extends StatelessWidget {
  const _AgentTopologyTile({required this.entry, required this.active});

  final AgentThreadTopologyEntry entry;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thread = entry.thread;
    final role = entry.displayRole;
    final statusColor = _agentRuntimeStatusColor(context, entry);
    final details = <String>[
      '${l10n.approvalThread}: ${thread.id}',
      '${l10n.timelineStatus}: ${entry.displayStatus}',
      if (role.isNotEmpty) '${l10n.agentRole}: $role',
      if (entry.agentPath != null) '${l10n.agentPath}: ${entry.agentPath}',
      if (entry.parentThreadId != null)
        '${l10n.agentParentThread}: ${entry.parentThreadId}',
      if (entry.ancestorThreadId != null)
        '${l10n.agentAncestorThread}: ${entry.ancestorThreadId}',
      if (thread.cwd.isNotEmpty) thread.cwd,
    ];
    return ListTile(
      key: ValueKey('agent-thread-${thread.id}'),
      contentPadding: EdgeInsetsDirectional.only(
        start: 16.0 + entry.depth * 24,
        end: 16,
      ),
      leading: Icon(
        entry.isSubagent ? Icons.account_tree_outlined : Icons.forum_outlined,
        color: statusColor,
      ),
      title: Text(
        active ? '${thread.title} (${l10n.activeThread})' : thread.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(details.join('\n')),
      isThreeLine: true,
      trailing: entry.hasChildren
          ? const Icon(Icons.keyboard_arrow_down)
          : const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pop(thread),
    );
  }
}

Color _agentRuntimeStatusColor(
  BuildContext context,
  AgentThreadTopologyEntry entry,
) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (entry.runtimeStatus) {
    AgentThreadRuntimeStatus.running => colorScheme.primary,
    AgentThreadRuntimeStatus.closed => colorScheme.onSurfaceVariant,
    AgentThreadRuntimeStatus.errored => colorScheme.error,
    null => switch (entry.displayStatus.trim().toLowerCase()) {
      'running' || 'inprogress' || 'pendinginit' => colorScheme.primary,
      'closed' ||
      'completed' ||
      'interrupted' ||
      'shutdown' => colorScheme.onSurfaceVariant,
      'errored' || 'failed' || 'notfound' => colorScheme.error,
      _ => colorScheme.secondary,
    },
  };
}

class _ComposerMention {
  const _ComposerMention({
    required this.token,
    required this.start,
    required this.end,
  });

  final String token;
  final int start;
  final int end;

  bool isPresentIn(String text) {
    return start >= 0 &&
        end <= text.length &&
        end > start &&
        text.substring(start, end) == token;
  }
}

sealed class _GoalCommand {
  const _GoalCommand();
}

class _GoalGetCommand extends _GoalCommand {
  const _GoalGetCommand();
}

class _GoalClearCommand extends _GoalCommand {
  const _GoalClearCommand();
}

class _GoalSetCommand extends _GoalCommand {
  const _GoalSetCommand({this.objective, this.status, this.tokenBudget});

  final String? objective;
  final String? status;
  final int? tokenBudget;
}

_GoalCommand? _parseGoalCommand(String arguments) {
  final trimmed = arguments.trim();
  if (trimmed.isEmpty || trimmed == 'show' || trimmed == 'get') {
    return const _GoalGetCommand();
  }
  if (trimmed == 'clear') {
    return const _GoalClearCommand();
  }

  final firstSpace = trimmed.indexOf(RegExp(r'\s'));
  final head = firstSpace == -1 ? trimmed : trimmed.substring(0, firstSpace);
  final tail = firstSpace == -1 ? '' : trimmed.substring(firstSpace + 1).trim();
  if (head == 'status') {
    if (!_goalStatuses.contains(tail)) {
      return null;
    }
    return _GoalSetCommand(status: tail);
  }
  if (head == 'budget') {
    final nextSpace = tail.indexOf(RegExp(r'\s'));
    final budgetText = nextSpace == -1 ? tail : tail.substring(0, nextSpace);
    final budget = int.tryParse(budgetText);
    if (budget == null || budget <= 0) {
      return null;
    }
    final objective = nextSpace == -1
        ? null
        : tail.substring(nextSpace + 1).trim();
    return _GoalSetCommand(
      tokenBudget: budget,
      objective: objective?.isEmpty == true ? null : objective,
    );
  }
  if (head == 'set') {
    return tail.isEmpty ? null : _GoalSetCommand(objective: tail);
  }
  return _GoalSetCommand(objective: trimmed);
}

const _goalStatuses = {
  'active',
  'paused',
  'blocked',
  'usageLimited',
  'budgetLimited',
  'complete',
};

class _ThemeSheet extends StatefulWidget {
  const _ThemeSheet({
    required this.initialTheme,
    required this.initialColorPalette,
  });

  final AppThemePreference initialTheme;
  final AppColorPalette initialColorPalette;

  @override
  State<_ThemeSheet> createState() => _ThemeSheetState();
}

class _ThemeSheetState extends State<_ThemeSheet> {
  late AppThemePreference _theme;
  late AppColorPalette _colorPalette;

  @override
  void initState() {
    super.initState();
    _theme = widget.initialTheme;
    _colorPalette = widget.initialColorPalette;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.themeCommandTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<AppThemePreference>(
                segments: [
                  ButtonSegment(
                    value: AppThemePreference.system,
                    icon: const Icon(Icons.brightness_auto_outlined),
                    label: Text(l10n.themeSystem),
                  ),
                  ButtonSegment(
                    value: AppThemePreference.light,
                    icon: const Icon(Icons.light_mode_outlined),
                    label: Text(l10n.themeLight),
                  ),
                  ButtonSegment(
                    value: AppThemePreference.dark,
                    icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(l10n.themeDark),
                  ),
                ],
                selected: {_theme},
                onSelectionChanged: (selection) {
                  setState(() => _theme = selection.single);
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.colorPalette,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.colorPaletteBody,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              AppColorPalettePicker(
                keyPrefix: 'chat-color-palette',
                selectedPalette: _colorPalette,
                onSelected: (palette) {
                  setState(() => _colorPalette = palette);
                },
              ),
              const SizedBox(height: 16),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: Text(l10n.approvalCancel),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('chat-theme-command-apply'),
                    onPressed: () => Navigator.of(context).pop(
                      _ThemeSheetResult(
                        theme: _theme,
                        colorPalette: _colorPalette,
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.applyTheme),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSheetResult {
  const _ThemeSheetResult({required this.theme, required this.colorPalette});

  final AppThemePreference theme;
  final AppColorPalette colorPalette;
}

class _FeedbackFormResult {
  const _FeedbackFormResult({
    required this.category,
    required this.includeLogs,
    this.note,
  });

  final _FeedbackCategory category;
  final bool includeLogs;
  final String? note;
}

enum _FeedbackCategory { bug, badResult, goodResult, safetyCheck, other }

extension _FeedbackCategoryLabels on _FeedbackCategory {
  String get classification {
    return switch (this) {
      _FeedbackCategory.bug => 'bug',
      _FeedbackCategory.badResult => 'bad_result',
      _FeedbackCategory.goodResult => 'good_result',
      _FeedbackCategory.safetyCheck => 'safety_check',
      _FeedbackCategory.other => 'other',
    };
  }

  String label(AppLocalizations l10n) {
    return switch (this) {
      _FeedbackCategory.bug => l10n.feedbackCategoryBug,
      _FeedbackCategory.badResult => l10n.feedbackCategoryBadResult,
      _FeedbackCategory.goodResult => l10n.feedbackCategoryGoodResult,
      _FeedbackCategory.safetyCheck => l10n.feedbackCategorySafetyCheck,
      _FeedbackCategory.other => l10n.feedbackCategoryOther,
    };
  }
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final TextEditingController _noteController = TextEditingController();
  _FeedbackCategory _category = _FeedbackCategory.bug;
  bool _includeLogs = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.feedbackCommandTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<_FeedbackCategory>(
              key: const ValueKey('chat-feedback-category'),
              initialValue: _category,
              decoration: InputDecoration(
                labelText: l10n.feedbackCategoryLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final category in _FeedbackCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label(l10n)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('chat-feedback-note'),
              controller: _noteController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.feedbackNoteLabel,
                hintText: l10n.feedbackNoteHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.feedbackIncludeLogs),
              value: _includeLogs,
              onChanged: (value) => setState(() => _includeLogs = value),
            ),
            if (_includeLogs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.feedbackLogsDisclosure,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.approvalCancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  child: Text(l10n.feedbackSubmit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_includeLogs) {
      final confirmed = await _confirmIncludeLogs();
      if (!mounted || !confirmed) {
        return;
      }
    }
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      _FeedbackFormResult(
        category: _category,
        includeLogs: _includeLogs,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  Future<bool> _confirmIncludeLogs() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.info_outline),
        title: Text(l10n.feedbackLogsConfirmTitle),
        content: Text(l10n.feedbackLogsConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.feedbackLogsConfirmSubmit),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

enum _OverrideScope { turn, session }

const _approvalPolicyOptions = ['', 'on-request', 'on-failure', 'never'];
const _sandboxModeOptions = [
  '',
  'readOnly',
  'workspaceWrite',
  'dangerFullAccess',
];

class _OverrideScopeSelector extends StatelessWidget {
  const _OverrideScopeSelector({required this.scope, required this.onChanged});

  final _OverrideScope scope;
  final ValueChanged<_OverrideScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<_OverrideScope>(
      segments: [
        ButtonSegment(
          value: _OverrideScope.turn,
          icon: const Icon(Icons.send_outlined),
          label: Text(l10n.overrideTurnScope),
        ),
        ButtonSegment(
          value: _OverrideScope.session,
          icon: const Icon(Icons.forum_outlined),
          label: Text(l10n.overrideSessionScope),
        ),
      ],
      selected: {scope},
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}

class _PermissionsOverrideResult {
  const _PermissionsOverrideResult({
    required this.scope,
    required this.approvalPolicy,
    required this.sandboxPolicy,
    required this.permissionProfile,
  });

  final _OverrideScope scope;
  final Object? approvalPolicy;
  final Map<String, Object?> sandboxPolicy;
  final String? permissionProfile;
}

class _PermissionsOverrideSheet extends StatefulWidget {
  const _PermissionsOverrideSheet({
    required this.controller,
    this.permissionProfileListController,
  });

  final CodexConfigOverrideController controller;
  final PermissionProfileListController? permissionProfileListController;

  @override
  State<_PermissionsOverrideSheet> createState() =>
      _PermissionsOverrideSheetState();
}

class _PermissionsOverrideSheetState extends State<_PermissionsOverrideSheet> {
  late _OverrideScope _scope;
  late String _approvalPolicy;
  late String _permissionProfile;
  late String _sandboxMode;
  late bool _networkAccess;

  @override
  void initState() {
    super.initState();
    _scope = _OverrideScope.turn;
    _loadScopeValues();
    unawaited(_refreshPermissionProfiles());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.permissionsCommandTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _OverrideScopeSelector(
              scope: _scope,
              onChanged: (scope) {
                setState(() {
                  _scope = scope;
                  _loadScopeValues();
                });
              },
            ),
            const SizedBox(height: 12),
            _OverrideDropdown(
              key: const ValueKey('chat-permissions-command-approval-policy'),
              label: l10n.approvalPolicy,
              value: _approvalPolicy,
              values: _approvalPolicyOptions,
              defaultLabel: l10n.serverDefaultOption,
              onChanged: (value) {
                setState(() => _approvalPolicy = value);
              },
            ),
            const SizedBox(height: 12),
            if (widget.permissionProfileListController != null) ...[
              _PermissionProfileSelector(
                controller: widget.permissionProfileListController!,
                value: _permissionProfile,
                onChanged: _handlePermissionProfileChanged,
              ),
              const SizedBox(height: 12),
            ],
            _OverrideDropdown(
              key: const ValueKey('chat-permissions-command-sandbox-mode'),
              label: l10n.sandboxMode,
              value: _sandboxMode,
              values: _sandboxModeOptions,
              defaultLabel: l10n.serverDefaultOption,
              enabled: _permissionProfile.isEmpty,
              onChanged: (value) {
                setState(() => _sandboxMode = value);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('chat-permissions-command-network-access'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.networkAccess),
              value: _networkAccess,
              onChanged: _sandboxMode.isEmpty || _permissionProfile.isNotEmpty
                  ? null
                  : (value) => setState(() => _networkAccess = value),
            ),
            if (_isHighRisk) ...[
              const SizedBox(height: 8),
              _PermissionsRiskWarning(message: l10n.permissionsHighRiskWarning),
            ],
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.approvalCancel),
                ),
                FilledButton.icon(
                  key: const ValueKey('chat-permissions-command-apply'),
                  onPressed: _apply,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyPermissionsOverride),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isHighRisk {
    return isHighRiskPermissionValue(
      approvalPolicy: _approvalPolicy,
      sandboxMode: _sandboxMode,
      permissionProfile: _permissionProfile,
    );
  }

  void _apply() {
    Navigator.of(context).pop(
      _PermissionsOverrideResult(
        scope: _scope,
        approvalPolicy: _approvalPolicy,
        sandboxPolicy: _sandboxPolicy(),
        permissionProfile: _permissionProfile.isEmpty
            ? null
            : _permissionProfile,
      ),
    );
  }

  void _loadScopeValues() {
    final overrides = _overridesForScope(widget.controller, _scope);
    _approvalPolicy = _supportedOption(
      configOverrideValueLabel(overrides.approvalPolicy) ?? '',
      _approvalPolicyOptions,
    );
    _permissionProfile = overrides.permissionProfile ?? '';
    final sandboxPolicy = overrides.sandboxPolicy;
    if (_permissionProfile.isNotEmpty) {
      _sandboxMode = '';
      _networkAccess = false;
    } else {
      _sandboxMode = _supportedOption(
        sandboxPolicy?['type'] as String? ?? '',
        _sandboxModeOptions,
      );
      _networkAccess = sandboxPolicy?['networkAccess'] as bool? ?? false;
    }
  }

  Map<String, Object?> _sandboxPolicy() {
    if (_permissionProfile.isNotEmpty || _sandboxMode.isEmpty) {
      return {};
    }
    return {'type': _sandboxMode, 'networkAccess': _networkAccess};
  }

  Future<void> _refreshPermissionProfiles() async {
    await widget.permissionProfileListController?.refresh(
      cwd: widget.controller.resolved.cwd,
    );
  }

  void _handlePermissionProfileChanged(String value) {
    setState(() {
      _permissionProfile = value;
      if (_permissionProfile.isNotEmpty) {
        _sandboxMode = '';
        _networkAccess = false;
      }
    });
  }
}

String _supportedOption(String value, List<String> options) {
  return options.contains(value) ? value : '';
}

class _PermissionProfileSelector extends StatelessWidget {
  const _PermissionProfileSelector({
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  final PermissionProfileListController controller;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _PermissionProfileSelectorContent(
        controller: controller,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _PermissionProfileSelectorContent extends StatelessWidget {
  const _PermissionProfileSelectorContent({
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  final PermissionProfileListController controller;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profiles = controller.profiles;
    final ids = profiles.map((profile) => profile.id).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.permissionProfile,
            border: const OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey(
                'chat-permissions-command-permission-profile',
              ),
              value: value,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(l10n.serverDefaultOption),
                ),
                if (value.isNotEmpty && !ids.contains(value))
                  DropdownMenuItem(value: value, child: Text(value)),
                for (final profile in profiles)
                  DropdownMenuItem(
                    value: profile.id,
                    enabled: profile.allowed,
                    child: Text(_profileLabel(l10n, profile)),
                  ),
              ],
              onChanged: (selected) => onChanged(selected ?? ''),
            ),
          ),
        ),
        if (controller.status == PermissionProfileListStatus.loading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ] else if (controller.status == PermissionProfileListStatus.failed) ...[
          const SizedBox(height: 8),
          Text(
            chatSummaryMessageWithOptionalDetail(
              l10n,
              l10n.permissionProfileLoadFailed,
              controller.error,
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ] else if (controller.status == PermissionProfileListStatus.loaded &&
            profiles.isEmpty) ...[
          const SizedBox(height: 8),
          Text(l10n.permissionProfilesEmpty),
        ],
      ],
    );
  }

  String _profileLabel(
    AppLocalizations l10n,
    PermissionProfileSummary profile,
  ) {
    if (profile.allowed) {
      return profile.label;
    }
    return '${profile.label} / ${l10n.permissionProfileUnavailable}';
  }
}

class _OverrideDropdown extends StatelessWidget {
  const _OverrideDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.defaultLabel,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String value;
  final List<String> values;
  final String defaultLabel;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: [
            for (final option in values)
              DropdownMenuItem(
                value: option,
                child: Text(option.isEmpty ? defaultLabel : option),
              ),
          ],
          onChanged: enabled
              ? (value) {
                  if (value != null) {
                    onChanged(value);
                  }
                }
              : null,
        ),
      ),
    );
  }
}

class _PermissionsRiskWarning extends StatelessWidget {
  const _PermissionsRiskWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelOverrideResult {
  const _ModelOverrideResult({
    required this.scope,
    required this.model,
    required this.effort,
  });

  final _OverrideScope scope;
  final String model;
  final String effort;
}

class _ModelOverrideSheet extends StatefulWidget {
  const _ModelOverrideSheet({
    required this.controller,
    this.modelListController,
  });

  final CodexConfigOverrideController controller;
  final ModelListController? modelListController;

  @override
  State<_ModelOverrideSheet> createState() => _ModelOverrideSheetState();
}

class _ModelOverrideSheetState extends State<_ModelOverrideSheet> {
  late _OverrideScope _scope;
  late final TextEditingController _modelController;
  late final TextEditingController _effortController;

  @override
  void initState() {
    super.initState();
    _scope = _OverrideScope.turn;
    final overrides = _overridesForScope(widget.controller, _scope);
    _modelController = TextEditingController(text: overrides.model ?? '');
    _effortController = TextEditingController(text: overrides.effort ?? '');
    unawaited(widget.modelListController?.refresh());
  }

  @override
  void dispose() {
    _modelController.dispose();
    _effortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.modelCommandTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _OverrideScopeSelector(
              scope: _scope,
              onChanged: (scope) {
                setState(() {
                  _scope = scope;
                  _loadScopeValues();
                });
              },
            ),
            const SizedBox(height: 12),
            _ModelListPicker(
              controller: widget.modelListController,
              modelController: _modelController,
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-model-command-model',
              controller: _modelController,
              label: l10n.modelOverride,
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-model-command-effort',
              controller: _effortController,
              label: l10n.effortOverride,
            ),
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.approvalCancel),
                ),
                FilledButton.icon(
                  key: const ValueKey('chat-model-command-apply'),
                  onPressed: _apply,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyModelOverride),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _apply() {
    Navigator.of(context).pop(
      _ModelOverrideResult(
        scope: _scope,
        model: _modelController.text,
        effort: _effortController.text,
      ),
    );
  }

  void _loadScopeValues() {
    final overrides = _overridesForScope(widget.controller, _scope);
    _modelController.text = overrides.model ?? '';
    _effortController.text = overrides.effort ?? '';
  }
}

class _ModelListPicker extends StatelessWidget {
  const _ModelListPicker({
    required this.controller,
    required this.modelController,
  });

  final ModelListController? controller;
  final TextEditingController modelController;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.models.isEmpty) {
          return const SizedBox.shrink();
        }
        final selectedModel =
            controller.models.any((model) => model.id == modelController.text)
            ? modelController.text
            : null;
        return InputDecorator(
          decoration: InputDecoration(
            labelText: context.l10n.modelList,
            border: const OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey('chat-model-command-model-list'),
              value: selectedModel,
              isExpanded: true,
              itemHeight: null,
              selectedItemBuilder: (context) => [
                for (final model in controller.models)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      codexModelDisplayLabel(context, model),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              items: [
                for (final model in controller.models)
                  DropdownMenuItem(
                    value: model.id,
                    child: _ModelPickerMenuItem(model: model),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  modelController.text = value;
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _ModelPickerMenuItem extends StatelessWidget {
  const _ModelPickerMenuItem({required this.model});

  final CodexModelSummary model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final capabilitySummary = codexModelCapabilitySummary(context, model);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            codexModelDisplayLabel(context, model),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (capabilitySummary != null) ...[
            const SizedBox(height: 2),
            Text(
              capabilitySummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonalityOverrideResult {
  const _PersonalityOverrideResult({
    required this.scope,
    required this.personality,
  });

  final _OverrideScope scope;
  final String personality;
}

class _PersonalityOverrideSheet extends StatefulWidget {
  const _PersonalityOverrideSheet({required this.controller});

  final CodexConfigOverrideController controller;

  @override
  State<_PersonalityOverrideSheet> createState() =>
      _PersonalityOverrideSheetState();
}

class _PersonalityOverrideSheetState extends State<_PersonalityOverrideSheet> {
  late _OverrideScope _scope;
  late final TextEditingController _personalityController;

  @override
  void initState() {
    super.initState();
    _scope = _OverrideScope.turn;
    final overrides = _overridesForScope(widget.controller, _scope);
    _personalityController = TextEditingController(
      text: overrides.personality ?? '',
    );
  }

  @override
  void dispose() {
    _personalityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.personalityCommandTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _OverrideScopeSelector(
              scope: _scope,
              onChanged: (scope) {
                setState(() {
                  _scope = scope;
                  _loadScopeValues();
                });
              },
            ),
            const SizedBox(height: 12),
            ConfigOverrideField(
              keyValue: 'chat-personality-command-personality',
              controller: _personalityController,
              label: l10n.personalityOverride,
            ),
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.approvalCancel),
                ),
                FilledButton.icon(
                  key: const ValueKey('chat-personality-command-apply'),
                  onPressed: _apply,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyPersonalityOverride),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _apply() {
    Navigator.of(context).pop(
      _PersonalityOverrideResult(
        scope: _scope,
        personality: _personalityController.text,
      ),
    );
  }

  void _loadScopeValues() {
    final overrides = _overridesForScope(widget.controller, _scope);
    _personalityController.text = overrides.personality ?? '';
  }
}

CodexConfigOverrides _overridesForScope(
  CodexConfigOverrideController controller,
  _OverrideScope scope,
) {
  return switch (scope) {
    _OverrideScope.turn => controller.layers.turn,
    _OverrideScope.session => controller.layers.session,
  };
}

class _ChatConnectionControls extends StatelessWidget {
  const _ChatConnectionControls({
    required this.profiles,
    required this.selectedProfile,
    required this.connectedProfile,
    required this.hostSessions,
    required this.status,
    required this.connectionLabel,
    required this.profileLoadError,
    required this.onProfileSelected,
  });

  final List<SshProfile> profiles;
  final SshProfile? selectedProfile;
  final SshProfile? connectedProfile;
  final List<HostSessionSummary> hostSessions;
  final CodexSessionStatus status;
  final String connectionLabel;
  final Object? profileLoadError;
  final ValueChanged<SshProfile>? onProfileSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeProfile = connectedProfile ?? selectedProfile;
    final hostStatusByProfileId = {
      for (final session in hostSessions) session.profile.id: session.status,
      if (connectedProfile != null) connectedProfile!.id: status,
    };
    final canOpen =
        onProfileSelected != null &&
        status != CodexSessionStatus.connecting &&
        status != CodexSessionStatus.disconnecting;
    return PopupMenuButton<SshProfile>(
      key: const ValueKey('chat-host-selector'),
      enabled: canOpen,
      tooltip: l10n.host,
      onSelected: onProfileSelected,
      itemBuilder: (context) => [
        if (profileLoadError != null)
          PopupMenuItem<SshProfile>(
            enabled: false,
            child: Text(
              '${l10n.savedHosts}: $profileLoadError',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (profiles.isEmpty)
          PopupMenuItem<SshProfile>(
            enabled: false,
            child: Text(l10n.noSavedHosts),
          ),
        for (final profile in profiles)
          PopupMenuItem<SshProfile>(
            key: ValueKey('chat-host-option-${profile.id}'),
            value: profile,
            child: _HostMenuItem(
              profile: profile,
              selected: activeProfile?.id == profile.id,
              status: hostStatusByProfileId[profile.id],
            ),
          ),
      ],
      child: _HostSelectorPill(
        label: activeProfile == null
            ? connectionLabel
            : _chatProfileTitle(activeProfile),
        connected: status == CodexSessionStatus.connected,
        busy:
            status == CodexSessionStatus.connecting ||
            status == CodexSessionStatus.reconnecting ||
            status == CodexSessionStatus.disconnecting,
        enabled: canOpen,
      ),
    );
  }
}

class _HostSelectorPill extends StatelessWidget {
  const _HostSelectorPill({
    required this.label,
    required this.connected,
    required this.busy,
    required this.enabled,
  });

  final String label;
  final bool connected;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.45);
    final borderColor = connected ? colorScheme.primary : colorScheme.outline;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: connected
              ? colorScheme.primaryContainer.withValues(alpha: 0.45)
              : colorScheme.surface,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(
                connected ? Icons.dns : Icons.dns_outlined,
                size: 18,
                color: foreground,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: foreground),
          ],
        ),
      ),
    );
  }
}

class _HostMenuItem extends StatelessWidget {
  const _HostMenuItem({
    required this.profile,
    required this.selected,
    this.status,
  });

  final SshProfile profile;
  final bool selected;
  final CodexSessionStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final statusLabel = _chatHostStatusLabel(l10n, status);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Row(
        children: [
          Icon(selected ? Icons.check : _chatAuthIcon(profile.authType)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _chatProfileTitle(profile),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  profile.endpoint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (statusLabel != null) ...[
            const SizedBox(width: 8),
            _HostStatusChip(
              key: ValueKey('chat-host-status-${profile.id}'),
              label: statusLabel,
              status: status!,
            ),
          ],
        ],
      ),
    );
  }
}

class _HostStatusChip extends StatelessWidget {
  const _HostStatusChip({super.key, required this.label, required this.status});

  final String label;
  final CodexSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active =
        status == CodexSessionStatus.connected ||
        status == CodexSessionStatus.reconnecting;
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: active ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      ),
      backgroundColor: active
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
    );
  }
}

String? _chatHostStatusLabel(
  AppLocalizations l10n,
  CodexSessionStatus? status,
) {
  return switch (status) {
    CodexSessionStatus.connecting => l10n.connecting,
    CodexSessionStatus.connected => l10n.connected,
    CodexSessionStatus.reconnecting => l10n.reconnecting,
    CodexSessionStatus.disconnecting => l10n.disconnecting,
    CodexSessionStatus.failed => l10n.connectionFailed,
    CodexSessionStatus.idle || null => null,
  };
}

String _chatProfileTitle(SshProfile profile) {
  return profile.displayName;
}

IconData _chatAuthIcon(SshAuthType authType) {
  return switch (authType) {
    SshAuthType.password => Icons.password,
    SshAuthType.privateKey => Icons.vpn_key_outlined,
  };
}

double _sidebarWidthFor(double maxWidth) {
  if (maxWidth <= 320) {
    return maxWidth;
  }
  if (maxWidth < 720) {
    return maxWidth * 0.88;
  }
  return 320;
}

class _ChatActivityStrip extends StatelessWidget {
  const _ChatActivityStrip({
    required this.sidebarVisible,
    required this.onToggleSidebar,
    required this.sessionController,
    required this.turnController,
    required this.timelineController,
    required this.statusLineParts,
    required this.connectionControls,
  });

  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;
  final CodexSessionStateController? sessionController;
  final TurnController? turnController;
  final ChatTimelineController? timelineController;
  final List<String> statusLineParts;
  final Widget connectionControls;

  @override
  Widget build(BuildContext context) {
    final timelineController = this.timelineController;
    if (timelineController == null) {
      return _buildBody();
    }
    return AnimatedBuilder(
      animation: timelineController,
      builder: (context, _) => _buildBody(),
    );
  }

  Widget _buildBody() {
    return _ChatActivityStripBody(
      sidebarVisible: sidebarVisible,
      onToggleSidebar: onToggleSidebar,
      sessionController: sessionController,
      turnController: turnController,
      timelineController: timelineController,
      statusLineParts: statusLineParts,
      connectionControls: connectionControls,
    );
  }
}

class _ChatActivityStripBody extends StatelessWidget {
  const _ChatActivityStripBody({
    required this.sidebarVisible,
    required this.onToggleSidebar,
    required this.sessionController,
    required this.turnController,
    required this.timelineController,
    required this.statusLineParts,
    required this.connectionControls,
  });

  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;
  final CodexSessionStateController? sessionController;
  final TurnController? turnController;
  final ChatTimelineController? timelineController;
  final List<String> statusLineParts;
  final Widget connectionControls;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final turn = turnController;
    final failed = turn?.status == TurnControllerStatus.failed;
    final busy = turn?.isBusy == true;
    final running = turn?.activeTurnId?.trim().isNotEmpty == true;
    final indicator = failed
        ? colorScheme.error
        : busy
        ? colorScheme.tertiary
        : running
        ? colorScheme.primary
        : colorScheme.outline;
    final status = _chatActivityStateLabel(
      l10n,
      turn,
      sessionController?.status,
    );
    final hostState = sessionStatusLabel(l10n, sessionController?.status);
    final turnStatus = turn == null
        ? null
        : _chatActivityTurnStatusLabel(l10n, turn);
    final activityDetail = _timelineActivityDetail(l10n, timelineController);
    final details = [
      if (turnStatus != null && turnStatus != status) turnStatus,
      ?activityDetail,
      if (hostState != status && hostState != turnStatus) hostState,
    ];

    final active = busy || running;
    return Material(
      color: active
          ? Color.alphaBlend(
              indicator.withValues(alpha: 0.08),
              colorScheme.surfaceContainerLowest,
            )
          : colorScheme.surfaceContainerLow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active
                  ? indicator.withValues(alpha: 0.48)
                  : colorScheme.outlineVariant,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: (active ? indicator : colorScheme.shadow).withValues(
                alpha: active ? 0.12 : 0.04,
              ),
              blurRadius: active ? 16 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                PositionedDirectional(
                  key: const ValueKey('chat-activity-rail'),
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: ColoredBox(
                    color: active
                        ? indicator
                        : indicator.withValues(alpha: 0.38),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 8, 5),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('chat-session-sidebar-toggle'),
                        tooltip: l10n.sessions,
                        onPressed: onToggleSidebar,
                        style: IconButton.styleFrom(
                          backgroundColor: sidebarVisible
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          foregroundColor: sidebarVisible
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size.square(36),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.menu),
                      ),
                      const SizedBox(width: 5),
                      _ChatTuiStatusMark(
                        key: const ValueKey('chat-tui-status-mark'),
                        color: indicator,
                        active: active,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ChatTuiStatusLine(
                          status: status,
                          details: details,
                          statusLineParts: statusLineParts,
                          color: indicator,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: connectionControls,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (active)
              DecoratedBox(
                key: const ValueKey('chat-running-progress'),
                decoration: BoxDecoration(
                  color: indicator.withValues(alpha: 0.14),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: busy ? 0.42 : 1,
                    child: ColoredBox(
                      color: indicator,
                      child: const SizedBox(height: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatTuiStatusLine extends StatelessWidget {
  const _ChatTuiStatusLine({
    required this.status,
    required this.details,
    required this.statusLineParts,
    required this.color,
  });

  final String status;
  final List<String> details;
  final List<String> statusLineParts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color.withValues(alpha: 0.42)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  child: Text(
                    status,
                    key: const ValueKey('chat-activity-status'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.72,
                    ),
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    child: Text(
                      details.join('  |  '),
                      key: const ValueKey('chat-activity-detail'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (statusLineParts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            key: const ValueKey('chat-status-line'),
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final part in statusLineParts)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      part,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChatTuiStatusMark extends StatelessWidget {
  const _ChatTuiStatusMark({
    super.key,
    required this.color,
    required this.active,
  });

  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.20 : 0.08),
        border: Border.all(
          color: color.withValues(alpha: active ? 0.72 : 0.45),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Container(
        width: active ? 8 : 6,
        height: active ? 8 : 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

String? _timelineActivityDetail(
  AppLocalizations l10n,
  ChatTimelineController? controller,
) {
  final turns = controller?.turns;
  if (turns == null || turns.isEmpty) {
    return null;
  }
  ChatTimelineTurn? activeTurn;
  for (final turn in turns.reversed) {
    if (!_isTerminalTurnStatus(turn.status)) {
      activeTurn = turn;
      break;
    }
  }
  if (activeTurn == null) {
    return null;
  }
  for (final item in activeTurn.items.reversed) {
    final title = _timelineActivityItemTitle(l10n, item);
    if (title != null) {
      return title;
    }
  }
  return null;
}

String? _timelineActivityItemTitle(
  AppLocalizations l10n,
  ChatTimelineItem item,
) {
  return switch (item.itemType) {
    'commandExecution' when item.command != null =>
      '${l10n.timelineCommand}: ${item.command}',
    'commandExecution' => l10n.timelineCommand,
    'fileChange' when item.fileChanges.isNotEmpty =>
      '${l10n.timelineFileChanges}: ${item.fileChanges.length}',
    'fileChange' => l10n.timelineFileChanges,
    'mcpToolCall' when item.server != null && item.tool != null =>
      '${l10n.timelineTool}: ${item.server}/${item.tool}',
    'mcpToolCall' when item.tool != null =>
      '${l10n.timelineTool}: ${item.tool}',
    'mcpToolCall' ||
    'dynamicToolCall' ||
    'collabAgentToolCall' => l10n.timelineToolCall,
    'reasoning' => l10n.timelineReasoning,
    'plan' => l10n.timelinePlan,
    _ => null,
  };
}

String _chatActivityStateLabel(
  AppLocalizations l10n,
  TurnController? controller,
  CodexSessionStatus? sessionStatus,
) {
  if (controller == null) {
    return sessionStatusLabel(l10n, sessionStatus);
  }
  if (controller.status == TurnControllerStatus.failed) {
    return l10n.statusFailed;
  }
  if (controller.isBusy) {
    return l10n.statusWorking;
  }
  if (controller.activeTurnId?.trim().isNotEmpty == true) {
    return l10n.statusRunning;
  }
  return sessionStatusLabel(l10n, sessionStatus);
}

String _chatActivityTurnStatusLabel(
  AppLocalizations l10n,
  TurnController controller,
) {
  return switch (controller.status) {
    TurnControllerStatus.idle => l10n.statusIdle,
    TurnControllerStatus.startingThread => l10n.startingThread,
    TurnControllerStatus.resumingThread => l10n.resumingThread,
    TurnControllerStatus.sendingTurn => l10n.sendingTurn,
    TurnControllerStatus.submitted => l10n.sendingTurn,
    TurnControllerStatus.completed => l10n.turnCompleted,
    TurnControllerStatus.interrupting => l10n.interruptingTurn,
    TurnControllerStatus.interrupted => l10n.turnInterrupted,
    TurnControllerStatus.failed => turnControllerErrorMessage(
      l10n,
      controller.error,
    ),
  };
}

class _ChatMainConversation extends StatefulWidget {
  const _ChatMainConversation({
    required this.compact,
    required this.sideConversation,
    required this.canReturnToMain,
    required this.onReturnToMain,
    required this.timelineController,
    required this.showRawTranscript,
  });

  final bool compact;
  final _SideConversation? sideConversation;
  final bool canReturnToMain;
  final VoidCallback onReturnToMain;
  final ChatTimelineController? timelineController;
  final bool showRawTranscript;

  @override
  State<_ChatMainConversation> createState() => _ChatMainConversationState();
}

class _ChatMainConversationState extends State<_ChatMainConversation> {
  final ScrollController _scrollController = ScrollController();
  String? _lastSelectedThreadId;
  bool _nearBottom = true;
  bool _showJumpToLatest = false;

  @override
  void initState() {
    super.initState();
    _lastSelectedThreadId = widget.timelineController?.selectedThreadId;
    _scrollController.addListener(_handleScroll);
    widget.timelineController?.addListener(_handleTimelineChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
  }

  @override
  void didUpdateWidget(_ChatMainConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timelineController != widget.timelineController) {
      oldWidget.timelineController?.removeListener(_handleTimelineChanged);
      widget.timelineController?.addListener(_handleTimelineChanged);
      _lastSelectedThreadId = widget.timelineController?.selectedThreadId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
    }
  }

  @override
  void dispose() {
    widget.timelineController?.removeListener(_handleTimelineChanged);
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final nearBottom = _scrollController.position.extentAfter < 96;
    if (nearBottom != _nearBottom || (_showJumpToLatest && nearBottom)) {
      setState(() {
        _nearBottom = nearBottom;
        if (nearBottom) {
          _showJumpToLatest = false;
        }
      });
    }
  }

  void _handleTimelineChanged() {
    final selectedThreadId = widget.timelineController?.selectedThreadId;
    final selectedThreadChanged = selectedThreadId != _lastSelectedThreadId;
    _lastSelectedThreadId = selectedThreadId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (selectedThreadChanged) {
        _jumpToLatest();
        return;
      }
      if (_nearBottom) {
        _animateToLatest();
      } else if (!_showJumpToLatest) {
        setState(() => _showJumpToLatest = true);
      }
    });
  }

  void _jumpToLatest() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    if (mounted) {
      setState(() {
        _nearBottom = true;
        _showJumpToLatest = false;
      });
    }
  }

  void _animateToLatest() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
    if (mounted && _showJumpToLatest) {
      setState(() => _showJumpToLatest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLowest),
      child: Stack(
        children: [
          ListView(
            key: const ValueKey('chat-main-conversation'),
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              widget.compact ? 8 : 16,
              widget.compact ? 8 : 14,
              widget.compact ? 8 : 16,
              widget.compact ? 48 : 52,
            ),
            children: [
              if (widget.sideConversation != null)
                _SideConversationPanel(
                  conversation: widget.sideConversation!,
                  canReturn: widget.canReturnToMain,
                  onReturn: widget.onReturnToMain,
                ),
              _ChatTimelinePanel(
                controller: widget.timelineController,
                showRaw: widget.showRawTranscript,
              ),
            ],
          ),
          if (_showJumpToLatest)
            PositionedDirectional(
              end: widget.compact ? 8 : 16,
              bottom: widget.compact ? 8 : 12,
              child: FilledButton.tonalIcon(
                key: const ValueKey('chat-jump-to-latest'),
                onPressed: _jumpToLatest,
                icon: const Icon(Icons.south, size: 17),
                label: Text(context.l10n.timelineJumpToLatest),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatThreadSidebar extends StatelessWidget {
  const _ChatThreadSidebar({required this.overlay, required this.child});

  final bool overlay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: overlay ? 8 : 0,
      color: colorScheme.surfaceContainerLowest,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            end: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: ListView(
          key: const ValueKey('chat-session-sidebar'),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          children: [child],
        ),
      ),
    );
  }
}

class _ChatSidebarWorkspaceHeader extends StatelessWidget {
  const _ChatSidebarWorkspaceHeader({
    required this.workspace,
    required this.onOpenAdvanced,
  });

  final String workspace;
  final VoidCallback? onOpenAdvanced;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      key: const ValueKey('chat-sidebar-workspace-header'),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                Icons.folder_copy_outlined,
                size: 17,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.workspaceFilesRootLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    workspace,
                    key: const ValueKey('chat-sidebar-workspace-summary'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              key: const ValueKey('chat-sidebar-advanced-controls'),
              onPressed: onOpenAdvanced,
              tooltip: l10n.showChatAdvancedControls,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: const Icon(Icons.tune, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatAdvancedControlsSheet extends StatelessWidget {
  const _ChatAdvancedControlsSheet({
    required this.configOverrideController,
    required this.rawRpcSender,
    required this.onApplySessionOverrides,
  });

  final CodexConfigOverrideController? configOverrideController;
  final RawRpcSender? rawRpcSender;
  final Future<void> Function(CodexConfigOverrides overrides)?
  onApplySessionOverrides;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = configOverrideController;
    return FractionallySizedBox(
      key: const ValueKey('chat-advanced-controls-sheet'),
      heightFactor: 0.88,
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.62,
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      Icons.tune,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.showChatAdvancedControls,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('chat-advanced-controls-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (controller != null) ...[
                    SessionOverrideControls(
                      controller: controller,
                      onApplySessionOverrides: onApplySessionOverrides,
                    ),
                    const SizedBox(height: 10),
                    TurnOverrideControls(controller: controller),
                    const SizedBox(height: 10),
                  ],
                  RawRpcPanel(onSend: rawRpcSender),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadListPanel extends StatelessWidget {
  const _ThreadListPanel({
    required this.controller,
    required this.detailController,
    required this.archived,
    required this.onArchivedChanged,
    required this.onUnarchiveThread,
  });

  final ThreadListController? controller;
  final ThreadDetailController? detailController;
  final bool archived;
  final ValueChanged<bool> onArchivedChanged;
  final Future<void> Function(ThreadSummary thread)? onUnarchiveThread;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return _ThreadListCard(
        title: context.l10n.sessions,
        child: Text(context.l10n.connectBeforeLoadingThreads),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _ThreadListContent(
        controller: controller,
        detailController: detailController,
        archived: archived,
        onArchivedChanged: onArchivedChanged,
        onUnarchiveThread: onUnarchiveThread,
      ),
    );
  }
}

class _ThreadListContent extends StatelessWidget {
  const _ThreadListContent({
    required this.controller,
    required this.detailController,
    required this.archived,
    required this.onArchivedChanged,
    required this.onUnarchiveThread,
  });

  final ThreadListController controller;
  final ThreadDetailController? detailController;
  final bool archived;
  final ValueChanged<bool> onArchivedChanged;
  final Future<void> Function(ThreadSummary thread)? onUnarchiveThread;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = l10n.sessions;
    return switch (controller.status) {
      ThreadListStatus.idle => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(
          controller: controller,
          archived: archived,
        ),
        modeControl: _ThreadListModeSelector(
          archived: archived,
          onChanged: onArchivedChanged,
        ),
        child: Text(l10n.connectBeforeLoadingThreads),
      ),
      ThreadListStatus.loading => _ThreadListCard(
        title: title,
        modeControl: _ThreadListModeSelector(
          archived: archived,
          onChanged: onArchivedChanged,
        ),
        child: const LinearProgressIndicator(),
      ),
      ThreadListStatus.failed => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(
          controller: controller,
          archived: archived,
        ),
        modeControl: _ThreadListModeSelector(
          archived: archived,
          onChanged: onArchivedChanged,
        ),
        child: Text(
          controller.error?.toString() ?? l10n.threadListFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      ThreadListStatus.loaded when controller.threads.isEmpty =>
        _ThreadListCard(
          title: title,
          action: _RefreshThreadsButton(
            controller: controller,
            archived: archived,
          ),
          modeControl: _ThreadListModeSelector(
            archived: archived,
            onChanged: onArchivedChanged,
          ),
          child: Text(archived ? l10n.noArchivedThreads : l10n.noThreads),
        ),
      ThreadListStatus.loaded => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(
          controller: controller,
          archived: archived,
        ),
        modeControl: _ThreadListModeSelector(
          archived: archived,
          onChanged: onArchivedChanged,
        ),
        child: Column(
          children: [
            for (final thread in controller.threads)
              _ThreadListTile(
                thread: thread,
                detailController: detailController,
                archived: archived,
                onUnarchiveThread: onUnarchiveThread,
              ),
          ],
        ),
      ),
    };
  }
}

class _ThreadListCard extends StatelessWidget {
  const _ThreadListCard({
    required this.title,
    required this.child,
    this.action,
    this.modeControl,
  });

  final String title;
  final Widget child;
  final Widget? action;
  final Widget? modeControl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 2, 0, 4),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const SizedBox(width: 4, height: 20),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.forum_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ),
        if (modeControl != null) ...[const SizedBox(height: 4), modeControl!],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, color: colorScheme.outlineVariant),
        ),
        child,
      ],
    );
  }
}

class _RefreshThreadsButton extends StatelessWidget {
  const _RefreshThreadsButton({
    required this.controller,
    required this.archived,
  });

  final ThreadListController controller;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.refreshThreads,
      onPressed: () => controller.refresh(archived: archived),
      icon: const Icon(Icons.refresh),
    );
  }
}

class _ThreadListModeSelector extends StatelessWidget {
  const _ThreadListModeSelector({
    required this.archived,
    required this.onChanged,
  });

  final bool archived;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThreadListModeButton(
              key: const ValueKey('chat-thread-mode-active'),
              selected: !archived,
              icon: Icons.forum_outlined,
              label: l10n.activeThreads,
              onPressed: () => onChanged(false),
            ),
            const SizedBox(height: 4),
            _ThreadListModeButton(
              key: const ValueKey('chat-thread-mode-archived'),
              selected: archived,
              icon: Icons.archive_outlined,
              label: l10n.archivedThreads,
              onPressed: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadListModeButton extends StatelessWidget {
  const _ThreadListModeButton({
    super.key,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return Tooltip(
      message: label,
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.68)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: Stack(
            children: [
              PositionedDirectional(
                start: 0,
                top: 5,
                bottom: 5,
                width: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 8, 7),
                child: Row(
                  children: [
                    Icon(icon, size: 17, color: foreground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check, size: 16, color: colorScheme.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadListTile extends StatelessWidget {
  const _ThreadListTile({
    required this.thread,
    required this.detailController,
    required this.archived,
    required this.onUnarchiveThread,
  });

  final ThreadSummary thread;
  final ThreadDetailController? detailController;
  final bool archived;
  final Future<void> Function(ThreadSummary thread)? onUnarchiveThread;

  @override
  Widget build(BuildContext context) {
    final selected = detailController?.selectedThreadId == thread.id;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    return Material(
      key: ValueKey('thread-summary-${thread.id}'),
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.52)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: detailController == null
            ? null
            : () => detailController!.readThread(thread.id),
        child: Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 5,
              bottom: 5,
              width: 3,
              child: DecoratedBox(
                key: ValueKey('thread-summary-rail-${thread.id}'),
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 2, 5),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primary.withValues(alpha: 0.14)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      selected ? Icons.chat_bubble : Icons.chat_bubble_outline,
                      size: 16,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      thread.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (archived)
                    SizedBox.square(
                      dimension: 30,
                      child: IconButton(
                        tooltip: context.l10n.unarchiveThread,
                        onPressed: onUnarchiveThread == null
                            ? null
                            : () => unawaited(onUnarchiveThread!(thread)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.unarchive_outlined, size: 17),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTimelinePanel extends StatelessWidget {
  const _ChatTimelinePanel({required this.controller, required this.showRaw});

  final ChatTimelineController? controller;
  final bool showRaw;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) =>
          _ChatTimelineContent(controller: controller, showRaw: showRaw),
    );
  }
}

class _ChatTimelineContent extends StatelessWidget {
  const _ChatTimelineContent({required this.controller, required this.showRaw});

  final ChatTimelineController controller;
  final bool showRaw;

  @override
  Widget build(BuildContext context) {
    final turns = controller.turns;
    if (turns.isEmpty) {
      return _TimelineEmptyState();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final turn in turns)
          _TimelineTurnView(turn: turn, showRaw: showRaw),
      ],
    );
  }
}

class _TimelineEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 36,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.noTimelineEvents,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTurnView extends StatelessWidget {
  const _TimelineTurnView({required this.turn, required this.showRaw});

  final ChatTimelineTurn turn;
  final bool showRaw;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('timeline-turn-${turn.turnId}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (turn.items.isEmpty)
            Text(context.l10n.noTimelineEvents)
          else
            for (final item in turn.items)
              _TimelineItemView(item: item, showRaw: showRaw),
        ],
      ),
    );
  }
}

class _TimelineItemView extends StatelessWidget {
  const _TimelineItemView({required this.item, required this.showRaw});

  final ChatTimelineItem item;
  final bool showRaw;

  @override
  Widget build(BuildContext context) {
    final body = _body;
    final title = _title(context);
    final icon = _iconFor(item.itemType);
    if (item.itemType == 'userMessage' || item.itemType == 'agentMessage') {
      return _TimelineMessageItem(
        item: item,
        title: title,
        body: body,
        rawJson: _rawJson,
        showRaw: showRaw,
      );
    }
    if (item.itemType == 'reasoning') {
      return _TimelineCollapsibleItem(
        item: item,
        title: title,
        icon: icon,
        body: body,
        rawJson: _rawJson,
        showRaw: showRaw,
      );
    }
    return _TimelineExecutionItem(
      item: item,
      title: title,
      icon: icon,
      body: body,
      rawJson: _rawJson,
      showRaw: showRaw,
    );
  }

  String get _rawJson {
    const encoder = JsonEncoder.withIndent('  ');
    final raw = item.raw.isEmpty
        ? <String, Object?>{
            'id': item.itemId,
            'type': item.itemType,
            if (item.text.isNotEmpty) 'text': item.text,
            if (item.output.isNotEmpty) 'output': item.output,
          }
        : item.raw;
    return encoder.convert(raw);
  }

  String _title(BuildContext context) {
    final l10n = context.l10n;
    return switch (item.itemType) {
      'userMessage' => l10n.timelineUser,
      'agentMessage' => l10n.timelineCodex,
      'reasoning' => l10n.timelineReasoning,
      'plan' => l10n.timelinePlan,
      'commandExecution' when item.command != null => item.command!,
      'commandExecution' => l10n.timelineCommand,
      'fileChange' => l10n.timelineFileChanges,
      'mcpToolCall' when item.server != null && item.tool != null =>
        '${item.server}/${item.tool}',
      'mcpToolCall' when item.tool != null => item.tool!,
      'mcpToolCall' ||
      'dynamicToolCall' ||
      'collabAgentToolCall' => l10n.timelineToolCall,
      _ => '${l10n.timelineItem}: ${item.itemType}',
    };
  }

  String get _body {
    if (item.output.isNotEmpty) {
      return item.output;
    }
    if (item.text.isNotEmpty) {
      return item.text;
    }
    if (item.itemType == 'commandExecution' ||
        item.itemType == 'fileChange' ||
        item.itemType == 'mcpToolCall') {
      return '';
    }
    return item.itemId;
  }

  IconData _iconFor(String itemType) {
    return switch (itemType) {
      'userMessage' => Icons.person_outline,
      'agentMessage' => Icons.smart_toy_outlined,
      'commandExecution' => Icons.terminal,
      'fileChange' => Icons.difference_outlined,
      'mcpToolCall' => Icons.extension_outlined,
      'reasoning' => Icons.psychology_outlined,
      'plan' => Icons.checklist,
      _ => Icons.notes_outlined,
    };
  }
}

class _TimelineMessageItem extends StatelessWidget {
  const _TimelineMessageItem({
    required this.item,
    required this.title,
    required this.body,
    required this.rawJson,
    required this.showRaw,
  });

  final ChatTimelineItem item;
  final String title;
  final String body;
  final String rawJson;
  final bool showRaw;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = item.itemType == 'userMessage';
    final accent = isUser ? colorScheme.primary : colorScheme.tertiary;
    final bubbleColor = isUser
        ? colorScheme.primaryContainer.withValues(alpha: 0.58)
        : colorScheme.tertiaryContainer.withValues(alpha: 0.52);
    final borderColor = isUser
        ? colorScheme.primary.withValues(alpha: 0.22)
        : colorScheme.tertiary.withValues(alpha: 0.22);
    final alignment = isUser
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd;
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: DecoratedBox(
        key: ValueKey('timeline-message-bubble-${item.itemId}'),
        decoration: BoxDecoration(
          color: bubbleColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(8),
            topEnd: const Radius.circular(8),
            bottomStart: Radius.circular(isUser ? 2 : 8),
            bottomEnd: Radius.circular(isUser ? 8 : 2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TimelineRoleLabel(
                label: title,
                foreground: accent,
                background: accent.withValues(alpha: 0.10),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 7),
                _TimelineMarkdownMessage(
                  key: ValueKey('timeline-message-markdown-${item.itemId}'),
                  text: body,
                ),
              ],
              if (showRaw) ...[
                const SizedBox(height: 8),
                SelectableText(
                  rawJson,
                  key: ValueKey('timeline-raw-${item.itemId}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Align(
        alignment: alignment,
        child: FractionallySizedBox(
          widthFactor: 0.78,
          alignment: alignment,
          child: bubble,
        ),
      ),
    );
  }
}

const _markdownMessageRawFallbackChars = 12000;
const _markdownMessageRawFallbackLines = 160;

class _TimelineMarkdownMessage extends StatelessWidget {
  const _TimelineMarkdownMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (_shouldUsePlainMessage(text)) {
      return SelectableText(
        text,
        key: const ValueKey('timeline-message-plain-raw'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.38),
      );
    }
    return WorkspaceMarkdownPreview(content: text);
  }

  bool _shouldUsePlainMessage(String value) {
    if (value.length > _markdownMessageRawFallbackChars) {
      return true;
    }
    return '\n'.allMatches(value).length > _markdownMessageRawFallbackLines;
  }
}

class _TimelineExecutionItem extends StatelessWidget {
  const _TimelineExecutionItem({
    required this.item,
    required this.title,
    required this.icon,
    required this.body,
    required this.rawJson,
    required this.showRaw,
  });

  final ChatTimelineItem item;
  final String title;
  final IconData icon;
  final String body;
  final String rawJson;
  final bool showRaw;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDiffs = item.fileChanges.any(
      (change) => change.diff.trim().isNotEmpty,
    );
    final hasBody = body.isNotEmpty;
    final accent = _timelineExecutionAccent(colorScheme, item.itemType);
    return Container(
      key: ValueKey('timeline-execution-${item.itemId}'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(
              key: ValueKey('timeline-execution-rail-${item.itemId}'),
              color: accent,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _TimelineGlyph(icon: icon, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                if (hasBody) ...[
                  const SizedBox(height: 10),
                  _TimelineBodyBlock(item: item, body: body),
                ],
                if (hasDiffs) ...[
                  const SizedBox(height: 10),
                  for (final change in item.fileChanges)
                    if (change.diff.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TimelineDiffBlock(change: change),
                      ),
                ],
                if (showRaw) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    rawJson,
                    key: ValueKey('timeline-raw-${item.itemId}'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _timelineExecutionAccent(ColorScheme colorScheme, String itemType) {
  return switch (itemType) {
    'commandExecution' => colorScheme.tertiary,
    'fileChange' => colorScheme.secondary,
    'mcpToolCall' ||
    'dynamicToolCall' ||
    'collabAgentToolCall' => colorScheme.primary,
    _ => colorScheme.outline,
  };
}

class _TimelineCollapsibleItem extends StatelessWidget {
  const _TimelineCollapsibleItem({
    required this.item,
    required this.title,
    required this.icon,
    required this.body,
    required this.rawJson,
    required this.showRaw,
  });

  final ChatTimelineItem item;
  final String title;
  final IconData icon;
  final String body;
  final String rawJson;
  final bool showRaw;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('timeline-collapsible-${item.itemId}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          dense: true,
          initiallyExpanded: false,
          leading: _TimelineGlyph(icon: icon, color: colorScheme.secondary),
          title: Text(title, style: Theme.of(context).textTheme.titleSmall),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            if (body.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: _TimelineBodyBlock(item: item, body: body),
              ),
            if (showRaw) ...[
              const SizedBox(height: 8),
              SelectableText(
                rawJson,
                key: ValueKey('timeline-raw-${item.itemId}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineGlyph extends StatelessWidget {
  const _TimelineGlyph({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }
}

class _TimelineRoleLabel extends StatelessWidget {
  const _TimelineRoleLabel({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

bool _isTerminalTurnStatus(String status) {
  return status == 'completed' || status == 'failed' || status == 'interrupted';
}

class _TimelineBodyBlock extends StatelessWidget {
  const _TimelineBodyBlock({required this.item, required this.body});

  final ChatTimelineItem item;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (item.itemType == 'commandExecution') {
      return _CollapsibleTerminalOutputBlock(itemId: item.itemId, text: body);
    }
    if (item.itemType == 'fileChange') {
      return DiffTextBlock(
        key: const ValueKey('timeline-diff-output'),
        text: body,
      );
    }
    return SelectableText(body);
  }
}

const _terminalOutputCollapseChars = 1800;
const _terminalOutputCollapseLines = 28;
const _terminalOutputSummaryLines = 5;

class _CollapsibleTerminalOutputBlock extends StatefulWidget {
  const _CollapsibleTerminalOutputBlock({
    required this.itemId,
    required this.text,
  });

  final String itemId;
  final String text;

  @override
  State<_CollapsibleTerminalOutputBlock> createState() =>
      _CollapsibleTerminalOutputBlockState();
}

class _CollapsibleTerminalOutputBlockState
    extends State<_CollapsibleTerminalOutputBlock> {
  bool _expanded = false;

  @override
  void didUpdateWidget(_CollapsibleTerminalOutputBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId || oldWidget.text != widget.text) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _terminalLines(widget.text);
    final bytes = utf8.encode(widget.text).length;
    final shouldCollapse =
        widget.text.length > _terminalOutputCollapseChars ||
        lines.length > _terminalOutputCollapseLines;
    if (!shouldCollapse || _expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TerminalOutputBlock(text: widget.text),
          if (shouldCollapse) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey(
                  'timeline-command-output-collapse-${widget.itemId}',
                ),
                onPressed: () => setState(() => _expanded = false),
                icon: const Icon(Icons.unfold_less, size: 18),
                label: Text(context.l10n.timelineCommandOutputCollapse),
              ),
            ),
          ],
        ],
      );
    }

    final colors = SadCoderThemeColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final summaryStart = lines.length > _terminalOutputSummaryLines
        ? lines.length - _terminalOutputSummaryLines
        : 0;
    final summary = lines.skip(summaryStart).join('\n').trimRight();
    return Container(
      key: ValueKey('timeline-command-output-collapsed-${widget.itemId}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.terminalBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.timelineCommandOutputSummary(lines.length, bytes),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.terminalForeground.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              summary,
              key: ValueKey('timeline-command-output-summary-${widget.itemId}'),
              style: TextStyle(
                color: colors.terminalForeground,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: ValueKey('timeline-command-output-expand-${widget.itemId}'),
              onPressed: () => setState(() => _expanded = true),
              icon: const Icon(Icons.unfold_more, size: 18),
              label: Text(context.l10n.timelineCommandOutputExpand),
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _terminalLines(String text) {
  if (text.isEmpty) {
    return const [];
  }
  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
}

class _TerminalOutputBlock extends StatelessWidget {
  const _TerminalOutputBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = SadCoderThemeColors.of(context);
    return Container(
      key: const ValueKey('timeline-terminal-output'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.terminalBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          color: colors.terminalForeground,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _TimelineDiffBlock extends StatelessWidget {
  const _TimelineDiffBlock({required this.change});

  final ThreadFileChangeSummary change;

  @override
  Widget build(BuildContext context) {
    final label = change.path.isEmpty
        ? change.kind
        : '${change.kind} ${change.path}';
    return DiffTextBlock(
      key: ValueKey('timeline-diff-output-$label'),
      text: change.diff,
      label: label,
    );
  }
}

class _SlashCommandPreview extends StatelessWidget {
  const _SlashCommandPreview({
    required this.result,
    required this.sendAsText,
    required this.onSendAsText,
  });

  final SlashCommandParseResult result;
  final bool sendAsText;
  final VoidCallback onSendAsText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sendAsTextButton = TextButton(
      key: const ValueKey('slash-command-send-as-text'),
      onPressed: onSendAsText,
      child: Text(l10n.slashCommandSendAsText),
    );
    return switch (result.kind) {
      SlashCommandParseKind.notSlash => const SizedBox.shrink(),
      SlashCommandParseKind.empty => _PreviewCard(
        icon: Icons.manage_search,
        title: l10n.slashCommands,
        subtitle: l10n.typeCommandName,
      ),
      SlashCommandParseKind.unknown => _PreviewCard(
        icon: Icons.error_outline,
        title: l10n.slashCommandUnknown('/${result.rawCommand}'),
        subtitle: sendAsText
            ? l10n.slashCommandWillSendAsPrompt
            : l10n.slashCommandNotSentAsPrompt,
        trailing: sendAsText ? null : sendAsTextButton,
      ),
      SlashCommandParseKind.known => _PreviewCard(
        icon: Icons.terminal,
        title: result.command!.slash,
        subtitle: sendAsText
            ? l10n.slashCommandWillSendAsPrompt
            : l10n.slashCommandDescription(
                result.command!.command,
                result.command!.description,
              ),
        trailing: sendAsText ? null : sendAsTextButton,
      ),
    };
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 18, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
