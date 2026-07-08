enum SlashCommandMappingType {
  appServer,
  uiOnly,
  agentFallback,
  topology,
  notApplicable,
  debug,
}

enum SlashCommandPhase {
  mvp,
  secondStage,
  secondStageExperimental,
  thirdStage,
  advancedDebug,
}

enum SlashCommandRiskLevel { low, medium, high }

enum SlashPlatformVisibility {
  all,
  desktopOnly,
  windowsOnly,
  debugOnly,
  tuiOnly,
}

class SlashCommandSpec {
  const SlashCommandSpec({
    required this.command,
    required this.description,
    required this.mappingType,
    required this.mappingTarget,
    required this.phase,
    this.aliases = const [],
    this.supportsInlineArgs = false,
    this.availableDuringTask = true,
    this.availableInSideConversation = false,
    this.platformVisibility = SlashPlatformVisibility.all,
    this.featureFlag,
    this.riskLevel = SlashCommandRiskLevel.low,
  });

  factory SlashCommandSpec.fromJson(Map<String, Object?> json) {
    return SlashCommandSpec(
      command: _requiredString(json, 'command'),
      aliases: _stringList(json['aliases']),
      description: _requiredString(json, 'description'),
      supportsInlineArgs: json['supportsInlineArgs'] as bool? ?? false,
      availableDuringTask: json['availableDuringTask'] as bool? ?? true,
      availableInSideConversation:
          json['availableInSideConversation'] as bool? ?? false,
      platformVisibility: _enumByName(
        SlashPlatformVisibility.values,
        _requiredString(json, 'platformVisibility'),
      ),
      featureFlag: json['featureFlag'] as String?,
      mappingType: _enumByName(
        SlashCommandMappingType.values,
        _requiredString(json, 'mappingType'),
      ),
      mappingTarget: _requiredString(json, 'mappingTarget'),
      phase: _enumByName(
        SlashCommandPhase.values,
        _requiredString(json, 'phase'),
      ),
      riskLevel: _enumByName(
        SlashCommandRiskLevel.values,
        _requiredString(json, 'riskLevel'),
      ),
    );
  }

  final String command;
  final List<String> aliases;
  final String description;
  final bool supportsInlineArgs;
  final bool availableDuringTask;
  final bool availableInSideConversation;
  final SlashPlatformVisibility platformVisibility;
  final String? featureFlag;
  final SlashCommandMappingType mappingType;
  final String mappingTarget;
  final SlashCommandPhase phase;
  final SlashCommandRiskLevel riskLevel;

  String get slash => '/$command';

  bool matches(String value) {
    final normalized = _normalizeCommand(value);
    return command == normalized || aliases.contains(normalized);
  }
}

class SlashCommandManifest {
  const SlashCommandManifest({
    required this.schemaVersion,
    required this.source,
    required this.commands,
  });

  factory SlashCommandManifest.fromJson(Map<String, Object?> json) {
    final commands = json['commands'];
    if (commands is! List<Object?>) {
      throw const FormatException(
        'Slash command manifest commands must be a list.',
      );
    }

    return SlashCommandManifest(
      schemaVersion: json['schemaVersion'] as int? ?? 0,
      source: _requiredString(json, 'source'),
      commands: [
        for (final command in commands)
          SlashCommandSpec.fromJson(command as Map<String, Object?>),
      ],
    );
  }

  final int schemaVersion;
  final String source;
  final List<SlashCommandSpec> commands;

  SlashCommandRegistry asRegistry() => SlashCommandRegistry(commands: commands);
}

enum SlashCommandParseKind { notSlash, empty, known, unknown }

class SlashCommandParseResult {
  const SlashCommandParseResult._({
    required this.kind,
    required this.rawCommand,
    required this.arguments,
    this.command,
  });

  const SlashCommandParseResult.notSlash()
    : this._(
        kind: SlashCommandParseKind.notSlash,
        rawCommand: '',
        arguments: '',
      );

  const SlashCommandParseResult.empty()
    : this._(kind: SlashCommandParseKind.empty, rawCommand: '', arguments: '');

  const SlashCommandParseResult.unknown({
    required String rawCommand,
    required String arguments,
  }) : this._(
         kind: SlashCommandParseKind.unknown,
         rawCommand: rawCommand,
         arguments: arguments,
       );

