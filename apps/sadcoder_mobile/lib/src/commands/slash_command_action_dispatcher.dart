import 'dart:async';

import 'slash_command_registry.dart';

typedef SlashCommandDisconnect = Future<void> Function();
typedef SlashCommandClearTranscript = void Function();
typedef SlashCommandCopyLastResponse = Future<bool> Function();
typedef SlashCommandShowStatus = FutureOr<String?> Function();
typedef SlashCommandShowUsage = FutureOr<String?> Function();
typedef SlashCommandShowMcp = FutureOr<String?> Function(String arguments);
typedef SlashCommandShowSkills = FutureOr<String?> Function(String arguments);
typedef SlashCommandShowPlugins = FutureOr<String?> Function(String arguments);
typedef SlashCommandShowHooks = FutureOr<String?> Function(String arguments);
typedef SlashCommandShowApps = FutureOr<String?> Function(String arguments);
typedef SlashCommandShowDebugConfig =
    FutureOr<String?> Function(String arguments);
typedef SlashCommandShowDiff = FutureOr<String?> Function(String arguments);
typedef SlashCommandHandleGoal = FutureOr<String?> Function(String arguments);
typedef SlashCommandHandleReview = FutureOr<String?> Function(String arguments);
typedef SlashCommandShowBackgroundTerminals =
    FutureOr<String?> Function(String arguments);
typedef SlashCommandCleanBackgroundTerminals =
    FutureOr<String?> Function(String arguments);
typedef SlashCommandToggleRawTranscript = bool? Function(String arguments);
typedef SlashCommandStartNewThread = Future<bool> Function();
typedef SlashCommandResumeThread = Future<bool> Function(String threadId);
typedef SlashCommandRenameThread = Future<bool> Function(String name);
typedef SlashCommandLogout = Future<SlashCommandCallbackResult> Function();
typedef SlashCommandSubmitFeedback =
    Future<SlashCommandCallbackResult> Function();
typedef SlashCommandConfigureTheme =
    Future<SlashCommandCallbackResult> Function();
typedef SlashCommandConfigureTitleDisplay =
    Future<SlashCommandCallbackResult> Function();
typedef SlashCommandConfigureStatusLineDisplay =
    Future<SlashCommandCallbackResult> Function();
typedef SlashCommandToggleComposerVimMode =
    Future<SlashCommandCallbackResult> Function();
typedef SlashCommandMentionFile = Future<SlashCommandCallbackResult> Function();
typedef SlashCommandStartSideConversation =
    Future<SlashCommandCallbackResult> Function(
      String arguments, {
      required bool btw,
    });
typedef SlashCommandShowAgentTopology =
    Future<SlashCommandCallbackResult> Function({required bool subagentsOnly});
typedef SlashCommandConfirmedThreadAction =
    Future<SlashCommandCallbackResult> Function();
typedef SlashCommandConfiguredAction =
    Future<SlashCommandCallbackResult> Function();

enum SlashCommandCallbackResult { executed, cancelled, unavailable }

enum SlashCommandActionOutcome {
  ignored,
  executed,
  cancelled,
  unknown,
  unsupported,
  unavailable,
  failed,
}

enum SlashCommandActionEffect {
  none,
  disconnect,
  clearTranscript,
  copy,
  status,
  usage,
  mcp,
  skills,
  plugins,
  hooks,
  apps,
  debugConfig,
  diff,
  goal,
  review,
  backgroundTerminals,
  backgroundTerminalCleanup,
  rawTranscript,
  newThread,
  resumeThread,
  renameThread,
  forkThread,
  compactThread,
  archiveThread,
  deleteThread,
  logout,
  feedback,
  theme,
  titleDisplay,
  statusLineDisplay,
  composerVimMode,
  mention,
  sideConversation,
  agentTopology,
  modelOverride,
  personalityOverride,
  permissionsOverride,
}

