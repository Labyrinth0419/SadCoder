import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../accounts/account_snapshot_controller.dart';
import '../../commands/slash_command_action_dispatcher.dart';
import '../../commands/slash_command_registry.dart';
import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
import '../../config/codex_config_snapshot_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../mcp/mcp_server_status_controller.dart';
import '../../mcp/mcp_server_status_reader.dart';
import '../../models/model_list_controller.dart';
import '../../permissions/permission_profile_list_controller.dart';
import '../../permissions/permission_profile_list_reader.dart';
import '../../reviews/thread_review_command.dart';
import '../../session/codex_session_state_controller.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_list_controller.dart';
import '../../threads/thread_mutation_runner.dart';
import '../../threads/thread_summary.dart';
import '../../turns/turn_controller.dart';
import '../../usage/account_usage_snapshot_controller.dart';
import 'chat_background_terminal_summary.dart';
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
  CodexSessionStatus? _lastSessionStatus;
  bool _slashPaletteOpen = false;
  bool _showRawTranscript = false;

  @override
  void initState() {
    super.initState();
    widget.sessionController?.addListener(_handleSessionChanged);
    widget.turnController?.addListener(_handleTurnChanged);
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
  }

  @override
  void dispose() {
    widget.sessionController?.removeListener(_handleSessionChanged);
    widget.turnController?.removeListener(_handleTurnChanged);
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.chat,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              _StateChip(
                label: _connectionLabel(l10n, sessionController?.status),
                connected:
                    sessionController?.status == CodexSessionStatus.connected,
              ),
            ],
          ),
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
                TextField(
                  key: const ValueKey('chat-composer-field'),
                  controller: _composerController,
                  onChanged: _handleComposerChanged,
                  decoration: InputDecoration(
                    hintText: l10n.connectBeforeTurn,
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleComposerChanged(String value) {
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
    await turnController.submitText(text);
    if (turnController.status != TurnControllerStatus.failed) {
      widget.configOverrideController?.clearTurn();
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
    );
    if (!mounted) {
      return;
    }
    if (result.outcome == SlashCommandActionOutcome.ignored) {
      return;
    }
    if (result.outcome == SlashCommandActionOutcome.executed) {
      _composerController.clear();
      _handleComposerChanged('');
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
          handleGoal: _handleGoalCommand,
          handleReview: _handleReviewCommand,
          showBackgroundTerminals: _buildBackgroundTerminalsSummary,
          cleanBackgroundTerminals: _cleanBackgroundTerminals,
          toggleRawTranscript: _toggleRawTranscript,
          startNewThread: _startNewThread,
          resumeThread: _resumeThread,
          renameThread: _renameThread,
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
        cwds: _currentSkillCwds(),
        forceReload: forceReload,
      );
      return buildSkillsSummary(l10n: l10n, page: page);
    } on Object catch (error) {
      return '${l10n.skillsTitle}\n${l10n.skillsLoadFailed}: $error';
    }
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

  Future<bool> _startNewThread() async {
    final turnController = widget.turnController;
    if (turnController == null) {
      return false;
    }
    final started = await turnController.startNewThread();
    if (!started) {
      return false;
    }
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
    widget.timelineController?.showThread(forked);
    unawaited(widget.threadDetailController?.readThread(forked.id));
    unawaited(widget.threadListController?.refresh());
    return SlashCommandCallbackResult.executed;
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

  List<String> _currentSkillCwds() {
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

  void _clearLocalTranscript() {
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
        SlashCommandActionEffect.modelOverride => l10n.slashCommandModelUpdated,
        SlashCommandActionEffect.personalityOverride =>
          l10n.slashCommandPersonalityUpdated,
        SlashCommandActionEffect.permissionsOverride =>
          l10n.slashCommandPermissionsUpdated,
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
      SlashCommandActionOutcome.unsupported => l10n.slashCommandUnsupported(
        result.slash,
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
    _lastSessionStatus = status;
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTurnChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _refreshThreadsIfConnected() {
    if (widget.sessionController?.status == CodexSessionStatus.connected) {
      unawaited(widget.threadListController?.refresh());
    }
  }

  String _connectionLabel(AppLocalizations l10n, CodexSessionStatus? status) {
    return sessionStatusLabel(l10n, status);
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
    return _approvalPolicy == 'never' ||
        _sandboxMode == 'dangerFullAccess' ||
        _permissionProfile == ':danger-full-access';
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
          if (body.isNotEmpty) ...[const SizedBox(height: 4), Text(body)],
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
