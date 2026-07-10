import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/apps/app_list_reader.dart';
import 'package:sadcoder_mobile/src/apps/codex_app_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('AppListPage parses app metadata payloads', () {
    final page = AppListPage.fromJson({
      'data': [
        {
          'id': 'linear',
          'name': 'Linear',
          'description': 'Plan work',
          'installUrl': 'https://linear.app/install',
          'distributionChannel': 'marketplace',
          'branding': {
            'category': 'Project management',
            'developer': 'Linear',
            'website': 'https://linear.app',
            'isDiscoverableApp': true,
          },
          'appMetadata': {
            'review': {'status': 'approved'},
            'categories': ['Productivity'],
            'developer': 'Linear Inc',
            'version': '1.2.3',
          },
          'isAccessible': true,
          'isEnabled': false,
          'pluginDisplayNames': ['Linear plugin'],
        },
        {'name': 'missing id'},
      ],
      'nextCursor': 'next-page',
    });

    expect(page.apps, hasLength(1));
    expect(page.nextCursor, 'next-page');

    final app = page.apps.single;
    expect(app.id, 'linear');
    expect(app.name, 'Linear');
    expect(app.description, 'Plan work');
    expect(app.installUrl, 'https://linear.app/install');
    expect(app.distributionChannel, 'marketplace');
    expect(app.category, 'Project management');
    expect(app.developer, 'Linear');
    expect(app.website, 'https://linear.app');
    expect(app.version, '1.2.3');
    expect(app.reviewStatus, 'approved');
    expect(app.isAccessible, true);
    expect(app.isEnabled, false);
    expect(app.pluginDisplayNames, ['Linear plugin']);
  });

  test('AppListPage parses snake_case app metadata fields', () {
    final page = AppListPage.fromJson({
      'data': [
        {
          'id': 'github',
          'name': 'GitHub',
          'description': 'Review pull requests',
          'install_url': 'https://github.com/install',
          'distribution_channel': 'workspace',
          'branding': {
            'category': 'Code review',
            'developer': 'GitHub',
            'website': 'https://github.com',
          },
          'app_metadata': {
            'review': {'status': 'pending'},
            'categories': ['Developer tools'],
            'developer': 'GitHub Inc',
            'version': '2.3.4',
          },
          'is_accessible': false,
          'is_enabled': true,
          'plugin_display_names': ['GitHub plugin'],
        },
      ],
      'next_cursor': 'next-snake-page',
    });

    expect(page.nextCursor, 'next-snake-page');
    final app = page.apps.single;
    expect(app.id, 'github');
    expect(app.installUrl, 'https://github.com/install');
    expect(app.distributionChannel, 'workspace');
    expect(app.category, 'Code review');
    expect(app.developer, 'GitHub');
    expect(app.website, 'https://github.com');
    expect(app.version, '2.3.4');
    expect(app.reviewStatus, 'pending');
    expect(app.isAccessible, false);
    expect(app.isEnabled, true);
    expect(app.pluginDisplayNames, ['GitHub plugin']);
  });

  test('CodexAppListReader calls app-server app/list', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'data': [
          {
            'id': 'docs',
            'name': 'Docs',
            'isAccessible': false,
            'isEnabled': true,
          },
        ],
      };
    });
    final reader = CodexAppListReader(CodexAppServerClient(transport));

    final page = await reader.listApps(
      cursor: ' cursor ',
      limit: 25,
      threadId: ' thr_1 ',
      forceRefetch: true,
    );

    expect(page.apps.single.id, 'docs');
    expect(requests.single.method, 'app/list');
    expect(requests.single.params, {
      'cursor': 'cursor',
      'limit': 25,
      'threadId': 'thr_1',
      'forceRefetch': true,
    });
  });
}
