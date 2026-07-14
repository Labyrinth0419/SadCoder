import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/plugins/codex_plugin_skill_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test(
    'readSkill calls stable plugin/skill/read and preserves contents',
    () async {
      final requests = <JsonRpcRequest>[];
      final reader = CodexPluginSkillReader(
        CodexAppServerClient(
          MemoryJsonRpcTransport((request) {
            requests.add(request);
            return {'contents': '# Review\n\n  Keep spacing.\n'};
          }),
        ),
      );
      final target = _remoteTarget();

      final document = await reader.readSkill(
        target: target,
        skillName: ' review ',
      );

      expect(document.pluginId, 'reviewer@openai-curated-remote');
      expect(document.skillName, 'review');
      expect(document.contents, '# Review\n\n  Keep spacing.\n');
      expect(requests.single.method, 'plugin/skill/read');
      expect(requests.single.params, {
        'remoteMarketplaceName': 'openai-curated-remote',
        'remotePluginId': 'plugins~reviewer',
        'skillName': 'review',
      });
    },
  );

  test('readSkill rejects local marketplace targets without sending RPC', () {
    final requests = <JsonRpcRequest>[];
    final reader = CodexPluginSkillReader(
      CodexAppServerClient(
        MemoryJsonRpcTransport((request) {
          requests.add(request);
          return const <String, Object?>{};
        }),
      ),
    );
    final target = PluginListPage.fromJson({
      'marketplaces': [
        {
          'name': 'repo-tools',
          'path': '/repo/.agents/plugins/marketplace.json',
          'plugins': [
            {
              'id': 'reviewer@repo-tools',
              'name': 'reviewer',
              'source': {'type': 'local', 'path': '/repo/plugins/reviewer'},
            },
          ],
        },
      ],
    }).resolveTarget('reviewer');

    expect(
      () => reader.readSkill(target: target, skillName: 'review'),
      throwsStateError,
    );
    expect(requests, isEmpty);
  });
}

PluginCatalogTarget _remoteTarget() {
  return PluginListPage.fromJson({
    'marketplaces': [
      {
        'name': 'openai-curated-remote',
        'plugins': [
          {
            'id': 'reviewer@openai-curated-remote',
            'remotePluginId': 'plugins~reviewer',
            'name': 'reviewer',
            'source': {'type': 'remote'},
          },
        ],
      },
    ],
  }).resolveTarget('reviewer');
}
