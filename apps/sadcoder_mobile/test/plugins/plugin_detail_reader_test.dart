import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/plugins/codex_plugin_detail_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_detail_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('PluginDetail parses stable nested plugin/read payloads', () {
    final detail = PluginDetail.fromJson(
      pluginId: 'linear@openai-curated',
      json: {
        'plugin': {
          'marketplace_name': 'openai-curated',
          'marketplace_path': '/marketplace/plugins.json',
          'description': 'Longer Linear description',
          'summary': {
            'id': 'linear@openai-curated',
            'remote_plugin_id': 'remote-linear',
            'name': 'linear',
            'version': '1.2.3',
            'local_version': '1.2.0',
            'source': {'type': 'remote'},
            'installed': true,
            'enabled': true,
            'install_policy': 'AVAILABLE',
            'auth_policy': 'ON_USE',
            'availability': 'AVAILABLE',
            'interface': {
              'display_name': 'Linear',
              'short_description': 'Plan work',
              'capabilities': ['mcp', 'skills'],
            },
          },
        },
      },
    );

    expect(detail.plugin.id, 'linear@openai-curated');
    expect(detail.plugin.remotePluginId, 'remote-linear');
    expect(detail.plugin.displayName, 'Linear');
    expect(detail.plugin.localVersion, '1.2.0');
    expect(detail.plugin.description, 'Plan work');
    expect(detail.marketplaceName, 'openai-curated');
    expect(detail.marketplacePath, '/marketplace/plugins.json');
    expect(detail.description, 'Longer Linear description');
  });

  test('PluginDetail parses top-level plugin fields', () {
    final detail = PluginDetail.fromJson(
      pluginId: 'local-plugin',
      json: {
        'id': 'local-plugin',
        'name': 'local-plugin',
        'source': {'type': 'local', 'path': '/repo/.codex-plugin'},
        'installed': false,
        'enabled': false,
      },
    );

    expect(detail.plugin.id, 'local-plugin');
    expect(detail.plugin.source.detail, '/repo/.codex-plugin');
  });

  test('CodexPluginDetailReader calls plugin/read', () async {
    final requests = <JsonRpcRequest>[];
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {
          'plugin': {
            'marketplaceName': 'openai-curated-remote',
            'summary': {
              'id': 'linear@openai-curated-remote',
              'remotePluginId': 'plugins~linear',
              'name': 'linear',
              'source': {'type': 'remote'},
            },
          },
        };
      }),
    );
    final reader = CodexPluginDetailReader(client);

    final target = PluginListPage.fromJson({
      'marketplaces': [
        {
          'name': 'openai-curated-remote',
          'plugins': [
            {
              'id': 'linear@openai-curated-remote',
              'remotePluginId': 'plugins~linear',
              'name': 'linear',
              'source': {'type': 'remote'},
            },
          ],
        },
      ],
    }).resolveTarget('linear');
    final detail = await reader.readPlugin(target: target);

    expect(detail.plugin.id, 'linear@openai-curated-remote');
    expect(requests.single.method, 'plugin/read');
    expect(requests.single.params, {
      'remoteMarketplaceName': 'openai-curated-remote',
      'pluginName': 'plugins~linear',
    });
  });
}
