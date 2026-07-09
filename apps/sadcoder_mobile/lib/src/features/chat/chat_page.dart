import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../accounts/account_snapshot_controller.dart';
import '../../appearance/app_appearance_controller.dart';
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
import '../../permissions/permission_profile_list_reader.dart';
import '../../reviews/thread_review_command.dart';
import '../../security/permission_risk.dart';
import '../../session/codex_session_state_controller.dart';
import '../../theme/sadcoder_theme.dart';
import '../../threads/agent_thread_topology.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_list_controller.dart';
import '../../threads/thread_mutation_runner.dart';
import '../../threads/thread_summary.dart';
import '../../turns/turn_controller.dart';
import '../../turns/turn_text_element.dart';
import '../../usage/account_usage_snapshot_controller.dart';
import 'chat_apps_summary.dart';
import 'chat_background_terminal_summary.dart';
import 'chat_debug_config_summary.dart';
import 'chat_display_settings_sheets.dart';
import 'chat_diff_summary.dart';
import 'chat_hooks_summary.dart';
import 'chat_plugins_summary.dart';
import 'chat_skills_summary.dart';
import 'chat_status_summary.dart';
import 'chat_timeline_controller.dart';
import 'chat_goal_summary.dart';
import 'chat_mcp_summary.dart';
import 'chat_review_summary.dart';
import 'chat_usage_summary.dart';
import 'config_override_controls.dart';
import 'config_override_labels.dart';
import 'session_override_controls.dart';
import 'slash_command_palette.dart';
import 'turn_override_controls.dart';

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
    this.modelListController,
    this.permissionProfileListController,
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
  final ModelListController? modelListController;
  final PermissionProfileListController? permissionProfileListController;
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
  bool _slashPaletteOpen = false;
  bool _showRawTranscript = false;

  @override
  void initState() {
    super.initState();
    widget.sessionController?.addListener(_handleSessionChanged);
    widget.turnController?.addListener(_handleTurnChanged);
    widget.appearanceController?.addListener(_handleAppearanceChanged);
    _lastSessionStatus = widget.sessionController?.status;
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
    final composerInputMode =
        widget.appearanceController?.composerInputMode ??
        AppComposerInputMode.standard;
    final composerSendShortcut =
        widget.appearanceController?.composerSendShortcut ??
        AppComposerSendShortcut.enter;
    final terminalPetPreference =
        widget.appearanceController?.terminalPetPreference ??
        AppTerminalPetPreference.tuiOnly;
    return Column(
      children: [
        _ChatHeader(
          title: _chatHeaderTitle(l10n),
          connectionLabel: _connectionLabel(l10n, sessionController?.status),
          connected: sessionController?.status == CodexSessionStatus.connected,
          statusLineParts: _chatStatusLineParts(l10n),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MessageBlock(
                title: l10n.m0ProtocolClient,
                body: l10n.m0ProtocolClientBody,
              ),
              _MessageBlock(
                title: l10n.slashCommandSurface,
                body: l10n.slashCommandSurfaceBody,
              ),
              _ThreadListPanel(
                controller: threadListController,
                detailController: threadDetailController,
              ),
              _ThreadDetailPanel(controller: threadDetailController),
              if (_sideConversation != null)
                _SideConversationPanel(
                  conversation: _sideConversation!,
                  canReturn: turnController?.canSubmit == true,
                  onReturn: _returnToMainThread,
                ),
              _ChatTimelinePanel(
                controller: widget.timelineController,
                showRaw: _showRawTranscript,
              ),
              _TurnStatusPanel(controller: turnController),
              _SlashCommandPreview(result: _slashCommand),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.configOverrideController != null) ...[
                  SessionOverrideControls(
                    controller: widget.configOverrideController!,
                  ),
                  const SizedBox(height: 8),
                  TurnOverrideControls(
                    controller: widget.configOverrideController!,
                  ),
                  const SizedBox(height: 8),
                ],
                CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    if (composerSendShortcut ==
                        AppComposerSendShortcut.ctrlEnter)
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        control: true,
                      ): () {
                        if (canSend) {
                          unawaited(_sendComposerText());
                        }
                      },
                  },
                  child: TextField(
                    key: const ValueKey('chat-composer-field'),
                    controller: _composerController,
                    onChanged: _handleComposerChanged,
                    keyboardType:
                        composerSendShortcut ==
                            AppComposerSendShortcut.ctrlEnter
                        ? TextInputType.multiline
                        : TextInputType.text,
                    minLines: 1,
                    maxLines:
                        composerSendShortcut ==
                            AppComposerSendShortcut.ctrlEnter
                        ? 4
                        : 1,
                    textInputAction:
                        composerSendShortcut == AppComposerSendShortcut.enter
                        ? TextInputAction.send
                        : TextInputAction.newline,
                    onSubmitted:
                        composerSendShortcut == AppComposerSendShortcut.enter &&
                            canSend
                        ? (_) => unawaited(_sendComposerText())
                        : null,
                    decoration: InputDecoration(
                      hintText: l10n.connectBeforeTurn,
                      helperText: _composerHelperText(
                        l10n,
                        composerInputMode,
                        composerSendShortcut,
                        terminalPetPreference,
                      ),
                      helperMaxLines: 2,
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
                            onPressed: turnController?.canInterrupt == true
                                ? _interruptActiveTurn
                                : null,
                            icon: const Icon(Icons.stop_circle_outlined),
                            tooltip: l10n.interruptTurn,
                          ),
                          IconButton(
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleComposerChanged(String value) {
    _pruneComposerMentions(value);
    final result = widget.registry.parseComposerText(value);
    setState(() => _slashCommand = result);
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
    _composerController.text = text;
    _composerController.selection = TextSelection.collapsed(
      offset: text.length,
    );
    _handleComposerChanged(text);
  }

  Future<void> _sendComposerText() async {
    final text = _composerController.text;
    final parsed = widget.registry.parseComposerText(text);
    if (!_canSubmitComposerText(
      text,
      isConnected: widget.sessionController?.isConnected == true,
      turnController: widget.turnController,
    )) {
      return;
    }
    if (parsed.kind != SlashCommandParseKind.notSlash) {
      await _dispatchSlashCommand(parsed);
      return;
    }

    final turnController = widget.turnController;
    if (turnController == null) {
      return;
    }
    final textElements = _composerTextElements(text);
    await turnController.submitText(text, textElements: textElements);
    if (turnController.status != TurnControllerStatus.failed) {
      widget.configOverrideController?.clearTurn();
      _composerMentions.clear();
      _composerController.clear();
      _handleComposerChanged('');
    }
  }

  Future<void> _interruptActiveTurn() async {
    await widget.turnController?.interruptActiveTurn();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_slashCommandResultMessage(context.l10n, result))),
    );
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
          showDiff: _buildDiffSummary,
          handleGoal: _handleGoalCommand,
          handleReview: _handleReviewCommand,
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
          compactThread: _compactCurrentThread,
          archiveThread: _archiveCurrentThread,
          deleteThread: _deleteCurrentThread,
          configureModel: _configureModelOverride,
          configurePersonality: _configurePersonalityOverride,
          configurePermissions: _configurePermissionsOverride,
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
    );
  }

  Future<String> _buildUsageSummary() async {
    final l10n = context.l10n;
    final controller = widget.accountUsageSnapshotController;
    if (controller != null) {
      await controller.refresh();
    }
    return buildAccountUsageSummary(l10n: l10n, controller: controller);
  }

  Future<String?> _buildMcpSummary(String arguments) async {
    final normalized = arguments.trim().toLowerCase();
    final verbose = normalized == 'verbose';
    if (normalized.isNotEmpty && !verbose) {
      return null;
    }

    final l10n = context.l10n;
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
    return buildMcpServerStatusSummary(
      l10n: l10n,
      controller: controller,
      verbose: verbose,
    );
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
      return '${l10n.skillsTitle}\n${l10n.skillsLoadFailed}: $error';
    }
  }

  Future<String?> _buildPluginsSummary(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }

    final l10n = context.l10n;
    final reader = widget.sessionController?.pluginListReader;
    if (reader == null) {
      return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
    }

    try {
      final page = await reader.listPlugins(cwds: _currentWorkspaceCwds());
      return buildPluginsSummary(l10n: l10n, page: page);
    } on Object catch (error) {
      return '${l10n.pluginsTitle}\n${l10n.pluginsLoadFailed}: $error';
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
      return '${l10n.hooksTitle}\n${l10n.hooksLoadFailed}: $error';
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
      return '${l10n.appsTitle}\n${l10n.appsLoadFailed}: $error';
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
      return '${l10n.diffTitle}\n${l10n.diffLoadFailed}: $error';
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
      builder: (context) => _MentionFileSheet(
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
      builder: (context) => _MentionFileSheet(
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
    unawaited(widget.threadListController?.refresh());
    unawaited(widget.threadDetailController?.readThread(reviewThreadId));
    return buildThreadReviewStartedSummary(
      l10n: l10n,
      result: result,
      target: command.target,
      delivery: command.delivery,
    );
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
    controller.clearTurn();
    return SlashCommandCallbackResult.executed;
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
    unawaited(widget.threadListController?.refresh());
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
    unawaited(widget.threadListController?.refresh());
    return true;
  }

  Future<bool> _renameThread(String name) async {
    final runner = widget.sessionController?.threadMutationRunner;
    final threadId = _currentThreadId();
    if (runner == null || threadId == null) {
      return false;
    }
    await runner.setThreadName(threadId: threadId, name: name);
    unawaited(widget.threadListController?.refresh());
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
    if (forked.id.trim().isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }
    final activated = turnController?.activateThread(forked.id) ?? true;
    if (!activated) {
      return SlashCommandCallbackResult.unavailable;
    }
    _clearSideConversation();
    widget.timelineController?.showThread(forked);
    unawaited(widget.threadDetailController?.readThread(forked.id));
    unawaited(widget.threadListController?.refresh());
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
    unawaited(widget.threadListController?.refresh());

    final initialPrompt = arguments.trim();
    if (initialPrompt.isNotEmpty) {
      await turnController.submitText(initialPrompt);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.slashCommandReturnedToMainThread)),
    );
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

    final theme = await showModalBottomSheet<AppThemePreference>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ThemeSheet(initialTheme: controller.theme),
    );
    if (!mounted || theme == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    controller.setTheme(theme);
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
    unawaited(widget.threadListController?.refresh());
    return SlashCommandCallbackResult.executed;
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
        SlashCommandActionEffect.compactThread =>
          l10n.slashCommandCompactionStarted,
        SlashCommandActionEffect.archiveThread =>
          l10n.slashCommandArchivedThread,
        SlashCommandActionEffect.deleteThread => l10n.slashCommandDeletedThread,
        SlashCommandActionEffect.logout => l10n.slashCommandLoggedOut,
        SlashCommandActionEffect.feedback => l10n.slashCommandFeedbackSubmitted,
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
    final parsed = widget.registry.parseComposerText(text);
    return switch (parsed.kind) {
      SlashCommandParseKind.notSlash =>
        isConnected && turnController != null && turnController.canSubmit,
      SlashCommandParseKind.empty || SlashCommandParseKind.unknown => false,
      SlashCommandParseKind.known => true,
    };
  }

  void _handleSessionChanged() {
    final status = widget.sessionController?.status;
    if (_lastSessionStatus != CodexSessionStatus.connected &&
        status == CodexSessionStatus.connected) {
      unawaited(widget.threadListController?.refresh());
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
    if (mounted) {
      setState(() {});
    }
  }

  void _refreshThreadsIfConnected() {
    if (widget.sessionController?.status == CodexSessionStatus.connected) {
      unawaited(widget.threadListController?.refresh());
    }
  }

  String _chatHeaderTitle(AppLocalizations l10n) {
    final settings =
        widget.appearanceController?.titleDisplay ??
        AppTitleDisplaySettings.defaults;
    final parts = <String>[l10n.chat];
    final threadTitle = widget.threadDetailController?.detail?.thread.title
        .trim();
    if (settings.showThreadTitle &&
        threadTitle != null &&
        threadTitle.isNotEmpty) {
      parts.add(threadTitle);
    }
    final cwd = _currentWorkspaceCwd();
    if (settings.showWorkingDirectory && cwd != null) {
      parts.add(cwd);
    }
    return parts.join(' / ');
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

  String? _nonEmptyText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _composerHelperText(
    AppLocalizations l10n,
    AppComposerInputMode inputMode,
    AppComposerSendShortcut sendShortcut,
    AppTerminalPetPreference terminalPetPreference,
  ) {
    return [
      _composerInputModeLabel(l10n, inputMode),
      _composerSendShortcutLabel(l10n, sendShortcut),
      _terminalPetPreferenceLabel(l10n, terminalPetPreference),
    ].join(' | ');
  }

  String _composerInputModeLabel(
    AppLocalizations l10n,
    AppComposerInputMode mode,
  ) {
    return switch (mode) {
      AppComposerInputMode.standard => l10n.composerInputModeStandard,
      AppComposerInputMode.vim => l10n.composerInputModeVim,
    };
  }

  String _composerSendShortcutLabel(
    AppLocalizations l10n,
    AppComposerSendShortcut shortcut,
  ) {
    return switch (shortcut) {
      AppComposerSendShortcut.enter => l10n.composerSendShortcutEnter,
      AppComposerSendShortcut.ctrlEnter => l10n.composerSendShortcutCtrlEnter,
    };
  }

  String _terminalPetPreferenceLabel(
    AppLocalizations l10n,
    AppTerminalPetPreference preference,
  ) {
    return switch (preference) {
      AppTerminalPetPreference.tuiOnly => l10n.composerTerminalPetTuiOnly,
      AppTerminalPetPreference.hidden => l10n.composerTerminalPetHidden,
    };
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.sideConversationDropped)),
    );
  }
}