class SlashCommandActionResult {
  const SlashCommandActionResult._({
    required this.outcome,
    required this.rawCommand,
    required this.arguments,
    this.command,
    this.effect = SlashCommandActionEffect.none,
    this.message,
    this.error,
  });

  const SlashCommandActionResult.ignored()
    : this._(
        outcome: SlashCommandActionOutcome.ignored,
        rawCommand: '',
        arguments: '',
      );

  const SlashCommandActionResult.executed({
    required SlashCommandSpec command,
    required String rawCommand,
    required String arguments,
    required SlashCommandActionEffect effect,
    String? message,
  }) : this._(
         outcome: SlashCommandActionOutcome.executed,
         command: command,
         rawCommand: rawCommand,
         arguments: arguments,
         effect: effect,
         message: message,
       );

  const SlashCommandActionResult.cancelled({
    required SlashCommandSpec command,
    required String rawCommand,
    required String arguments,
  }) : this._(
         outcome: SlashCommandActionOutcome.cancelled,
         command: command,
         rawCommand: rawCommand,
         arguments: arguments,
       );

  const SlashCommandActionResult.unknown({
    required String rawCommand,
    required String arguments,
  }) : this._(
         outcome: SlashCommandActionOutcome.unknown,
         rawCommand: rawCommand,
         arguments: arguments,
       );

  const SlashCommandActionResult.unsupported({
    required SlashCommandSpec command,
    required String rawCommand,
    required String arguments,
  }) : this._(
         outcome: SlashCommandActionOutcome.unsupported,
         command: command,
         rawCommand: rawCommand,
         arguments: arguments,
       );

  const SlashCommandActionResult.unavailable({
    required SlashCommandSpec command,
    required String rawCommand,
    required String arguments,
  }) : this._(
         outcome: SlashCommandActionOutcome.unavailable,
         command: command,
         rawCommand: rawCommand,
         arguments: arguments,
       );

  const SlashCommandActionResult.failed({
    required SlashCommandSpec command,
    required String rawCommand,
    required String arguments,
    required Object error,
  }) : this._(
         outcome: SlashCommandActionOutcome.failed,
         command: command,
         rawCommand: rawCommand,
         arguments: arguments,
         error: error,
       );

  final SlashCommandActionOutcome outcome;
  final SlashCommandSpec? command;
  final String rawCommand;
  final String arguments;
  final SlashCommandActionEffect effect;
  final String? message;
  final Object? error;

  String get slash => command?.slash ?? '/$rawCommand';
}

class SlashCommandActionDispatcher {
  const SlashCommandActionDispatcher({
    this.disconnect,
    this.clearTranscript,
    this.copyLastResponse,
    this.showStatus,
    this.showUsage,
    this.showMcp,
    this.showSkills,
    this.showPlugins,
    this.showHooks,
    this.showApps,
    this.showDebugConfig,
    this.showDiff,
    this.handleGoal,
    this.handleReview,
    this.showBackgroundTerminals,
    this.cleanBackgroundTerminals,
    this.toggleRawTranscript,
    this.startNewThread,
    this.resumeThread,
    this.renameThread,
    this.logout,
    this.submitFeedback,
    this.configureTheme,
    this.configureTitleDisplay,
    this.configureStatusLineDisplay,
    this.toggleComposerVimMode,
    this.mentionFile,
    this.startSideConversation,
    this.showAgentTopology,
    this.forkThread,
    this.compactThread,
    this.archiveThread,
    this.deleteThread,
    this.configureModel,
    this.configurePersonality,
    this.configurePermissions,
  });