  const SlashCommandParseResult.known({
    required SlashCommandSpec command,
    required String rawCommand,
    required String arguments,
  }) : this._(
         kind: SlashCommandParseKind.known,
         command: command,
         rawCommand: rawCommand,
         arguments: arguments,
       );

  final SlashCommandParseKind kind;
  final SlashCommandSpec? command;
  final String rawCommand;
  final String arguments;

  bool get shouldSendAsPrompt => kind == SlashCommandParseKind.notSlash;
}

class SlashCommandRegistry {
  const SlashCommandRegistry({this.commands = builtInSlashCommands});

  final List<SlashCommandSpec> commands;

  SlashCommandSpec? find(String commandOrAlias) {
    final normalized = _normalizeCommand(commandOrAlias);
    for (final command in commands) {
      if (command.matches(normalized)) {
        return command;
      }
    }
    return null;
  }

  SlashCommandParseResult parseComposerText(String text) {
    final trimmedLeft = text.trimLeft();
    if (!trimmedLeft.startsWith('/')) {
      return const SlashCommandParseResult.notSlash();
    }

    final withoutSlash = trimmedLeft.substring(1);
    if (withoutSlash.trim().isEmpty) {
      return const SlashCommandParseResult.empty();
    }

    final separator = withoutSlash.indexOf(RegExp(r'\s'));
    final rawCommand = separator == -1
        ? withoutSlash.trim()
        : withoutSlash.substring(0, separator).trim();
    final arguments = separator == -1
        ? ''
        : withoutSlash.substring(separator).trimLeft();
    final command = find(rawCommand);

    if (command == null) {
      return SlashCommandParseResult.unknown(
        rawCommand: rawCommand,
        arguments: arguments,
      );
    }

    return SlashCommandParseResult.known(
      command: command,
      rawCommand: rawCommand,
      arguments: arguments,
    );
  }
}

const slashCommandManifestSource =
    'refs/codex/codex-rs/tui/src/slash_command.rs';