String? _normalizedText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
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
    return Card(
      key: const ValueKey('chat-side-conversation-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.call_split_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.sideConversationTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      '${l10n.sideConversationCommand}: ${conversation.slash}',
                      '${l10n.sideConversationThread}: ${conversation.sideThreadId}',
                      '${l10n.sideConversationParent}: ${conversation.parentThreadId}',
                    ].join('\n'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const ValueKey('chat-side-return-main'),
              onPressed: canReturn ? onReturn : null,
              icon: const Icon(Icons.keyboard_return),
              label: Text(l10n.returnToMainThread),
            ),
          ],
        ),
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

class _MentionFileSheet extends StatefulWidget {
  const _MentionFileSheet({
    required this.reader,
    required this.roots,
    required this.title,
    required this.searchHint,
    this.initialQuery = '',
  });

  final FileSearchReader reader;
  final List<String> roots;
  final String title;
  final String searchHint;
  final String initialQuery;

  @override
  State<_MentionFileSheet> createState() => _MentionFileSheetState();
}

class _MentionFileSheetState extends State<_MentionFileSheet> {
  final TextEditingController _queryController = TextEditingController();
  FileSearchResultPage? _page;
  Object? _error;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.initialQuery.trim();
    unawaited(_load());
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.attach_file),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: l10n.approvalCancel,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('chat-mention-search-field'),
                controller: _queryController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _load(),
              ),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              Flexible(child: _buildResults(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final l10n = context.l10n;
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          '${l10n.mentionLoadFailed}: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    final files = _page?.files ?? const <FileSearchMatch>[];
    if (files.isEmpty && _loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(l10n.mentionNoResults),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return ListTile(
          key: ValueKey('chat-mention-file-${file.path}'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(file.path, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: file.root.isEmpty
              ? null
              : Text(file.root, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.of(context).pop(file),
        );
      },
    );
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.reader.searchFiles(
        query: _queryController.text.trim(),
        roots: widget.roots,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _page = page;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
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
  const _ThemeSheet({required this.initialTheme});

  final AppThemePreference initialTheme;

  @override
  State<_ThemeSheet> createState() => _ThemeSheetState();
}

class _ThemeSheetState extends State<_ThemeSheet> {
  late AppThemePreference _theme;

  @override
  void initState() {
    super.initState();
    _theme = widget.initialTheme;
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
                  onPressed: () => Navigator.of(context).pop(_theme),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyTheme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
            '${l10n.permissionProfileLoadFailed}: ${controller.error}',
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
              items: [
                for (final model in controller.models)
                  DropdownMenuItem(value: model.id, child: Text(model.label)),
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

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.connected});

  final String label;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(connected ? Icons.link : Icons.link_off, size: 18),
      label: Text(label),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.connectionLabel,
    required this.connected,
    required this.statusLineParts,
  });

  final String title;
  final String connectionLabel;
  final bool connected;
  final List<String> statusLineParts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  key: const ValueKey('chat-display-title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              _StateChip(label: connectionLabel, connected: connected),
            ],
          ),
          if (statusLineParts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              key: const ValueKey('chat-status-line'),
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final part in statusLineParts)
                  Text(part, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ThreadListPanel extends StatelessWidget {
  const _ThreadListPanel({
    required this.controller,
    required this.detailController,
  });

  final ThreadListController? controller;
  final ThreadDetailController? detailController;

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
      ),
    );
  }
}

