import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/plugins/codex_plugin_detail_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_detail_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('PluginDetail parses nested plugin/read payloads', () {
    final detail = PluginDetail.fromJson(
      pluginId: 'linear',
      json: {
        'marketplace_name': 'openai-curated',
        'marketplace_path': '/marketplace/plugins.json',
        'readme_markdown': '# Linear\nPlan work.',
        'plugin': {
          'id': 'linear',
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
    );

    expect(detail.plugin.id, 'linear');
    expect(detail.plugin.remotePluginId, 'remote-linear');
    expect(detail.plugin.displayName, 'Linear');
    expect(detail.plugin.localVersion, '1.2.0');
    expect(detail.plugin.description, 'Plan work');
    expect(detail.marketplaceName, 'openai-curated');
    expect(detail.marketplacePath, '/marketplace/plugins.json');
    expect(detail.readme, '# Linear\nPlan work.');
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
            'id': 'linear',
            'name': 'linear',
            'source': {'type': 'remote'},
          },
        };
      }),
    );
    final reader = CodexPluginDetailReader(client);

    final detail = await reader.readPlugin(
      pluginId: ' linear ',
      cwds: [' /repo ', ' '],
    );

    expect(detail.plugin.id, 'linear');
    expect(requests.single.method, 'plugin/read');
    expect(requests.single.params, {
      'pluginId': 'linear',
      'cwds': ['/repo'],
    });
  });
}