const builtInSlashCommands = <SlashCommandSpec>[
  SlashCommandSpec(
    command: 'model',
    description: 'choose what model and reasoning effort to use',
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'model/list + session override',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'ide',
    description:
        'include current selection, open files, and other context from your IDE',
    supportsInlineArgs: true,
    availableInSideConversation: true,
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'mobile context attachment substitute',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'permissions',
    description: 'choose what Codex is allowed to do',
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'permission profile and sandbox override',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'keymap',
    description: 'remap TUI shortcuts',
    supportsInlineArgs: true,
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'mobile keyboard shortcut settings',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'vim',
    description: 'toggle Vim mode for the composer',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'composer input mode',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'setup-default-sandbox',
    description: 'set up elevated agent sandbox',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.agentFallback,
    mappingTarget: 'codex sandbox setup fallback',
    phase: SlashCommandPhase.thirdStage,
    riskLevel: SlashCommandRiskLevel.high,
  ),
  SlashCommandSpec(
    command: 'sandbox-add-read-dir',
    description:
        'let sandbox read a directory: /sandbox-add-read-dir <absolute_path>',
    supportsInlineArgs: true,
    availableDuringTask: false,
    platformVisibility: SlashPlatformVisibility.windowsOnly,
    mappingType: SlashCommandMappingType.agentFallback,
    mappingTarget: 'windows sandbox read directory configuration',
    phase: SlashCommandPhase.thirdStage,
    riskLevel: SlashCommandRiskLevel.high,
  ),
  SlashCommandSpec(
    command: 'experimental',
    description: 'toggle experimental features',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.agentFallback,
    mappingTarget: 'server Codex config experimental toggles',
    phase: SlashCommandPhase.thirdStage,
    riskLevel: SlashCommandRiskLevel.medium,
  ),
  SlashCommandSpec(
    command: 'approve',
    description: 'approve one retry of a recent auto-review denial',
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'auto-review retry approval',
    phase: SlashCommandPhase.thirdStage,
    riskLevel: SlashCommandRiskLevel.medium,
  ),
  SlashCommandSpec(
    command: 'memories',
    description: 'configure memory use and generation',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.agentFallback,
    mappingTarget: 'server memory configuration',
    phase: SlashCommandPhase.thirdStage,
    riskLevel: SlashCommandRiskLevel.medium,
  ),
  SlashCommandSpec(
    command: 'skills',
    description: 'use skills to improve how Codex performs specific tasks',
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'skills/list + skill detail',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'import',
    description:
        'import setup, this project, and recent chats from Claude Code',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.agentFallback,
    mappingTarget: 'Claude Code import flow',
    phase: SlashCommandPhase.thirdStage,
    riskLevel: SlashCommandRiskLevel.medium,
  ),
  SlashCommandSpec(
    command: 'hooks',
    description: 'view and manage lifecycle hooks',
    mappingType: SlashCommandMappingType.agentFallback,
    mappingTarget: 'hooks list/read/update',
    phase: SlashCommandPhase.secondStage,
    riskLevel: SlashCommandRiskLevel.medium,
  ),
  SlashCommandSpec(
    command: 'review',
    description: 'review my current changes and find issues',
    supportsInlineArgs: true,
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'review/start',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'rename',
    description: 'rename the current thread',
    supportsInlineArgs: true,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'thread/name/set',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'new',
    description: 'start a new chat during a conversation',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'thread/start',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'archive',
    description: 'archive this session and exit',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'thread/archive',
    phase: SlashCommandPhase.mvp,
    riskLevel: SlashCommandRiskLevel.medium,
  ),
  SlashCommandSpec(
    command: 'delete',
    description: 'permanently delete this session and exit',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'thread/delete with confirmation',
    phase: SlashCommandPhase.mvp,
    riskLevel: SlashCommandRiskLevel.high,
  ),
  SlashCommandSpec(
    command: 'resume',
    description: 'resume a saved chat',
    supportsInlineArgs: true,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'thread/list + thread/resume',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'fork',
    description: 'fork the current chat',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'thread/fork',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'app',
    description: 'continue this session in Codex Desktop',
    platformVisibility: SlashPlatformVisibility.desktopOnly,
    mappingType: SlashCommandMappingType.notApplicable,
    mappingTarget: 'Codex Desktop handoff unavailable on mobile',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'init',
    description: 'create an AGENTS.md file with instructions for Codex',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.agentFallback,
    mappingTarget: 'AGENTS.md generation with diff approval',
    phase: SlashCommandPhase.thirdStage,
    riskLevel: SlashCommandRiskLevel.medium,
  ),
  SlashCommandSpec(
    command: 'compact',
    description: 'summarize conversation to prevent hitting the context limit',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'thread/compact/start',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'plan',
    description: 'switch to Plan mode',
    supportsInlineArgs: true,
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'collaboration mode override',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'goal',
    description: 'set or view the goal for a long-running task',
    supportsInlineArgs: true,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'thread/goal/*',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'agent',
    description: 'switch the active agent thread',
    mappingType: SlashCommandMappingType.topology,
    mappingTarget: 'multi-agent thread picker',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'side',
    description: 'start a side conversation in an ephemeral fork',
    supportsInlineArgs: true,
    mappingType: SlashCommandMappingType.topology,
    mappingTarget: 'thread/fork ephemeral=true + side boundary prompt',
    phase: SlashCommandPhase.secondStageExperimental,
  ),
  SlashCommandSpec(
    command: 'btw',
    description: 'start a side conversation in an ephemeral fork',
    supportsInlineArgs: true,
    mappingType: SlashCommandMappingType.topology,
    mappingTarget: 'thread/fork ephemeral=true + btw boundary prompt',
    phase: SlashCommandPhase.secondStageExperimental,
  ),
  SlashCommandSpec(
    command: 'copy',
    description: 'copy last response as markdown',
    availableInSideConversation: true,
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'local clipboard markdown copy',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'raw',
    description:
        'toggle raw scrollback mode for copy-friendly terminal selection',
    supportsInlineArgs: true,
    availableInSideConversation: true,
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'raw event/transcript view',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'diff',
    description: 'show git diff (including untracked files)',
    availableInSideConversation: true,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'diff/file change read or git diff fallback',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'mention',
    description: 'mention a file',
    availableInSideConversation: true,
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'file picker attachment/context injection',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'status',
    description: 'show current session configuration and token usage',
    availableInSideConversation: true,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'thread/read + config/account/model status',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'usage',
    description: 'view account usage or use a usage limit reset',
    supportsInlineArgs: true,
    availableInSideConversation: true,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'account/usage/read',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'debug-config',
    description: 'show config layers and requirement sources for debugging',
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'config/read debug layers',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'title',
    description: 'configure which items appear in the terminal title',
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'mobile title display settings',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'statusline',
    description: 'configure which items appear in the status line',
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'mobile status bar display settings',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'theme',
    description: 'choose a syntax highlighting theme',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'mobile theme settings',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'pets',
    aliases: ['pet'],
    description: 'choose or hide the terminal pet',
    supportsInlineArgs: true,
    availableDuringTask: false,
    platformVisibility: SlashPlatformVisibility.tuiOnly,
    mappingType: SlashCommandMappingType.notApplicable,
    mappingTarget: 'terminal TUI-only visual feature',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'mcp',
    description: 'list configured MCP tools; use /mcp verbose for details',
    supportsInlineArgs: true,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'mcpServerStatus/list + verbose detail',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'apps',
    description: 'manage apps',
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'apps/* or agent fallback',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'plugins',
    description: 'browse plugins',
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'plugin/* + marketplace/*',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'logout',
    description: 'log out of Codex',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'account/logout with confirmation',
    phase: SlashCommandPhase.secondStage,
    riskLevel: SlashCommandRiskLevel.high,
  ),
  SlashCommandSpec(
    command: 'quit',
    description: 'exit Codex',
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'close mobile session/proxy connection only',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'exit',
    description: 'exit Codex',
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'close mobile session/proxy connection only',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'feedback',
    description: 'send logs to maintainers',
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'feedback/upload or agent fallback',
    phase: SlashCommandPhase.thirdStage,
    riskLevel: SlashCommandRiskLevel.medium,
  ),
  SlashCommandSpec(
    command: 'rollout',
    description: 'print the rollout file path',
    platformVisibility: SlashPlatformVisibility.debugOnly,
    mappingType: SlashCommandMappingType.debug,
    mappingTarget: 'diagnostic rollout path display',
    phase: SlashCommandPhase.advancedDebug,
  ),
  SlashCommandSpec(
    command: 'ps',
    description: 'list background terminals',
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'background terminal/process list',
    phase: SlashCommandPhase.secondStage,
  ),
  SlashCommandSpec(
    command: 'stop',
    aliases: ['clean'],
    description: 'stop all background terminals',
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'background terminal/process stop; never turn/interrupt',
    phase: SlashCommandPhase.secondStage,
    riskLevel: SlashCommandRiskLevel.medium,
  ),
  SlashCommandSpec(
    command: 'clear',
    description: 'clear the terminal and start a new chat',
    availableDuringTask: false,
    mappingType: SlashCommandMappingType.uiOnly,
    mappingTarget: 'clear mobile transcript view and start new thread',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'personality',
    description: 'choose a communication style for Codex',
    mappingType: SlashCommandMappingType.appServer,
    mappingTarget: 'config/personality override',
    phase: SlashCommandPhase.mvp,
  ),
  SlashCommandSpec(
    command: 'test-approval',
    description: 'test approval request',
    platformVisibility: SlashPlatformVisibility.debugOnly,
    mappingType: SlashCommandMappingType.debug,
    mappingTarget: 'approval pipeline test',
    phase: SlashCommandPhase.advancedDebug,
  ),
  SlashCommandSpec(
    command: 'subagents',
    description: 'switch the active agent thread',
    mappingType: SlashCommandMappingType.topology,
    mappingTarget: 'subagent thread tree read-only browser',
    phase: SlashCommandPhase.thirdStage,
  ),
  SlashCommandSpec(
    command: 'debug-m-drop',
    description: 'DO NOT USE',
    availableDuringTask: false,
    platformVisibility: SlashPlatformVisibility.debugOnly,
    mappingType: SlashCommandMappingType.debug,
    mappingTarget: 'memory debug drop',
    phase: SlashCommandPhase.advancedDebug,
    riskLevel: SlashCommandRiskLevel.high,
  ),
  SlashCommandSpec(
    command: 'debug-m-update',
    description: 'DO NOT USE',
    availableDuringTask: false,
    platformVisibility: SlashPlatformVisibility.debugOnly,
    mappingType: SlashCommandMappingType.debug,
    mappingTarget: 'memory debug update',
    phase: SlashCommandPhase.advancedDebug,
    riskLevel: SlashCommandRiskLevel.high,
  ),
];

String _normalizeCommand(String value) {
  final trimmed = value.trim().toLowerCase();
  return trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Missing required string field: $key');
}

List<String> _stringList(Object? value) {
  if (value == null) {
    return const [];
  }
  if (value is! List<Object?>) {
    throw const FormatException('Expected a string list.');
  }
  return [for (final item in value) item as String];
}

T _enumByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  throw FormatException('Unknown enum value: $name');
}