class _ThreadListContent extends StatelessWidget {
  const _ThreadListContent({
    required this.controller,
    required this.detailController,
  });

  final ThreadListController controller;
  final ThreadDetailController? detailController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = l10n.sessions;
    return switch (controller.status) {
      ThreadListStatus.idle => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(controller: controller),
        child: Text(l10n.connectBeforeLoadingThreads),
      ),
      ThreadListStatus.loading => _ThreadListCard(
        title: title,
        child: const LinearProgressIndicator(),
      ),
      ThreadListStatus.failed => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(controller: controller),
        child: Text(
          controller.error?.toString() ?? l10n.threadListFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      ThreadListStatus.loaded when controller.threads.isEmpty =>
        _ThreadListCard(
          title: title,
          action: _RefreshThreadsButton(controller: controller),
          child: Text(l10n.noThreads),
        ),
      ThreadListStatus.loaded => _ThreadListCard(
        title: title,
        action: _RefreshThreadsButton(controller: controller),
        child: Column(
          children: [
            for (final thread in controller.threads)
              _ThreadListTile(
                thread: thread,
                detailController: detailController,
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
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _RefreshThreadsButton extends StatelessWidget {
  const _RefreshThreadsButton({required this.controller});

  final ThreadListController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.refreshThreads,
      onPressed: () => controller.refresh(),
      icon: const Icon(Icons.refresh),
    );
  }
}

class _ThreadListTile extends StatelessWidget {
  const _ThreadListTile({required this.thread, required this.detailController});

  final ThreadSummary thread;
  final ThreadDetailController? detailController;

  @override
  Widget build(BuildContext context) {
    final badges = <String>[
      thread.status,
      if (thread.isFork) context.l10n.forkedThread,
      if (thread.isSubagent) context.l10n.subagentThread,
    ];
    return ListTile(
      key: ValueKey('thread-summary-${thread.id}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.forum_outlined),
      title: Text(thread.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          thread.cwd,
          badges.join(' / '),
        ].where((value) => value.isNotEmpty).join('\n'),
      ),
      isThreeLine: thread.cwd.isNotEmpty && badges.isNotEmpty,
      onTap: detailController == null
          ? null
          : () => detailController!.readThread(thread.id),
    );
  }
}

class _ThreadDetailPanel extends StatelessWidget {
  const _ThreadDetailPanel({required this.controller});

  final ThreadDetailController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _ThreadDetailContent(controller: controller),
    );
  }
}

class _ThreadDetailContent extends StatelessWidget {
  const _ThreadDetailContent({required this.controller});

  final ThreadDetailController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (controller.status) {
      ThreadDetailStatus.idle => const SizedBox.shrink(),
      ThreadDetailStatus.loading => _ThreadDetailCard(
        title: l10n.threadDetail,
        child: const LinearProgressIndicator(),
      ),
      ThreadDetailStatus.failed => _ThreadDetailCard(
        title: l10n.threadDetail,
        child: Text(
          controller.error?.toString() ?? l10n.threadDetailFailed,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      ThreadDetailStatus.loaded => _LoadedThreadDetail(
        detail: controller.detail!,
      ),
    };
  }
}

class _LoadedThreadDetail extends StatelessWidget {
  const _LoadedThreadDetail({required this.detail});

  final ThreadDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thread = detail.thread;
    return _ThreadDetailCard(
      title: l10n.threadDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(thread.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('${l10n.approvalThread}: ${thread.id}'),
          if (thread.cwd.isNotEmpty)
            Text('${l10n.approvalWorkingDirectory}: ${thread.cwd}'),
          Text(l10n.turnCount(thread.turns.length)),
          const SizedBox(height: 8),
          if (thread.turns.isEmpty)
            Text(l10n.noTurns)
          else
            for (final turn in thread.turns) _TurnSummaryTile(turn: turn),
        ],
      ),
    );
  }
}

class _TurnStatusPanel extends StatelessWidget {
  const _TurnStatusPanel({required this.controller});

