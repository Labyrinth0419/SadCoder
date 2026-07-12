import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_registry.dart';

void main() {
  const registry = SlashCommandRegistry();

  test('built-in registry keeps its presentation order explicit', () {
    expect(builtInSlashCommands.map((command) => command.command), [
      'model',
      'ide',
      'permissions',
      'keymap',
      'vim',
      'setup-default-sandbox',
      'sandbox-add-read-dir',
      'experimental',
      'approve',
      'memories',
      'skills',
      'import',
      'hooks',
      'review',
      'rename',
      'new',
      'archive',
      'delete',
      'resume',
      'fork',
      'duplicate',
      'rewind',
      'app',
      'init',
      'compact',
      'plan',
      'goal',
      'agent',
      'side',
      'btw',
      'copy',
      'raw',
      'diff',
      'mention',
      'status',
      'usage',
      'debug-config',
      'title',
      'statusline',
      'theme',
      'pets',
      'mcp',
      'apps',
      'plugins',
      'logout',
      'quit',
      'exit',
      'feedback',
      'rollout',
      'ps',
      'stop',
      'clear',
      'personality',
      'test-approval',
      'subagents',
      'debug-m-drop',
      'debug-m-update',
    ]);
  });

  test('built-in registry covers checked-out Codex TUI slash source', () {
    final sourceFile = File(
      '../../refs/codex/codex-rs/tui/src/slash_command.rs',
    );
    if (!sourceFile.existsSync()) {
      return;
    }

    final source = sourceFile.readAsStringSync();
    final codexCommands = _parseCodexSlashCommands(source);
    final builtInCommands = builtInSlashCommands
        .map((command) => command.command)
        .toList(growable: false);
    final builtInByName = {
      for (final command in builtInSlashCommands) command.command: command,
    };
    final codexCommandNames = codexCommands
        .map((command) => command.command)
        .toSet();

    expect(
      [
        for (final command in codexCommands)
          if (!builtInByName.containsKey(command.command)) command.command,
      ],
      isEmpty,
      reason: 'SadCoder slash manifest is missing commands from refs/codex.',
    );

    var searchStart = 0;
    for (final command in codexCommands) {
      final index = builtInCommands.indexOf(command.command, searchStart);
      expect(
        index,
        isNot(-1),
        reason:
            'SadCoder slash manifest moved /${command.command} before its '
            'Codex source-order predecessor.',
      );
      searchStart = index + 1;
    }

    for (final command in codexCommands) {
      final actual = builtInByName[command.command]!;
      expect(
        actual.aliases,
        containsAll(command.aliases),
        reason:
            'SadCoder slash manifest is missing aliases for /${command.command}.',
      );
    }

    expect(
      builtInSlashCommands
          .where((command) => command.supportsInlineArgs)
          .map((command) => command.command)
          .toSet(),
      _withSadCoderExtensions(
        _commandNamesForVariants(
          codexCommands,
          _parseCodexMatchesFunction(source, 'supports_inline_args'),
        ),
        _sadCoderInlineArgsExtensions,
      ),
      reason:
          'SadCoder slash manifest inline-argument flags drifted from refs/codex.',
    );

    expect(
      builtInSlashCommands
          .where((command) => command.availableInSideConversation)
          .map((command) => command.command)
          .toSet(),
      _commandNamesForVariants(
        codexCommands,
        _parseCodexMatchesFunction(source, 'available_in_side_conversation'),
      ),
      reason:
          'SadCoder slash manifest side-conversation flags drifted from refs/codex.',
    );

    expect(
      builtInSlashCommands
          .where((command) => !command.availableDuringTask)
          .map((command) => command.command)
          .toSet(),
      _withSadCoderExtensions(
        _commandNamesForVariants(
          codexCommands,
          _parseCodexAvailableDuringTaskFalseVariants(source),
        ),
        _sadCoderActiveTaskDisabledExtensions,
      ),
      reason:
          'SadCoder slash manifest active-task availability drifted from refs/codex.',
    );

    expect(
      [
        for (final command in builtInCommands)
          if (!codexCommandNames.contains(command) &&
              !_sadCoderSlashCommandExtensions.contains(command))
            command,
      ],
      isEmpty,
      reason:
          'SadCoder slash manifest has extra commands not present in refs/codex. '
          'Add intentional extensions to _sadCoderSlashCommandExtensions.',
    );
  });

  test('built-in registry matches the shared manifest', () {
    final manifest =
        jsonDecode(
              File(
                '../../resources/slash_commands_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final parsed = SlashCommandManifest.fromJson(manifest);
    final commands = manifest['commands'] as List<Object?>;

    expect(manifest['source'], slashCommandManifestSource);
    expect(parsed.schemaVersion, 1);
    expect(parsed.asRegistry().find('/clean')?.command, 'stop');
    expect(commands, hasLength(builtInSlashCommands.length));

    for (var i = 0; i < commands.length; i++) {
      final json = commands[i] as Map<String, Object?>;
      final command = builtInSlashCommands[i];

      expect(json['command'], command.command);
      expect(json['aliases'], command.aliases);
      expect(json['description'], command.description);
      expect(json['supportsInlineArgs'], command.supportsInlineArgs);
      expect(json['availableDuringTask'], command.availableDuringTask);
      expect(
        json['availableInSideConversation'],
        command.availableInSideConversation,
      );
      expect(json['platformVisibility'], command.platformVisibility.name);
      expect(json['mappingType'], command.mappingType.name);
      expect(json['mappingTarget'], command.mappingTarget);
      expect(json['phase'], command.phase.name);
      expect(json['riskLevel'], command.riskLevel.name);
    }
  });

  test('aliases resolve to canonical commands', () {
    expect(registry.find('/clean')?.command, 'stop');
    expect(registry.find('pet')?.command, 'pets');
    expect(registry.find('/approve')?.command, 'approve');
    expect(registry.find('/subagents')?.command, 'subagents');
  });

  test('quit commands describe mobile disconnection only', () {
    for (final slash in ['/quit', '/exit']) {
      final command = registry.find(slash);

      expect(command?.description, contains('mobile session/proxy'));
      expect(command?.description.toLowerCase(), isNot(contains('codex')));
      expect(
        command?.mappingTarget,
        'close mobile session/proxy connection only',
      );
    }
  });

  test('inline args match current Codex TUI contract', () {
    final inlineArgs = builtInSlashCommands
        .where((command) => command.supportsInlineArgs)
        .map((command) => command.command);

    expect(inlineArgs, [
      'ide',
      'keymap',
      'sandbox-add-read-dir',
      'review',
      'rename',
      'resume',
      'rewind',
      'plan',
      'goal',
      'side',
      'btw',
      'raw',
      'usage',
      'pets',
      'mcp',
      'plugins',
    ]);
  });

  test('active task disabled commands match current Codex TUI contract', () {
    final disabled = builtInSlashCommands
        .where((command) => !command.availableDuringTask)
        .map((command) => command.command);

    expect(disabled, [
      'keymap',
      'vim',
      'setup-default-sandbox',
      'sandbox-add-read-dir',
      'experimental',
      'memories',
      'import',
      'review',
      'new',
      'archive',
      'delete',
      'fork',
      'duplicate',
      'rewind',
      'init',
      'compact',
      'plan',
      'theme',
      'pets',
      'logout',
      'clear',
      'debug-m-drop',
      'debug-m-update',
    ]);
  });

  test('side conversation availability is explicitly modeled', () {
    final sideAvailable = builtInSlashCommands
        .where((command) => command.availableInSideConversation)
        .map((command) => command.command);

    expect(sideAvailable, [
      'ide',
      'copy',
      'raw',
      'diff',
      'mention',
      'status',
      'usage',
    ]);
  });

  test('parser never silently treats unknown slash commands as prompts', () {
    expect(registry.parseComposerText('write tests').shouldSendAsPrompt, true);

    final known = registry.parseComposerText('/clean now');
    expect(known.kind, SlashCommandParseKind.known);
    expect(known.command?.command, 'stop');
    expect(known.rawCommand, 'clean');
    expect(known.arguments, 'now');
    expect(known.shouldSendAsPrompt, false);

    final unknown = registry.parseComposerText('/does-not-exist now');
    expect(unknown.kind, SlashCommandParseKind.unknown);
    expect(unknown.rawCommand, 'does-not-exist');
    expect(unknown.arguments, 'now');
    expect(unknown.shouldSendAsPrompt, false);
  });
}

const _sadCoderSlashCommandExtensions = {'duplicate', 'rewind'};
const _sadCoderInlineArgsExtensions = {'plugins', 'rewind'};
const _sadCoderActiveTaskDisabledExtensions = {'duplicate', 'rewind'};

List<_CodexSlashCommand> _parseCodexSlashCommands(String source) {
  final enumMatch = RegExp(
    r'pub enum SlashCommand \{([\s\S]*?)\n\}',
  ).firstMatch(source);
  if (enumMatch == null) {
    throw const FormatException('Codex SlashCommand enum was not found');
  }

  final commands = <_CodexSlashCommand>[];
  final attributes = <String>[];
  for (final rawLine in enumMatch.group(1)!.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('//')) {
      continue;
    }
    if (line.startsWith('#[strum(')) {
      attributes.add(line);
      continue;
    }

    final variant = RegExp(
      r'^([A-Za-z][A-Za-z0-9]*),',
    ).firstMatch(line)?.group(1);
    if (variant == null) {
      continue;
    }

    final attributeText = attributes.join(' ');
    final toString = RegExp(
      r'to_string\s*=\s*"([^"]+)"',
    ).firstMatch(attributeText)?.group(1);
    final serializes = [
      for (final match in RegExp(
        r'serialize\s*=\s*"([^"]+)"',
      ).allMatches(attributeText))
        match.group(1)!,
    ];
    final command =
        toString ??
        (serializes.isNotEmpty ? serializes.first : _kebabCase(variant));
    commands.add(
      _CodexSlashCommand(variant, command, [
        for (final alias in serializes)
          if (alias != command) alias,
      ]),
    );
    attributes.clear();
  }
  return commands;
}

Set<String> _parseCodexMatchesFunction(String source, String methodName) {
  final match = RegExp(
    'pub fn $methodName\\(self\\)[\\s\\S]*?matches!\\(\\s*self,([\\s\\S]*?)\\n\\s*\\)',
  ).firstMatch(source);
  if (match == null) {
    throw FormatException(
      'Codex SlashCommand method was not found: $methodName',
    );
  }
  return _variantNames(match.group(1)!);
}

Set<String> _parseCodexAvailableDuringTaskFalseVariants(String source) {
  final match = RegExp(
    r'pub fn available_during_task\(self\)[\s\S]*?match self \{([\s\S]*?)\n\s*\}',
  ).firstMatch(source);
  if (match == null) {
    throw const FormatException(
      'Codex SlashCommand available_during_task method was not found',
    );
  }

  final falseVariants = <String>{};
  final arm = StringBuffer();
  for (final rawLine in match.group(1)!.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    arm.writeln(line);
    if (!line.contains('=>')) {
      continue;
    }
    final armText = arm.toString();
    if (armText.contains('=> false')) {
      falseVariants.addAll(_variantNames(armText));
    }
    arm.clear();
  }
  return falseVariants;
}

Set<String> _variantNames(String source) {
  return {
    for (final match in RegExp(
      r'SlashCommand::([A-Za-z][A-Za-z0-9]*)',
    ).allMatches(source))
      match.group(1)!,
  };
}

Set<String> _commandNamesForVariants(
  List<_CodexSlashCommand> commands,
  Set<String> variants,
) {
  final byVariant = {
    for (final command in commands) command.variant: command.command,
  };
  return {
    for (final variant in variants)
      if (byVariant[variant] != null) byVariant[variant]!,
  };
}

Set<String> _withSadCoderExtensions(
  Set<String> codexCommands,
  Set<String> sadCoderExtensions,
) {
  return {...codexCommands, ...sadCoderExtensions};
}

String _kebabCase(String value) {
  final buffer = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final char = value[i];
    final lower = char.toLowerCase();
    if (i > 0 && char != lower) {
      buffer.write('-');
    }
    buffer.write(lower);
  }
  return buffer.toString();
}

class _CodexSlashCommand {
  const _CodexSlashCommand(this.variant, this.command, this.aliases);

  final String variant;
  final String command;
  final List<String> aliases;
}
