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
    });
  });
}