  final TurnController? controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _TurnStatusCard(controller: controller),
    );
  }
}

class _TurnStatusCard extends StatelessWidget {
  const _TurnStatusCard({required this.controller});

  final TurnController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final content = switch (controller.status) {
      TurnControllerStatus.idle => null,
      TurnControllerStatus.startingThread => l10n.startingThread,
      TurnControllerStatus.resumingThread => l10n.resumingThread,
      TurnControllerStatus.sendingTurn => l10n.sendingTurn,
      TurnControllerStatus.submitted => l10n.turnSubmitted(
        controller.activeTurnId ?? '',
      ),
      TurnControllerStatus.completed => l10n.turnCompleted,
      TurnControllerStatus.interrupting => l10n.interruptingTurn,
      TurnControllerStatus.interrupted => l10n.turnInterrupted,
      TurnControllerStatus.failed =>
        controller.error?.toString() ?? l10n.turnFailed,
    };
    if (content == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (controller.isBusy) ...[
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
            ] else ...[
              Icon(
                controller.status == TurnControllerStatus.failed
                    ? Icons.error_outline
                    : Icons.task_alt,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(content)),
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
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.timeline,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final turn in turns)
              _TimelineTurnView(turn: turn, showRaw: showRaw),
          ],
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${context.l10n.approvalTurn}: ${turn.turnId} / ${turn.status}'),
        if (turn.items.isEmpty)
          Text(context.l10n.noTimelineEvents)
        else
          for (final item in turn.items)
            _TimelineItemView(item: item, showRaw: showRaw),
      ],
    );
  }
}

