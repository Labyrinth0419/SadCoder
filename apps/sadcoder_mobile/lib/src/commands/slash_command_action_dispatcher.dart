import 'dart:async';

import 'slash_command_registry.dart';

typedef SlashCommandDisconnect = Future<void> Function();
typedef SlashCommandClearTranscript = void Function();
typedef SlashCommandCopyLastResponse = Future<bool> Function();
typedef SlashCommandShowStatus = FutureOr<String?> Function();
typedef SlashCommandShowUsage = FutureOr<String?> Function();
typedef SlashCommandShowMcp = FutureOr<String?> Function(String arguments);
typedef SlashCommandHandleGoal = FutureOr<String?> Function(String arguments);
typedef SlashCommandToggleRawTranscript = bool? Function(String arguments);
typedef SlashCommandStartNewThread = Future<bool> Function();
typedef SlashCommandResumeThread = Future<bool> Function(String threadId);
typedef SlashCommandRenameThread = Future<bool> Function(String name);
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
  goal,
  rawTranscript,
  newThread,
  resumeThread,
  renameThread,
  forkThread,
  compactThread,
  archiveThread,
  deleteThread,
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
    this.handleGoal,
    this.toggleRawTranscript,
    this.startNewThread,
    this.resumeThread,
    this.renameThread,
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
  final SlashCommandHandleGoal? handleGoal;
  final SlashCommandToggleRawTranscript? toggleRawTranscript;
  final SlashCommandStartNewThread? startNewThread;
  final SlashCommandResumeThread? resumeThread;
  final SlashCommandRenameThread? renameThread;
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
        return _dispatchKnown(parsed, hasActiveTurn: hasActiveTurn);
    }
  }

  Future<SlashCommandActionResult> _dispatchKnown(
    SlashCommandParseResult parsed, {
    required bool hasActiveTurn,
  }) async {
    final command = parsed.command!;
    if (hasActiveTurn && !command.availableDuringTask) {
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
      case 'goal':
        return _handleGoal(parsed);
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

  Future<SlashCommandActionResult> _handleGoal(
    SlashCommandParseResult parsed,
  ) async {
    return _showMessageWithArguments(
      parsed,
      action: handleGoal,
      effect: SlashCommandActionEffect.goal,
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
