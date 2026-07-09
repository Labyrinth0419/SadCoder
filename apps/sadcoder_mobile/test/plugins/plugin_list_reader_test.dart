import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/plugins/codex_plugin_list_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('PluginListPage parses marketplace and plugin payloads', () {
    final page = PluginListPage.fromJson({
      'marketplaces': [
        {
          'name': 'openai-curated',
          'path': '/home/me/.codex/plugins/marketplace.json',
          'interface': {'displayName': 'OpenAI curated'},
          'plugins': [
            {
              'id': 'linear',
              'remotePluginId': 'remote-linear',
              'version': '1.2.3',
              'localVersion': '1.2.0',
              'name': 'linear',
              'source': {'type': 'git', 'url': 'https://example.com/linear'},
              'installed': true,
              'enabled': false,
              'installPolicy': 'AVAILABLE',
              'authPolicy': 'ON_USE',
              'availability': 'AVAILABLE',
              'interface': {
                'displayName': 'Linear',
                'shortDescription': 'Plan work',
                'developerName': 'OpenAI',
                'category': 'Project management',
                'capabilities': ['mcp', 'skills'],
                'websiteUrl': 'https://linear.app',
              },
              'keywords': ['issues'],
            },
            {'id': 'missing-name'},
          ],
        },
      ],
      'marketplaceLoadErrors': [
        {
          'marketplacePath': '/bad/marketplace.json',
          'message': 'invalid marketplace',
        },
      ],
      'featuredPluginIds': ['linear'],
    });

    expect(page.marketplaces, hasLength(1));
    expect(page.marketplaceLoadErrors.single.message, 'invalid marketplace');
    expect(page.featuredPluginIds, ['linear']);

    final marketplace = page.marketplaces.single;
    expect(marketplace.displayName, 'OpenAI curated');
    expect(marketplace.plugins, hasLength(1));

    final plugin = marketplace.plugins.single;
    expect(plugin.id, 'linear');
    expect(plugin.displayName, 'Linear');
    expect(plugin.description, 'Plan work');
    expect(plugin.source.type, 'git');
    expect(plugin.source.detail, 'https://example.com/linear');
    expect(plugin.installed, true);
    expect(plugin.enabled, false);
    expect(plugin.interface?.capabilities, ['mcp', 'skills']);
  });

  test('CodexPluginListReader calls app-server plugin/list', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'marketplaces': [
          {
            'name': 'local',
            'plugins': [
              {
                'id': 'doc',
                'name': 'doc',
                'source': {'type': 'local', 'path': '/plugins/doc'},
                'installed': true,
                'enabled': true,
                'installPolicy': 'AVAILABLE',
                'authPolicy': 'ON_USE',
              },
            ],
          },
        ],
      };
    });
    final reader = CodexPluginListReader(CodexAppServerClient(transport));

    final page = await reader.listPlugins(
      cwds: [' /repo ', ' '],
      marketplaceKinds: const [PluginMarketplaceKind.workspaceDirectory],
    );

    expect(page.marketplaces.single.plugins.single.name, 'doc');
    expect(requests.single.method, 'plugin/list');
    expect(requests.single.params, {
      'cwds': ['/repo'],
      'marketplaceKinds': ['workspace-directory'],
    });
  });
}