class _TimelineItemView extends StatelessWidget {
  const _TimelineItemView({required this.item, required this.showRaw});

  final ChatTimelineItem item;
  final bool showRaw;

  @override
  Widget build(BuildContext context) {
    final details = _details(context);
    final body = _body;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_iconFor(item.itemType)),
      title: Text(_title(context)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (details.isNotEmpty) Text(details.join('\n')),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            _TimelineBodyBlock(item: item, body: body),
          ],
          if (item.fileChanges.any(
            (change) => change.diff.trim().isNotEmpty,
          )) ...[
            const SizedBox(height: 8),
            for (final change in item.fileChanges)
              if (change.diff.trim().isNotEmpty)
                _TimelineDiffBlock(change: change),
          ],
          if (showRaw) ...[
            const SizedBox(height: 8),
            SelectableText(
              _rawJson,
              key: ValueKey('timeline-raw-${item.itemId}'),
            ),
          ],
        ],
      ),
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
      'commandExecution' when item.command != null => item.command!,
      'fileChange' => l10n.timelineFileChanges,
      'mcpToolCall' when item.server != null && item.tool != null =>
        '${item.server}/${item.tool}',
      'mcpToolCall' when item.tool != null => item.tool!,
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

  List<String> _details(BuildContext context) {
    final l10n = context.l10n;
    return [
      if (item.cwd != null && item.cwd!.isNotEmpty)
        '${l10n.approvalWorkingDirectory}: ${item.cwd}',
      if (item.status != null && item.status!.isNotEmpty)
        '${l10n.timelineStatus}: ${item.status}',
      if (item.exitCode != null) '${l10n.timelineExitCode}: ${item.exitCode}',
      if (item.durationMs != null)
        '${l10n.timelineDuration}: ${item.durationMs} ms',
      if (item.server != null && item.server!.isNotEmpty)
        '${l10n.approvalServer}: ${item.server}',
      if (item.tool != null && item.tool!.isNotEmpty)
        '${l10n.timelineTool}: ${item.tool}',
      if (item.fileChanges.isNotEmpty)
        '${l10n.timelineFileChanges}: ${item.fileChanges.map(_fileChangeLabel).join(', ')}',
    ];
  }

  String _fileChangeLabel(ThreadFileChangeSummary change) {
    if (change.path.isEmpty) {
      return change.kind;
    }
    return '${change.kind} ${change.path}';
  }

  IconData _iconFor(String itemType) {
    return switch (itemType) {
      'agentMessage' => Icons.smart_toy_outlined,
      'commandExecution' => Icons.terminal,
      'fileChange' => Icons.difference_outlined,
      'mcpToolCall' => Icons.extension_outlined,
      'plan' => Icons.checklist,
      _ => Icons.notes_outlined,
    };
  }
}