  final SlashCommandDisconnect? disconnect;
  final SlashCommandClearTranscript? clearTranscript;
  final SlashCommandCopyLastResponse? copyLastResponse;
  final SlashCommandShowStatus? showStatus;
  final SlashCommandShowUsage? showUsage;
  final SlashCommandShowMcp? showMcp;
  final SlashCommandShowSkills? showSkills;
  final SlashCommandShowPlugins? showPlugins;
  final SlashCommandShowHooks? showHooks;
  final SlashCommandShowApps? showApps;
  final SlashCommandShowDebugConfig? showDebugConfig;
  final SlashCommandShowDiff? showDiff;
  final SlashCommandHandleGoal? handleGoal;
  final SlashCommandHandleReview? handleReview;
  final SlashCommandShowBackgroundTerminals? showBackgroundTerminals;
  final SlashCommandCleanBackgroundTerminals? cleanBackgroundTerminals;
  final SlashCommandToggleRawTranscript? toggleRawTranscript;
  final SlashCommandStartNewThread? startNewThread;
  final SlashCommandResumeThread? resumeThread;
  final SlashCommandRenameThread? renameThread;
  final SlashCommandLogout? logout;
  final SlashCommandSubmitFeedback? submitFeedback;
  final SlashCommandConfigureTheme? configureTheme;
  final SlashCommandConfigureTitleDisplay? configureTitleDisplay;
  final SlashCommandConfigureStatusLineDisplay? configureStatusLineDisplay;
  final SlashCommandToggleComposerVimMode? toggleComposerVimMode;
  final SlashCommandMentionFile? mentionFile;
  final SlashCommandStartSideConversation? startSideConversation;
  final SlashCommandShowAgentTopology? showAgentTopology;
  final SlashCommandConfiguredAction? forkThread;
  final SlashCommandConfiguredAction? compactThread;
  final SlashCommandConfirmedThreadAction? archiveThread;
  final SlashCommandConfirmedThreadAction? deleteThread;
  final SlashCommandConfiguredAction? configureModel;
  final SlashCommandConfiguredAction? configurePersonality;
  final SlashCommandConfiguredAction? configurePermissions;

  Future<SlashCommandActionResult> dispatch(
    SlashCommandParseResult parsed, {
    required bool hasActiveTurn,
    bool isSideConversation = false,
  }) async {
    switch (parsed.kind) {
      case SlashCommandParseKind.notSlash || SlashCommandParseKind.empty:
        return const SlashCommandActionResult.ignored();
      case SlashCommandParseKind.unknown:
        return SlashCommandActionResult.unknown(
          rawCommand: parsed.rawCommand,
          arguments: parsed.arguments,
        );
      case SlashCommandParseKind.known:
        return _dispatchKnown(
          parsed,
          hasActiveTurn: hasActiveTurn,
          isSideConversation: isSideConversation,
        );
    }
  }

