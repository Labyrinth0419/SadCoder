import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_registry.dart';

void main() {
  const registry = SlashCommandRegistry();

  test('built-in registry covers Codex TUI slash commands in source order', () {
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