class _TimelineBodyBlock extends StatelessWidget {
  const _TimelineBodyBlock({required this.item, required this.body});

  final ChatTimelineItem item;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (item.itemType == 'commandExecution') {
      return _TerminalOutputBlock(text: body);
    }
    if (item.itemType == 'fileChange') {
      return _DiffTextBlock(text: body);
    }
    return Text(body);
  }
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
    return _DiffTextBlock(
      text: change.diff,
      label: label,
      blockKey: ValueKey('timeline-diff-output-$label'),
    );
  }
}

class _DiffTextBlock extends StatelessWidget {
  const _DiffTextBlock({
    required this.text,
    this.label,
    this.blockKey = const ValueKey('timeline-diff-output'),
  });

  final String text;
  final String? label;
  final Key blockKey;

  @override
  Widget build(BuildContext context) {
    final colors = SadCoderThemeColors.of(context);
    return Container(
      key: blockKey,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null && label!.trim().isNotEmpty)
            Container(
              color: colors.diffHeaderBackground,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                label!,
                style: TextStyle(
                  color: colors.diffHeaderForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (final line in text.trimRight().split('\n'))
            _DiffLine(line: line),
        ],
      ),
    );
  }
}

class _DiffLine extends StatelessWidget {
  const _DiffLine({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final colors = SadCoderThemeColors.of(context);
    final isAdded = line.startsWith('+') && !line.startsWith('+++');
    final isRemoved = line.startsWith('-') && !line.startsWith('---');
    final isHeader =
        line.startsWith('diff ') ||
        line.startsWith('index ') ||
        line.startsWith('@@') ||
        line.startsWith('---') ||
        line.startsWith('+++');
    return Container(
      color: isAdded
          ? colors.diffAddedBackground
          : isRemoved
          ? colors.diffRemovedBackground
          : isHeader
          ? colors.diffHeaderBackground
          : colors.codeBackground,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: SelectableText(
        line,
        style: TextStyle(
          color: isAdded
              ? colors.diffAddedForeground
              : isRemoved
              ? colors.diffRemovedForeground
              : isHeader
              ? colors.diffHeaderForeground
              : colors.codeForeground,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _ThreadDetailCard extends StatelessWidget {
  const _ThreadDetailCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _TurnSummaryTile extends StatelessWidget {
  const _TurnSummaryTile({required this.turn});

  final TurnSummary turn;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.notes_outlined),
      title: Text('${context.l10n.approvalTurn}: ${turn.id}'),
      subtitle: Text(
        '${turn.status} / ${turn.itemCount} items / ${turn.itemsView}',
      ),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}

class _SlashCommandPreview extends StatelessWidget {
  const _SlashCommandPreview({required this.result});

  final SlashCommandParseResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
        subtitle: l10n.slashCommandNotSentAsPrompt,
      ),
      SlashCommandParseKind.known => _PreviewCard(
        icon: Icons.terminal,
        title: result.command!.slash,
        subtitle: result.command!.description,
      ),
    };
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