  Future<SlashCommandActionResult> _dispatchKnown(
    SlashCommandParseResult parsed, {
    required bool hasActiveTurn,
    required bool isSideConversation,
  }) async {
    final command = parsed.command!;
    if (hasActiveTurn && !command.availableDuringTask) {
      return SlashCommandActionResult.unavailable(
        command: command,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    if (isSideConversation && !command.availableInSideConversation) {
      return SlashCommandActionResult.unavailable(
        command: command,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }

    switch (command.command) {
      case 'model':
        return _configuredAction(
          parsed,
          action: configureModel,
          effect: SlashCommandActionEffect.modelOverride,
        );
      case 'personality':
        return _configuredAction(
          parsed,
          action: configurePersonality,
          effect: SlashCommandActionEffect.personalityOverride,
        );
      case 'permissions':
        return _configuredAction(
          parsed,
          action: configurePermissions,
          effect: SlashCommandActionEffect.permissionsOverride,
        );
      case 'quit' || 'exit':
        return _disconnect(parsed);
      case 'clear':
        return _clearTranscript(parsed);
      case 'copy':
        return _copyLastResponse(parsed);
      case 'status':
        return _showStatus(parsed);
      case 'usage':
        return _showUsage(parsed);
      case 'mcp':
        return _showMcp(parsed);
      case 'skills':
        return _showSkills(parsed);
      case 'plugins':
        return _showPlugins(parsed);
      case 'hooks':
        return _showHooks(parsed);
      case 'apps':
        return _showApps(parsed);
      case 'debug-config':
        return _showDebugConfig(parsed);
      case 'diff':
        return _showDiff(parsed);
      case 'goal':
        return _handleGoal(parsed);
      case 'agent':
        return _showAgentTopology(parsed, subagentsOnly: false);
      case 'subagents':
        return _showAgentTopology(parsed, subagentsOnly: true);
      case 'review':
        return _handleReview(parsed);
      case 'ps':
        return _showBackgroundTerminals(parsed);
      case 'stop':
        return _cleanBackgroundTerminals(parsed);
      case 'raw':
        return _toggleRawTranscript(parsed);
      case 'new':
        return _startNewThread(parsed);
      case 'resume':
        return _resumeThread(parsed);
      case 'rename':
        return _renameThread(parsed);
      case 'fork':
        return _configuredAction(
          parsed,
          action: forkThread,
          effect: SlashCommandActionEffect.forkThread,
        );
      case 'compact':
        return _configuredAction(
          parsed,
          action: compactThread,
          effect: SlashCommandActionEffect.compactThread,
        );
      case 'archive':
        return _confirmedThreadAction(
          parsed,
          action: archiveThread,
          effect: SlashCommandActionEffect.archiveThread,
        );
      case 'delete':
        return _confirmedThreadAction(
          parsed,
          action: deleteThread,
          effect: SlashCommandActionEffect.deleteThread,
        );
      case 'logout':
        return _logout(parsed);
      case 'feedback':
        return _submitFeedback(parsed);
      case 'theme':
        return _configureTheme(parsed);
      case 'title':
        return _configureTitleDisplay(parsed);
      case 'statusline':
        return _configureStatusLineDisplay(parsed);
      case 'vim':
        return _toggleComposerVimMode(parsed);
      case 'mention':
        return _mentionFile(parsed);
      case 'side':
        return _startSideConversation(parsed, btw: false);
      case 'btw':
        return _startSideConversation(parsed, btw: true);
      default:
        return SlashCommandActionResult.unsupported(
          command: command,
          rawCommand: parsed.rawCommand,
          arguments: parsed.arguments,
        );
    }
  }

  Future<SlashCommandActionResult> _disconnect(
    SlashCommandParseResult parsed,
  ) async {
    final disconnect = this.disconnect;
    if (disconnect == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      await disconnect();
      return SlashCommandActionResult.executed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        effect: SlashCommandActionEffect.disconnect,
      );
    } on Object catch (error) {
      return SlashCommandActionResult.failed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        error: error,
      );
    }
  }

  SlashCommandActionResult _clearTranscript(SlashCommandParseResult parsed) {
    final clearTranscript = this.clearTranscript;
    if (clearTranscript == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      clearTranscript();
      return SlashCommandActionResult.executed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        effect: SlashCommandActionEffect.clearTranscript,
      );
    } on Object catch (error) {
      return SlashCommandActionResult.failed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        error: error,
      );
    }
  }

  Future<SlashCommandActionResult> _copyLastResponse(
    SlashCommandParseResult parsed,
  ) async {
    final copyLastResponse = this.copyLastResponse;
    if (copyLastResponse == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      final copied = await copyLastResponse();
      if (!copied) {
        return SlashCommandActionResult.unavailable(
          command: parsed.command!,
          rawCommand: parsed.rawCommand,
          arguments: parsed.arguments,
        );
      }
      return SlashCommandActionResult.executed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        effect: SlashCommandActionEffect.copy,
      );
    } on Object catch (error) {
      return SlashCommandActionResult.failed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        error: error,
      );
    }
  }

  Future<SlashCommandActionResult> _showStatus(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessage(
      parsed,
      action: showStatus,
      effect: SlashCommandActionEffect.status,
    );
  }

  Future<SlashCommandActionResult> _showUsage(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessage(
      parsed,
      action: showUsage,
      effect: SlashCommandActionEffect.usage,
    );
  }

  Future<SlashCommandActionResult> _showMcp(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: showMcp,
      effect: SlashCommandActionEffect.mcp,
    );
  }

  Future<SlashCommandActionResult> _showSkills(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: showSkills,
      effect: SlashCommandActionEffect.skills,
    );
  }

  Future<SlashCommandActionResult> _showPlugins(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: showPlugins,
      effect: SlashCommandActionEffect.plugins,
    );
  }

  Future<SlashCommandActionResult> _showHooks(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: showHooks,
      effect: SlashCommandActionEffect.hooks,
    );
  }

  Future<SlashCommandActionResult> _showApps(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: showApps,
      effect: SlashCommandActionEffect.apps,
    );
  }

  Future<SlashCommandActionResult> _showDebugConfig(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: showDebugConfig,
      effect: SlashCommandActionEffect.debugConfig,
    );
  }

  Future<SlashCommandActionResult> _showDiff(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: showDiff,
      effect: SlashCommandActionEffect.diff,
    );
  }

  Future<SlashCommandActionResult> _handleGoal(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: handleGoal,
      effect: SlashCommandActionEffect.goal,
    );
  }

  Future<SlashCommandActionResult> _handleReview(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: handleReview,
      effect: SlashCommandActionEffect.review,
    );
  }

  Future<SlashCommandActionResult> _showBackgroundTerminals(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: showBackgroundTerminals,
      effect: SlashCommandActionEffect.backgroundTerminals,
    );
  }

  Future<SlashCommandActionResult> _cleanBackgroundTerminals(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: cleanBackgroundTerminals,
      effect: SlashCommandActionEffect.backgroundTerminalCleanup,
    );
  }

  Future<SlashCommandActionResult> _showMessage(
    SlashCommandParseResult parsed, {
    required FutureOr<String?> Function()? action,
    required SlashCommandActionEffect effect,
  }) async {
    return _showMessageWithArguments(
      parsed,
      action: action == null ? null : (_) => action(),
      effect: effect,
    );
  }

  Future<SlashCommandActionResult> _showMessageWithArguments(
    SlashCommandParseResult parsed, {
    required FutureOr<String?> Function(String arguments)? action,
    required SlashCommandActionEffect effect,
  }) async {
    if (action == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      final message = (await action(parsed.arguments))?.trim();
      if (message == null || message.isEmpty) {
        return SlashCommandActionResult.unavailable(
          command: parsed.command!,
          rawCommand: parsed.rawCommand,
          arguments: parsed.arguments,
        );
      }
      return SlashCommandActionResult.executed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        effect: effect,
        message: message,
      );
    } on Object catch (error) {
      return SlashCommandActionResult.failed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        error: error,
      );
    }
  }

  SlashCommandActionResult _toggleRawTranscript(
    SlashCommandParseResult parsed,
  ) {
    final toggleRawTranscript = this.toggleRawTranscript;
    if (toggleRawTranscript == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      final enabled = toggleRawTranscript(parsed.arguments);
      if (enabled == null) {
        return SlashCommandActionResult.unavailable(
          command: parsed.command!,
          rawCommand: parsed.rawCommand,
          arguments: parsed.arguments,
        );
      }
      return SlashCommandActionResult.executed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        effect: SlashCommandActionEffect.rawTranscript,
      );
    } on Object catch (error) {
      return SlashCommandActionResult.failed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        error: error,
      );
    }
  }

  Future<SlashCommandActionResult> _startNewThread(
    SlashCommandParseResult parsed,
  ) async {
    final startNewThread = this.startNewThread;
    if (startNewThread == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      final started = await startNewThread();
      if (!started) {
        return SlashCommandActionResult.unavailable(
          command: parsed.command!,
          rawCommand: parsed.rawCommand,
          arguments: parsed.arguments,
        );
      }
      return SlashCommandActionResult.executed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        effect: SlashCommandActionEffect.newThread,
      );
    } on Object catch (error) {
      return SlashCommandActionResult.failed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        error: error,
      );
    }
  }

  Future<SlashCommandActionResult> _resumeThread(
    SlashCommandParseResult parsed,
  ) async {
    final resumeThread = this.resumeThread;
    if (resumeThread == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    final threadId = parsed.arguments.trim();
    if (threadId.isEmpty) {
      return SlashCommandActionResult.unavailable(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      final resumed = await resumeThread(threadId);
      if (!resumed) {
        return SlashCommandActionResult.unavailable(
          command: parsed.command!,
          rawCommand: parsed.rawCommand,
          arguments: parsed.arguments,
        );
      }
      return SlashCommandActionResult.executed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        effect: SlashCommandActionEffect.resumeThread,
      );
    } on Object catch (error) {
      return SlashCommandActionResult.failed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        error: error,
      );
    }
  }

  Future<SlashCommandActionResult> _renameThread(
    SlashCommandParseResult parsed,
  ) async {
    final renameThread = this.renameThread;
    if (renameThread == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    final name = parsed.arguments.trim();
    if (name.isEmpty) {
      return SlashCommandActionResult.unavailable(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      final renamed = await renameThread(name);
      if (!renamed) {
        return SlashCommandActionResult.unavailable(
          command: parsed.command!,
          rawCommand: parsed.rawCommand,
          arguments: parsed.arguments,
        );
      }
      return SlashCommandActionResult.executed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        effect: SlashCommandActionEffect.renameThread,
      );
    } on Object catch (error) {
      return SlashCommandActionResult.failed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        error: error,
      );
    }
  }

  Future<SlashCommandActionResult> _confirmedThreadAction(
    SlashCommandParseResult parsed, {
    required SlashCommandConfirmedThreadAction? action,
    required SlashCommandActionEffect effect,
  }) async {
    return _callbackAction(parsed, action: action, effect: effect);
  }

  Future<SlashCommandActionResult> _logout(
    SlashCommandParseResult parsed,
  ) async {
    if (parsed.arguments.trim().isNotEmpty) {
      return SlashCommandActionResult.unavailable(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    return _callbackAction(
      parsed,
      action: logout,
      effect: SlashCommandActionEffect.logout,
    );
  }

  Future<SlashCommandActionResult> _submitFeedback(
    SlashCommandParseResult parsed,
  ) async {
    if (parsed.arguments.trim().isNotEmpty) {
      return SlashCommandActionResult.unavailable(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    return _callbackAction(
      parsed,
      action: submitFeedback,
      effect: SlashCommandActionEffect.feedback,
    );
  }

  Future<SlashCommandActionResult> _configureTheme(
    SlashCommandParseResult parsed,
  ) async {
    if (parsed.arguments.trim().isNotEmpty) {
      return SlashCommandActionResult.unavailable(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    return _callbackAction(
      parsed,
      action: configureTheme,
      effect: SlashCommandActionEffect.theme,
    );
  }

  Future<SlashCommandActionResult> _configureTitleDisplay(
    SlashCommandParseResult parsed,
  ) async {
    if (parsed.arguments.trim().isNotEmpty) {
      return SlashCommandActionResult.unavailable(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    return _callbackAction(
      parsed,
      action: configureTitleDisplay,
      effect: SlashCommandActionEffect.titleDisplay,
    );
  }

  Future<SlashCommandActionResult> _configureStatusLineDisplay(
    SlashCommandParseResult parsed,
  ) async {
    if (parsed.arguments.trim().isNotEmpty) {
      return SlashCommandActionResult.unavailable(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    return _callbackAction(
      parsed,
      action: configureStatusLineDisplay,
      effect: SlashCommandActionEffect.statusLineDisplay,
    );
  }

  Future<SlashCommandActionResult> _toggleComposerVimMode(
    SlashCommandParseResult parsed,
  ) async {
    if (parsed.arguments.trim().isNotEmpty) {
      return SlashCommandActionResult.unavailable(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    return _callbackAction(
      parsed,
      action: toggleComposerVimMode,
      effect: SlashCommandActionEffect.composerVimMode,
    );
  }

  Future<SlashCommandActionResult> _mentionFile(
    SlashCommandParseResult parsed,
  ) async {
    if (parsed.arguments.trim().isNotEmpty) {
      return SlashCommandActionResult.unavailable(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    return _callbackAction(
      parsed,
      action: mentionFile,
      effect: SlashCommandActionEffect.mention,
    );
  }

  Future<SlashCommandActionResult> _startSideConversation(
    SlashCommandParseResult parsed, {
    required bool btw,
  }) async {
    final startSideConversation = this.startSideConversation;
    if (startSideConversation == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      final result = await startSideConversation(parsed.arguments, btw: btw);
      return switch (result) {
        SlashCommandCallbackResult.executed =>
          SlashCommandActionResult.executed(
            command: parsed.command!,
            rawCommand: parsed.rawCommand,
            arguments: parsed.arguments,
            effect: SlashCommandActionEffect.sideConversation,
          ),
        SlashCommandCallbackResult.cancelled =>
          SlashCommandActionResult.cancelled(
            command: parsed.command!,
            rawCommand: parsed.rawCommand,
            arguments: parsed.arguments,
          ),
        SlashCommandCallbackResult.unavailable =>
          SlashCommandActionResult.unavailable(
            command: parsed.command!,
            rawCommand: parsed.rawCommand,
            arguments: parsed.arguments,
          ),
      };
    } on Object catch (error) {
      return SlashCommandActionResult.failed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        error: error,
      );
    }
  }

  Future<SlashCommandActionResult> _showAgentTopology(
    SlashCommandParseResult parsed, {
    required bool subagentsOnly,
  }) async {
    if (parsed.arguments.trim().isNotEmpty) {
      return SlashCommandActionResult.unavailable(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    final showAgentTopology = this.showAgentTopology;
    if (showAgentTopology == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      final result = await showAgentTopology(subagentsOnly: subagentsOnly);
      return switch (result) {
        SlashCommandCallbackResult.executed =>
          SlashCommandActionResult.executed(
            command: parsed.command!,
            rawCommand: parsed.rawCommand,
            arguments: parsed.arguments,
            effect: SlashCommandActionEffect.agentTopology,
          ),
        SlashCommandCallbackResult.cancelled =>
          SlashCommandActionResult.cancelled(
            command: parsed.command!,
            rawCommand: parsed.rawCommand,
            arguments: parsed.arguments,
          ),
        SlashCommandCallbackResult.unavailable =>
          SlashCommandActionResult.unavailable(
            command: parsed.command!,
            rawCommand: parsed.rawCommand,
            arguments: parsed.arguments,
          ),
      };
    } on Object catch (error) {
      return SlashCommandActionResult.failed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        error: error,
      );
    }
  }

  Future<SlashCommandActionResult> _configuredAction(
    SlashCommandParseResult parsed, {
    required SlashCommandConfiguredAction? action,
    required SlashCommandActionEffect effect,
  }) async {
    return _callbackAction(parsed, action: action, effect: effect);
  }

  Future<SlashCommandActionResult> _callbackAction(
    SlashCommandParseResult parsed, {
    required Future<SlashCommandCallbackResult> Function()? action,
    required SlashCommandActionEffect effect,
  }) async {
    if (action == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      final result = await action();
      return switch (result) {
        SlashCommandCallbackResult.executed =>
          SlashCommandActionResult.executed(
            command: parsed.command!,
            rawCommand: parsed.rawCommand,
            arguments: parsed.arguments,
            effect: effect,
          ),
        SlashCommandCallbackResult.cancelled =>
          SlashCommandActionResult.cancelled(
            command: parsed.command!,
            rawCommand: parsed.rawCommand,
            arguments: parsed.arguments,
          ),
        SlashCommandCallbackResult.unavailable =>
          SlashCommandActionResult.unavailable(
            command: parsed.command!,
            rawCommand: parsed.rawCommand,
            arguments: parsed.arguments,
          ),
      };
    } on Object catch (error) {
      return SlashCommandActionResult.failed(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
        error: error,
      );
    }
  }
}
