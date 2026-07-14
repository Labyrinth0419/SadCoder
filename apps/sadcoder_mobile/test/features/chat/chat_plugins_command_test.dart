import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_plugins_command.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_list_reader.dart';

void main() {
  group('parseChatPluginsCommand', () {
    test('parses empty arguments as an unfiltered list command', () {
      final command = parseChatPluginsCommand('');

      expect(command, isA<ChatPluginsListCommand>());
      expect((command as ChatPluginsListCommand).marketplaceKinds, isEmpty);
    });

    test('parses read command aliases with the original plugin id', () {
      for (final verb in const ['read', 'show', 'detail']) {
        final command = parseChatPluginsCommand('$verb Plugin.ID');

        expect(command, isA<ChatPluginsReadCommand>());
        expect((command as ChatPluginsReadCommand).pluginId, 'Plugin.ID');
      }
    });

    test('parses install and uninstall command aliases', () {
      final install = parseChatPluginsCommand('install plugin-a');
      expect(install, isA<ChatPluginsInstallCommand>());
      expect((install as ChatPluginsInstallCommand).pluginId, 'plugin-a');

      for (final verb in const ['uninstall', 'remove']) {
        final uninstall = parseChatPluginsCommand('$verb plugin-b');
        expect(uninstall, isA<ChatPluginsUninstallCommand>());
        expect((uninstall as ChatPluginsUninstallCommand).pluginId, 'plugin-b');
      }
    });

    test('parses remote plugin skill read commands', () {
      for (final verb in const ['skill', 'read-skill']) {
        final command = parseChatPluginsCommand(
          '$verb reviewer@openai-curated review',
        );

        expect(command, isA<ChatPluginsSkillReadCommand>());
        final read = command as ChatPluginsSkillReadCommand;
        expect(read.pluginId, 'reviewer@openai-curated');
        expect(read.skillName, 'review');
      }
    });

    test('parses marketplace add with ref and repeated sparse paths', () {
      final command = parseChatPluginsCommand(
        'marketplace add https://example.com/tools.git '
        '--ref main --sparse plugins --sparse=skills',
      );

      expect(command, isA<ChatMarketplaceAddCommand>());
      final add = command as ChatMarketplaceAddCommand;
      expect(add.source, 'https://example.com/tools.git');
      expect(add.refName, 'main');
      expect(add.sparsePaths, ['plugins', 'skills']);
    });

    test('parses marketplace add equals-form ref', () {
      final command = parseChatPluginsCommand(
        'marketplaces add team-tools --ref=release',
      );

      expect(command, isA<ChatMarketplaceAddCommand>());
      expect((command as ChatMarketplaceAddCommand).refName, 'release');
      expect(command.sparsePaths, isEmpty);
    });

    test('parses marketplace remove and named or all upgrades', () {
      final remove = parseChatPluginsCommand('marketplace remove team-tools');
      expect(remove, isA<ChatMarketplaceRemoveCommand>());
      expect(
        (remove as ChatMarketplaceRemoveCommand).marketplaceName,
        'team-tools',
      );

      final named = parseChatPluginsCommand('marketplace upgrade team-tools');
      expect(named, isA<ChatMarketplaceUpgradeCommand>());
      expect(
        (named as ChatMarketplaceUpgradeCommand).marketplaceName,
        'team-tools',
      );

      final all = parseChatPluginsCommand('marketplace upgrade');
      expect(all, isA<ChatMarketplaceUpgradeCommand>());
      expect((all as ChatMarketplaceUpgradeCommand).marketplaceName, isNull);
    });

    test('parses marketplace kind filters', () {
      expect(
        (parseChatPluginsCommand('local') as ChatPluginsListCommand)
            .marketplaceKinds,
        [PluginMarketplaceKind.local],
      );
      expect(
        (parseChatPluginsCommand('marketplace workspace-directory')
                as ChatPluginsListCommand)
            .marketplaceKinds,
        [PluginMarketplaceKind.workspaceDirectory],
      );
      expect(
        (parseChatPluginsCommand('marketplaces shared_with_me')
                as ChatPluginsListCommand)
            .marketplaceKinds,
        [PluginMarketplaceKind.sharedWithMe],
      );
      expect(
        (parseChatPluginsCommand('created-by-me-remote')
                as ChatPluginsListCommand)
            .marketplaceKinds,
        [PluginMarketplaceKind.createdByMeRemote],
      );
    });

    test('gives action commands precedence over marketplace filter names', () {
      final command = parseChatPluginsCommand('read local');

      expect(command, isA<ChatPluginsReadCommand>());
      expect((command as ChatPluginsReadCommand).pluginId, 'local');
    });

    test('rejects unsupported arguments', () {
      expect(parseChatPluginsCommand('marketplace nowhere'), isNull);
      expect(parseChatPluginsCommand('local extra'), isNull);
      expect(parseChatPluginsCommand('install'), isNull);
      expect(parseChatPluginsCommand('read plugin extra'), isNull);
      expect(parseChatPluginsCommand('skill plugin'), isNull);
      expect(parseChatPluginsCommand('skill plugin skill extra'), isNull);
    });

    test('rejects malformed marketplace mutations', () {
      for (final arguments in const [
        'marketplace add',
        'marketplace add --ref main',
        'marketplace add source --ref',
        'marketplace add source --ref --sparse plugins',
        'marketplace add source --ref=main --ref release',
        'marketplace add source --sparse',
        'marketplace add source --sparse --ref main',
        'marketplace add source --unknown value',
        'marketplace remove',
        'marketplace remove --all',
        'marketplace upgrade --all',
        'marketplace upgrade one two',
      ]) {
        expect(parseChatPluginsCommand(arguments), isNull, reason: arguments);
      }
    });
  });
}
