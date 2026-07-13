import 'dart:async';

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
import '../../models/model_list_controller.dart';
import '../../permissions/permission_profile_list_controller.dart';
import '../../plugins/plugin_list_reader.dart';
import '../../reviews/thread_review_command.dart';
import '../../session/codex_session_state_controller.dart';
import '../../session/host_session_summary.dart';
import '../../ssh/ssh_profile.dart';
import '../../ssh/ssh_profile_store.dart';
import '../../threads/agent_thread_topology.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_item_list_reader.dart';
import '../../threads/thread_list_controller.dart';
import '../../threads/thread_mutation_runner.dart';
import '../../threads/thread_summary.dart';
import '../../turns/turn_controller.dart';
import '../../turns/turn_text_element.dart';
import '../../usage/account_usage_snapshot_controller.dart';
import '../../usage/thread_token_usage_controller.dart';
import '../files/file_search_sheet.dart';
import 'chat_advanced_controls_sheet.dart';
import 'chat_agent_topology_sheet.dart';
import 'chat_apps_summary.dart';
import 'chat_activity_strip.dart';
import 'chat_background_terminal_summary.dart';
import 'chat_connection_controls.dart';
import 'chat_composer_mention.dart';
import 'chat_debug_config_summary.dart';
import 'chat_display_settings_sheets.dart';
import 'chat_diff_summary.dart';
import 'chat_experimental_summary.dart';
import 'chat_feedback_sheet.dart';
import 'chat_goal_command.dart';
import 'chat_hooks_summary.dart';
import 'chat_layout_metrics.dart';
import 'chat_mcp_command.dart';
import 'chat_memories_summary.dart';
import 'chat_model_override_sheet.dart';
import 'chat_override_scope.dart';
import 'chat_personality_override_sheet.dart';
import 'chat_permissions_override_sheet.dart';
import 'chat_plugins_command.dart';
import 'chat_plugins_summary.dart';
import 'chat_skills_summary.dart';
import 'chat_status_summary.dart';
import 'chat_timeline_controller.dart';
import 'chat_goal_summary.dart';
import 'chat_mcp_summary.dart';
import 'chat_review_summary.dart';
import 'chat_rollout_diagnostics.dart';
import 'chat_side_conversation_panel.dart';
import 'chat_slash_command_preview.dart';
import 'chat_summary_formatting.dart';
import 'chat_thread_sidebar.dart';
import 'chat_theme_sheet.dart';
import 'chat_timeline_renderer.dart';
import 'chat_usage_summary.dart';
import 'chat_timeline_view.dart';
import 'slash_command_palette.dart';

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
  final List<ChatComposerMention> _composerMentions = [];
  ChatSideConversation? _sideConversation;
  CodexSessionStatus? _lastSessionStatus;
  String? _slashTextPrompt;
  bool _slashPaletteOpen = false;
  bool _showRawTranscript = false;
  bool _showArchivedThreads = false;
  bool _showThreadSidebar = false;
  List<SshProfile> _savedProfiles = const [];
  String? _selectedProfileId;
  Object? _profileLoadError;
  String? _lastTimelineWindowThreadId;
  int _timelineWindowGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.sessionController?.addListener(_handleSessionChanged);
    widget.threadDetailController?.addListener(_handleThreadDetailChanged);
    widget.turnController?.addListener(_handleTurnChanged);
    widget.appearanceController?.addListener(_handleAppearanceChanged);
    _lastSessionStatus = widget.sessionController?.status;
    unawaited(_loadSavedProfiles());
    _refreshThreadsIfConnected();
    _handleThreadDetailChanged();
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
    if (oldWidget.threadDetailController != widget.threadDetailController) {
      oldWidget.threadDetailController?.removeListener(
        _handleThreadDetailChanged,
      );
      widget.threadDetailController?.addListener(_handleThreadDetailChanged);
      _lastTimelineWindowThreadId = null;
      _handleThreadDetailChanged();
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
    widget.threadDetailController?.removeListener(_handleThreadDetailChanged);
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
              ChatActivityStrip(
                sidebarVisible: _showThreadSidebar,
                onToggleSidebar: _toggleThreadSidebar,
                sessionController: sessionController,
                turnController: turnController,
                timelineController: widget.timelineController,
                statusLineParts: _chatStatusLineParts(l10n),
                connectionControls: ChatConnectionControls(
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
                  final overlaySidebar =
                      bodyConstraints.maxWidth <
                      chatThreadSidebarOverlayBreakpoint;
                  final sidebarVisible = _showThreadSidebar && !compactHeight;
                  final sidebarWidth = chatThreadSidebarWidthFor(
                    bodyConstraints.maxWidth,
                  );
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 210),
                        curve: Curves.easeOutCubic,
                        top: 0,
                        bottom: 0,
                        left: sidebarVisible && !overlaySidebar
                            ? sidebarWidth
                            : 0,
                        right: 0,
                        child: ChatTimelineConversation(
                          compact: compactHeight,
                          timelineController: widget.timelineController,
                          onLoadOlderHistory: _requestOlderTimelineItems,
                          header: _sideConversation == null
                              ? null
                              : ChatSideConversationPanel(
                                  conversation: _sideConversation!,
                                  canReturn:
                                      widget.turnController?.canSubmit == true,
                                  onReturn: _returnToMainThread,
                                ),
                          timeline: ChatTimelinePanel(
                            controller: widget.timelineController,
                            showRaw: _showRawTranscript,
                            onRetryOlderHistory: _requestOlderTimelineItems,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        width: sidebarWidth,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 210),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInOutCubic,
                          transitionBuilder: (child, animation) {
                            final curved = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                              reverseCurve: Curves.easeInOutCubic,
                            );
                            return FadeTransition(
                              opacity: curved,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(-0.08, 0),
                                  end: Offset.zero,
                                ).animate(curved),
                                child: child,
                              ),
                            );
                          },
                          child: sidebarVisible
                              ? ChatThreadSidebar(
                                  key: const ValueKey('chat-sidebar-visible'),
                                  overlay: overlaySidebar,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ChatSidebarWorkspaceHeader(
                                        workspace: _workspaceSummary(l10n),
                                        onOpenAdvanced:
                                            widget.configOverrideController !=
                                                    null ||
                                                widget.sessionController != null
                                            ? _showAdvancedControlsSheet
                                            : null,
                                      ),
                                      const SizedBox(height: 10),
                                      ChatThreadListPanel(
                                        controller: threadListController,
                                        detailController:
                                            threadDetailController,
                                        archived: _showArchivedThreads,
                                        onArchivedChanged:
                                            _setThreadArchiveView,
                                        onUnarchiveThread: _unarchiveThread,
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('chat-sidebar-hidden'),
                                  width: 0,
                                  height: 0,
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
                        child: ChatSlashCommandPreview(
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
    final command = parseChatMcpCommand(arguments);
    if (command == null) {
      return null;
    }

    final l10n = context.l10n;
    switch (command) {
      case ChatMcpLoginCommand(:final serverName):
        final runner = widget.sessionController?.mcpServerOAuthRunner;
        if (runner == null) {
          return null;
        }
        final result = await runner.startOAuthLogin(serverName: serverName);
        return buildMcpServerOAuthLoginSummary(l10n: l10n, result: result);
      case ChatMcpReloadCommand(:final verbose):
        final runner = widget.sessionController?.mcpServerConfigRunner;
        if (runner == null) {
          return null;
        }
        await runner.reloadMcpServers();
        return _buildMcpStatusSummary(
          l10n: l10n,
          verbose: verbose,
          prefix: l10n.mcpServersReloaded,
        );
      case ChatMcpSummaryCommand(:final verbose):
        return _buildMcpStatusSummary(l10n: l10n, verbose: verbose);
    }
  }

  Future<String> _buildMcpStatusSummary({
    required AppLocalizations l10n,
    required bool verbose,
    String? prefix,
  }) async {
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
    if (prefix != null) {
      return [prefix, summary].join('\n');
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
    final command = parseChatPluginsCommand(arguments);
    if (command == null) {
      return null;
    }

    final l10n = context.l10n;
    final reader = widget.sessionController?.pluginListReader;
    final cwds = _currentWorkspaceCwds();
    if (command case ChatPluginsReadCommand(:final pluginId)) {
      final detailReader = widget.sessionController?.pluginDetailReader;
      if (detailReader == null) {
        return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
      }
      try {
        final detail = await detailReader.readPlugin(
          pluginId: pluginId,
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
    final mutationPluginId = switch (command) {
      ChatPluginsInstallCommand(:final pluginId) => pluginId,
      ChatPluginsUninstallCommand(:final pluginId) => pluginId,
      _ => null,
    };
    if (mutationPluginId != null) {
      final runner = widget.sessionController?.pluginMutationRunner;
      if (runner == null) {
        return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
      }
      try {
        final result = switch (command) {
          ChatPluginsInstallCommand() => await runner.installPlugin(
            pluginId: mutationPluginId,
            cwds: cwds,
          ),
          ChatPluginsUninstallCommand() => await runner.uninstallPlugin(
            pluginId: mutationPluginId,
            cwds: cwds,
          ),
          _ => throw StateError('Unexpected plugin mutation command.'),
        };
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

    final marketplaceKinds = switch (command) {
      ChatPluginsListCommand(:final marketplaceKinds) => marketplaceKinds,
      _ => const <PluginMarketplaceKind>[],
    };
    if (reader == null) {
      return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
    }

    try {
      final page = await reader.listPlugins(
        cwds: cwds,
        marketplaceKinds: marketplaceKinds,
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
    final rolloutPath = rolloutPathFromThreadRaw(
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
    removeChatComposerMentionsOverlappingRange(
      _composerMentions,
      start: safeStart,
      end: safeEnd,
    );
    _composerMentions.add(
      ChatComposerMention(
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
    pruneChatComposerMentions(_composerMentions, text);
  }

  List<TurnTextElement> _composerTextElements(String text) {
    return chatComposerTextElements(text: text, mentions: _composerMentions);
  }

  Future<String?> _handleGoalCommand(String arguments) async {
    final runner = widget.sessionController?.threadGoalRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return null;
    }

    final command = parseChatGoalCommand(arguments);
    if (command == null) {
      return null;
    }

    final l10n = context.l10n;
    return switch (command) {
      ChatGoalGetCommand() => buildThreadGoalSummary(
        l10n: l10n,
        goal: (await runner.getGoal(threadId: threadId)).goal,
      ),
      ChatGoalClearCommand() => buildThreadGoalClearedSummary(
        l10n: l10n,
        cleared: (await runner.clearGoal(threadId: threadId)).cleared,
      ),
      ChatGoalSetCommand(:final objective, :final status, :final tokenBudget) =>
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
    unawaited(
      widget.threadDetailController?.readThread(
        reviewThreadId,
        includeTurns: false,
      ),
    );
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
      builder: (context) => ChatAdvancedControlsSheet(
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
    final result = await showModalBottomSheet<ChatModelOverrideResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChatModelOverrideSheet(
        controller: controller,
        modelListController: widget.modelListController,
      ),
    );
    if (!mounted || result == null) {
      return SlashCommandCallbackResult.cancelled;
    }
    switch (result.scope) {
      case ChatOverrideScope.turn:
        controller.setTurnModelEffort(
          model: result.model,
          effort: result.effort,
        );
      case ChatOverrideScope.session:
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
    final result = await showModalBottomSheet<ChatPermissionsOverrideResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChatPermissionsOverrideSheet(
        controller: controller,
        permissionProfileListController: widget.permissionProfileListController,
      ),
    );
    if (!mounted || result == null) {
      return SlashCommandCallbackResult.cancelled;
    }
    if (result.isHighRisk) {
      final confirmed = await _confirmHighRiskPermissionsOverride();
      if (!mounted || !confirmed) {
        return SlashCommandCallbackResult.cancelled;
      }
    }
    switch (result.scope) {
      case ChatOverrideScope.turn:
        controller.setTurnPermissions(
          approvalPolicy: result.approvalPolicy,
          sandboxPolicy: result.sandboxPolicy,
          permissionProfile: result.permissionProfile,
        );
      case ChatOverrideScope.session:
        controller.setSessionPermissions(
          approvalPolicy: result.approvalPolicy,
          sandboxPolicy: result.sandboxPolicy,
          permissionProfile: result.permissionProfile,
        );
    }
    return SlashCommandCallbackResult.executed;
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
    final result = await showModalBottomSheet<ChatPersonalityOverrideResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          ChatPersonalityOverrideSheet(controller: controller),
    );
    if (!mounted || result == null) {
      return SlashCommandCallbackResult.cancelled;
    }
    switch (result.scope) {
      case ChatOverrideScope.turn:
        controller.setTurnPersonality(result.personality);
      case ChatOverrideScope.session:
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
      unawaited(
        widget.threadDetailController?.readThread(
          threadId,
          includeTurns: false,
        ),
      );
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
    unawaited(
      widget.threadDetailController?.readThread(
        activeThreadId,
        includeTurns: false,
      ),
    );
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
      unawaited(
        widget.threadDetailController?.readThread(
          threadId,
          includeTurns: false,
        ),
      );
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
    unawaited(
      widget.threadDetailController?.readThread(thread.id, includeTurns: false),
    );
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
      _sideConversation = ChatSideConversation(
        parentThreadId: parentThreadId,
        sideThreadId: sideThread.id,
        slash: btw ? '/btw' : '/side',
      );
    });
    widget.timelineController?.showThread(sideThread);
    unawaited(
      widget.threadDetailController?.readThread(
        sideThread.id,
        includeTurns: false,
      ),
    );
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
      builder: (context) => ChatAgentTopologySheet(
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
    unawaited(
      widget.threadDetailController?.readThread(
        selectedThread.id,
        includeTurns: false,
      ),
    );
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
        includeTurns: false,
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

    final selection = await showModalBottomSheet<ChatThemeSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ChatThemeSheet(
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

    final result = await showModalBottomSheet<ChatFeedbackFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ChatFeedbackSheet(),
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

  void _handleThreadDetailChanged() {
    final detailController = widget.threadDetailController;
    switch (detailController?.status) {
      case ThreadDetailStatus.loading:
        widget.timelineController?.selectThread(
          detailController?.selectedThreadId,
        );
      case ThreadDetailStatus.loaded:
        final detail = detailController?.detail;
        final thread = detail?.thread;
        final selectedThreadId = _nonEmptyText(
          detailController?.selectedThreadId,
        );
        if (thread != null && thread.id == selectedThreadId) {
          _loadInitialTimelineWindow(thread);
        }
      case ThreadDetailStatus.idle:
        _lastTimelineWindowThreadId = null;
      case ThreadDetailStatus.failed:
      case null:
        break;
    }
  }

  void _loadInitialTimelineWindow(ThreadSummary thread) {
    final threadId = _nonEmptyText(thread.id);
    final timelineController = widget.timelineController;
    if (threadId == null || timelineController == null) {
      return;
    }
    final reader = widget.sessionController?.threadItemListReader;
    if (reader == null) {
      _lastTimelineWindowThreadId = threadId;
      timelineController.showThread(thread);
      return;
    }
    if (_lastTimelineWindowThreadId == threadId &&
        timelineController.selectedThreadId == threadId &&
        timelineController.itemCount > 0) {
      return;
    }
    _lastTimelineWindowThreadId = threadId;
    final generation = ++_timelineWindowGeneration;
    unawaited(
      _readInitialTimelineWindow(
        generation: generation,
        reader: reader,
        thread: thread,
      ),
    );
  }

  Future<void> _readInitialTimelineWindow({
    required int generation,
    required ThreadItemListReader reader,
    required ThreadSummary thread,
  }) async {
    try {
      final page = await reader.listItems(
        threadId: thread.id,
        limit: chatTimelineInitialItemLimit,
        sortDirection: 'desc',
      );
      if (!mounted || generation != _timelineWindowGeneration) {
        return;
      }
      widget.timelineController?.showThreadItemWindow(
        thread: thread,
        items: page.items.reversed.toList(growable: false),
        olderItemsCursor: page.nextCursor,
      );
    } on Object {
      if (!mounted || generation != _timelineWindowGeneration) {
        return;
      }
      widget.timelineController?.showThread(thread);
    }
  }

  void _requestOlderTimelineItems() {
    final timelineController = widget.timelineController;
    final reader = widget.sessionController?.threadItemListReader;
    final threadId = _nonEmptyText(timelineController?.selectedThreadId);
    final cursor = _normalizedText(timelineController?.olderItemsCursor);
    if (timelineController == null ||
        reader == null ||
        threadId == null ||
        cursor == null ||
        timelineController.isLoadingOlderHistory) {
      return;
    }
    timelineController.beginOlderHistoryLoad();
    final generation = ++_timelineWindowGeneration;
    unawaited(
      _readOlderTimelineItems(
        generation: generation,
        reader: reader,
        threadId: threadId,
        cursor: cursor,
      ),
    );
  }

  Future<void> _readOlderTimelineItems({
    required int generation,
    required ThreadItemListReader reader,
    required String threadId,
    required String cursor,
  }) async {
    try {
      final page = await reader.listItems(
        threadId: threadId,
        cursor: cursor,
        limit: chatTimelineInitialItemLimit,
        sortDirection: 'desc',
      );
      if (!mounted || generation != _timelineWindowGeneration) {
        return;
      }
      final nextCursor = _normalizedText(page.nextCursor);
      widget.timelineController?.prependThreadItems(
        threadId: threadId,
        items: page.items.reversed.toList(growable: false),
        olderItemsCursor: nextCursor == cursor ? null : nextCursor,
      );
    } on Object catch (error) {
      if (!mounted || generation != _timelineWindowGeneration) {
        return;
      }
      widget.timelineController?.failOlderHistoryLoad(error);
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
