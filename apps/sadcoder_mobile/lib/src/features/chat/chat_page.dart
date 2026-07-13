import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../accounts/account_snapshot_controller.dart';
import '../../appearance/app_appearance_controller.dart';
import '../../commands/slash_command_action_dispatcher.dart';
import '../../commands/slash_command_registry.dart';
import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_snapshot_controller.dart';
import '../../files/file_search_reader.dart';
import '../../i18n/app_localizations.dart';
import '../../mcp/mcp_server_status_controller.dart';
import '../../models/model_list_controller.dart';
import '../../permissions/permission_profile_list_controller.dart';
import '../../session/codex_session_state_controller.dart';
import '../../session/host_session_summary.dart';
import '../../ssh/ssh_profile.dart';
import '../../ssh/ssh_profile_store.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_list_controller.dart';
import '../../turns/turn_controller.dart';
import '../../turns/turn_text_element.dart';
import '../../usage/account_usage_snapshot_controller.dart';
import '../../usage/thread_token_usage_controller.dart';
import 'chat_account_command_handler.dart';
import 'chat_advanced_controls_handler.dart';
import 'chat_activity_strip.dart';
import 'chat_appearance_command_handler.dart';
import 'chat_connection_controls.dart';
import 'chat_composer_mention.dart';
import 'chat_composer_submit_handler.dart';
import 'chat_conversation_command_handler.dart';
import 'chat_file_context_command_handler.dart';
import 'chat_layout_metrics.dart';
import 'chat_override_command_handler.dart';
import 'chat_profile_selection_handler.dart';
import 'chat_raw_transcript_command.dart';
import 'chat_status_summary.dart';
import 'chat_summary_command_handler.dart';
import 'chat_timeline_controller.dart';
import 'chat_side_conversation_panel.dart';
import 'chat_slash_command_preview.dart';
import 'chat_thread_command_handler.dart';
import 'chat_thread_sidebar.dart';
import 'chat_timeline_renderer.dart';
import 'chat_timeline_view.dart';
import 'chat_timeline_window_coordinator.dart';
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
  late final ChatTimelineWindowCoordinator _timelineWindowCoordinator;

  @override
  void initState() {
    super.initState();
    _timelineWindowCoordinator = ChatTimelineWindowCoordinator(
      mounted: () => mounted,
      timelineControllerProvider: () => widget.timelineController,
      threadItemListReaderProvider: () =>
          widget.sessionController?.threadItemListReader,
      turnControllerProvider: () => widget.turnController,
    );
    widget.sessionController?.addListener(_handleSessionChanged);
    widget.threadDetailController?.addListener(_handleThreadDetailChanged);
    widget.turnController?.addListener(_handleTurnChanged);
    widget.appearanceController?.addListener(_handleAppearanceChanged);
    _lastSessionStatus = widget.sessionController?.status;
    unawaited(_profileSelectionHandler().loadSavedProfiles());
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
      _timelineWindowCoordinator.reset();
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
      unawaited(_profileSelectionHandler().loadSavedProfiles());
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
    final canSend = _composerSubmitHandler().canSubmit(
      _composerController.text,
    );
    final composerSendShortcut =
        widget.appearanceController?.composerSendShortcut ??
        AppComposerSendShortcut.enter;
    final sendSlashAsText = isSlashTextPrompt(
      _composerController.text,
      _slashCommand,
      _slashTextPrompt,
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
                      : _profileSelectionHandler().selectProfile,
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
                          onLoadOlderHistory:
                              _timelineWindowCoordinator.requestOlderItems,
                          header: _sideConversation == null
                              ? null
                              : ChatSideConversationPanel(
                                  conversation: _sideConversation!,
                                  canReturn:
                                      widget.turnController?.canSubmit == true,
                                  onReturn: () => unawaited(
                                    _conversationCommandHandler()
                                        .returnToMainThread(),
                                  ),
                                ),
                          timeline: ChatTimelinePanel(
                            controller: widget.timelineController,
                            showRaw: _showRawTranscript,
                            onRetryOlderHistory:
                                _timelineWindowCoordinator.requestOlderItems,
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
                                            ? _advancedControlsHandler()
                                                  .showSheet
                                            : null,
                                      ),
                                      if (widget.hostSessions.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        ChatHostSessionsPanel(
                                          hostSessions: widget.hostSessions,
                                          selectedProfile:
                                              sessionController?.profile,
                                          onProfileSelected:
                                              sessionController == null &&
                                                  widget.profileConnector ==
                                                      null
                                              ? null
                                              : _profileSelectionHandler()
                                                    .selectProfile,
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      ChatThreadListPanel(
                                        controller: threadListController,
                                        detailController:
                                            threadDetailController,
                                        archived: _showArchivedThreads,
                                        onArchivedChanged:
                                            _setThreadArchiveView,
                                        onUnarchiveThread: (thread) =>
                                            _threadCommandHandler()
                                                .unarchiveThread(thread),
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
    await _composerSubmitHandler().submit(_composerController.text);
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

  List<SshProfile> _headerProfiles() {
    return chatHeaderProfiles(
      savedProfiles: _savedProfiles,
      hostSessions: widget.hostSessions,
      connectedProfile: widget.sessionController?.profile,
    );
  }

  SshProfile? _selectedHeaderProfile() {
    return selectedChatHeaderProfile(
      profiles: _headerProfiles(),
      connectedProfile: widget.sessionController?.profile,
      selectedProfileId: _selectedProfileId,
    );
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
      _clearComposerInput();
    }
    if (result.outcome == SlashCommandActionOutcome.executed &&
        result.effect == SlashCommandActionEffect.mention) {
      return;
    }
    _showChatSnackBar(_slashCommandResultMessage(context.l10n, result));
  }

  SlashCommandActionDispatcher _slashCommandDispatcher() {
    final injected = widget.slashCommandDispatcher;
    if (injected != null) {
      return injected;
    }
    final summaryHandler = _summaryCommandHandler();
    return SlashCommandActionDispatcher(
      disconnect: widget.sessionController?.disconnect,
      clearTranscript: _clearLocalTranscript,
      copyLastResponse: summaryHandler.copyLastResponse,
      showStatus: summaryHandler.buildStatusSummary,
      showUsage: summaryHandler.buildUsageSummary,
      showMcp: summaryHandler.buildMcpSummary,
      showSkills: summaryHandler.buildSkillsSummary,
      showPlugins: summaryHandler.buildPluginsSummary,
      showHooks: summaryHandler.buildHooksSummary,
      showApps: summaryHandler.buildAppsSummary,
      showDebugConfig: summaryHandler.buildDebugConfigSummary,
      showExperimental: summaryHandler.buildExperimentalSummary,
      showMemories: summaryHandler.buildMemoriesSummary,
      showRollout: summaryHandler.buildRolloutSummary,
      testApproval: summaryHandler.testApprovalRequest,
      showDiff: summaryHandler.buildDiffSummary,
      handleGoal: summaryHandler.handleGoalCommand,
      handleReview: summaryHandler.handleReviewCommand,
      approveRecentAutoReviewDenial:
          summaryHandler.approveRecentAutoReviewDenial,
      showBackgroundTerminals: summaryHandler.buildBackgroundTerminalsSummary,
      cleanBackgroundTerminals: summaryHandler.cleanBackgroundTerminals,
      toggleRawTranscript: _toggleRawTranscript,
      startNewThread: () => _threadCommandHandler().startNewThread(),
      resumeThread: (threadId) =>
          _threadCommandHandler().resumeThread(threadId),
      renameThread: (name) => _threadCommandHandler().renameThread(name),
      logout: () => _accountCommandHandler().logoutAccount(),
      submitFeedback: () => _accountCommandHandler().submitFeedback(),
      configureTheme: () => _appearanceCommandHandler().configureTheme(),
      configureTitleDisplay: () =>
          _appearanceCommandHandler().configureTitleDisplay(),
      configureStatusLineDisplay: () =>
          _appearanceCommandHandler().configureStatusLineDisplay(),
      configureKeymap: (arguments) =>
          _appearanceCommandHandler().configureKeymap(arguments),
      toggleComposerVimMode: () =>
          _appearanceCommandHandler().toggleComposerVimMode(),
      configureTerminalPets: (arguments) =>
          _appearanceCommandHandler().configureTerminalPets(arguments),
      attachIdeContext: (arguments) =>
          _fileContextCommandHandler().attachIdeContext(arguments),
      configurePlanMode: (arguments) =>
          _overrideCommandHandler().configurePlanMode(arguments),
      mentionFile: () => _fileContextCommandHandler().mentionFile(),
      startSideConversation: (arguments, {required btw}) =>
          _conversationCommandHandler().startSideConversation(
            arguments,
            btw: btw,
          ),
      showAgentTopology: ({required subagentsOnly}) =>
          _conversationCommandHandler().showAgentTopology(
            subagentsOnly: subagentsOnly,
          ),
      forkThread: () => _threadCommandHandler().forkCurrentThread(),
      duplicateThread: () => _threadCommandHandler().duplicateCurrentThread(),
      rewindThread: (lastTurnId) =>
          _threadCommandHandler().rewindCurrentThread(lastTurnId),
      compactThread: () => _threadCommandHandler().compactCurrentThread(),
      archiveThread: () => _threadCommandHandler().archiveCurrentThread(),
      deleteThread: () => _threadCommandHandler().deleteCurrentThread(),
      configureModel: () => _overrideCommandHandler().configureModel(),
      configurePersonality: () =>
          _overrideCommandHandler().configurePersonality(),
      configurePermissions: () =>
          _overrideCommandHandler().configurePermissions(),
      confirmHighRisk: _confirmHighRiskSlashCommand,
    );
  }

  ChatSummaryCommandHandler _summaryCommandHandler() {
    return ChatSummaryCommandHandler(
      context: context,
      sessionController: widget.sessionController,
      threadListController: widget.threadListController,
      threadDetailController: widget.threadDetailController,
      turnController: widget.turnController,
      timelineController: widget.timelineController,
      configOverrideController: widget.configOverrideController,
      configSnapshotController: widget.configSnapshotController,
      accountSnapshotController: widget.accountSnapshotController,
      accountUsageSnapshotController: widget.accountUsageSnapshotController,
      mcpServerStatusController: widget.mcpServerStatusController,
      threadTokenUsageController: widget.threadTokenUsageController,
      currentThreadIdProvider: _currentThreadId,
      currentWorkspaceCwdsProvider: _currentWorkspaceCwds,
      currentThreadUsageProvider: _currentThreadTokenUsage,
      refreshVisibleThreads: _refreshVisibleThreads,
    );
  }

  ChatThreadCommandHandler _threadCommandHandler() {
    return ChatThreadCommandHandler(
      context: context,
      mounted: () => mounted,
      sessionController: widget.sessionController,
      threadDetailController: widget.threadDetailController,
      turnController: widget.turnController,
      timelineController: widget.timelineController,
      clearSideConversation: _clearSideConversation,
      clearLocalTranscript: _clearLocalTranscript,
      refreshVisibleThreads: _refreshVisibleThreads,
      showSnackBar: _showChatSnackBar,
    );
  }

  ChatAppearanceCommandHandler _appearanceCommandHandler() {
    return ChatAppearanceCommandHandler(
      context: context,
      mounted: () => mounted,
      controller: widget.appearanceController,
    );
  }

  ChatOverrideCommandHandler _overrideCommandHandler() {
    return ChatOverrideCommandHandler(
      context: context,
      mounted: () => mounted,
      configOverrideController: widget.configOverrideController,
      modelListController: widget.modelListController,
      permissionProfileListController: widget.permissionProfileListController,
      turnController: widget.turnController,
      resolvePlanModeModel: _resolvePlanModeModel,
      syncActiveTurnToTimeline: _timelineWindowCoordinator.syncActiveTurn,
    );
  }

  ChatAccountCommandHandler _accountCommandHandler() {
    return ChatAccountCommandHandler(
      context: context,
      mounted: () => mounted,
      sessionController: widget.sessionController,
      accountSnapshotController: widget.accountSnapshotController,
      accountUsageSnapshotController: widget.accountUsageSnapshotController,
      currentThreadIdProvider: _currentThreadId,
      activeTurnIdProvider: () => widget.turnController?.activeTurnId,
    );
  }

  ChatFileContextCommandHandler _fileContextCommandHandler() {
    return ChatFileContextCommandHandler(
      context: context,
      mounted: () => mounted,
      fileSearchReader: widget.sessionController?.fileSearchReader,
      currentWorkspaceCwdsProvider: _currentWorkspaceCwds,
      insertMention: _insertMention,
    );
  }

  ChatConversationCommandHandler _conversationCommandHandler() {
    return ChatConversationCommandHandler(
      context: context,
      mounted: () => mounted,
      sessionController: widget.sessionController,
      threadListController: widget.threadListController,
      threadDetailController: widget.threadDetailController,
      turnController: widget.turnController,
      timelineController: widget.timelineController,
      currentThreadIdProvider: _currentThreadId,
      sideConversationProvider: () => _sideConversation,
      setSideConversation: (conversation) {
        setState(() => _sideConversation = conversation);
      },
      clearSideConversation: _clearSideConversation,
      refreshVisibleThreads: _refreshVisibleThreads,
      syncActiveTurnToTimeline: _timelineWindowCoordinator.syncActiveTurn,
      showSnackBar: _showChatSnackBar,
    );
  }

  ChatProfileSelectionHandler _profileSelectionHandler() {
    return ChatProfileSelectionHandler(
      context: context,
      mounted: () => mounted,
      profileStoreProvider: () => widget.profileStore,
      sessionController: widget.sessionController,
      profileConnector: widget.profileConnector,
      currentSelectedProfileId: () => _selectedProfileId,
      applyProfileState:
          ({
            required savedProfiles,
            required selectedProfileId,
            required profileLoadError,
          }) {
            setState(() {
              _savedProfiles = savedProfiles;
              _selectedProfileId = selectedProfileId;
              _profileLoadError = profileLoadError;
            });
          },
      selectProfileLocally: (profileId) {
        setState(() {
          _selectedProfileId = profileId;
          _profileLoadError = null;
        });
      },
      showSnackBar: _showChatSnackBar,
    );
  }

  ChatComposerSubmitHandler _composerSubmitHandler() {
    return ChatComposerSubmitHandler(
      context: context,
      mounted: () => mounted,
      registry: widget.registry,
      sessionController: widget.sessionController,
      turnController: widget.turnController,
      configOverrideController: widget.configOverrideController,
      slashTextPromptProvider: () => _slashTextPrompt,
      textElementsProvider: _composerTextElements,
      dispatchSlashCommand: _dispatchSlashCommand,
      syncActiveTurn: _timelineWindowCoordinator.syncActiveTurn,
      clearComposer: _clearComposerInput,
      showSnackBar: _showChatSnackBar,
    );
  }

  ChatAdvancedControlsHandler _advancedControlsHandler() {
    return ChatAdvancedControlsHandler(
      context: context,
      sessionController: widget.sessionController,
      configOverrideController: widget.configOverrideController,
      threadDetailController: widget.threadDetailController,
      currentThreadIdProvider: _currentThreadId,
      refreshVisibleThreads: _refreshVisibleThreads,
    );
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

  void _clearComposerInput() {
    _composerMentions.clear();
    _slashTextPrompt = null;
    _composerController.clear();
    _handleComposerChanged('');
  }

  bool? _toggleRawTranscript(String arguments) {
    final next = rawTranscriptVisibilityForCommand(
      current: _showRawTranscript,
      arguments: arguments,
    );
    if (next == null) {
      return null;
    }
    setState(() => _showRawTranscript = next);
    return next;
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
          _timelineWindowCoordinator.loadInitialWindow(thread);
        }
      case ThreadDetailStatus.idle:
        _timelineWindowCoordinator.reset();
      case ThreadDetailStatus.failed:
      case null:
        break;
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
    _timelineWindowCoordinator.syncActiveTurn();
    if (mounted) {
      setState(() {});
    }
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
