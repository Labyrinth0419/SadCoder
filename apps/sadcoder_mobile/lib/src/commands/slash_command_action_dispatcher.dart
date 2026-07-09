import 'slash_command_registry.dart';

typedef SlashCommandDisconnect = Future<void> Function();
typedef SlashCommandClearTranscript = void Function();
typedef SlashCommandCopyLastResponse = Future<bool> Function();
typedef SlashCommandShowStatus = String? Function();
typedef SlashCommandToggleRawTranscript = bool? Function(String arguments);

enum SlashCommandActionOutcome {
  ignored,
  executed,
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
  rawTranscript,
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
    this.toggleRawTranscript,
  });

  final SlashCommandDisconnect? disconnect;
  final SlashCommandClearTranscript? clearTranscript;
  final SlashCommandCopyLastResponse? copyLastResponse;
  final SlashCommandShowStatus? showStatus;
  final SlashCommandToggleRawTranscript? toggleRawTranscript;

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
      case 'quit' || 'exit':
        return _disconnect(parsed);
      case 'clear':
        return _clearTranscript(parsed);
      case 'copy':
        return _copyLastResponse(parsed);
      case 'status':
        return _showStatus(parsed);
      case 'raw':
        return _toggleRawTranscript(parsed);
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

  SlashCommandActionResult _showStatus(SlashCommandParseResult parsed) {
    final showStatus = this.showStatus;
    if (showStatus == null) {
      return SlashCommandActionResult.unsupported(
        command: parsed.command!,
        rawCommand: parsed.rawCommand,
        arguments: parsed.arguments,
      );
    }
    try {
      final message = showStatus()?.trim();
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
        effect: SlashCommandActionEffect.status,
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
}
