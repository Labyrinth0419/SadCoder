import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/experimental_features/codex_experimental_feature_runner.dart';
import 'package:sadcoder_mobile/src/experimental_features/experimental_feature_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('parses feature metadata and paginates the server catalog', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      if (request.params?['cursor'] == 'next') {
        return {
          'data': [
            {
              'name': 'prevent_idle_sleep',
              'stage': 'underDevelopment',
              'enabled': false,
              'defaultEnabled': false,
            },
          ],
        };
      }
      return {
        'data': [
          {
            'name': 'network_proxy',
            'stage': 'beta',
            'displayName': 'Network proxy',
            'description': 'Restrict network access.',
            'announcement': 'New',
            'enabled': true,
            'defaultEnabled': false,
          },
        ],
        'nextCursor': 'next',
      };
    });
    final runner = CodexExperimentalFeatureRunner(
      CodexAppServerClient(transport),
    );

    final features = await runner.listFeatures(threadId: 'thread-1');

    expect(features, hasLength(2));
    expect(features.first.isUserSelectable, isTrue);
    expect(features.first.label, 'Network proxy');
    expect(features.last.stage, ExperimentalFeatureStage.underDevelopment);
    expect(requests.map((request) => request.method), [
      'experimentalFeature/list',
      'experimentalFeature/list',
    ]);
    expect(requests.first.params, {'limit': 100, 'threadId': 'thread-1'});
    expect(requests.last.params, {
      'cursor': 'next',
      'limit': 100,
      'threadId': 'thread-1',
    });
  });

  test('persists feature changes with the Codex TUI config path', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'status': 'ok',
        'version': 'v2',
        'filePath': '/home/coder/.codex/config.toml',
      };
    });
    final runner = CodexExperimentalFeatureRunner(
      CodexAppServerClient(transport),
    );

    final result = await runner.setFeatureEnabled(
      featureName: ' network_proxy ',
      enabled: true,
      expectedVersion: 'v1',
    );

    expect(result.status, 'ok');
    expect(result.filePath, '/home/coder/.codex/config.toml');
    expect(requests.single.method, 'config/batchWrite');
    expect(requests.single.params, {
      'edits': [
        {
          'keyPath': 'features.network_proxy',
          'value': true,
          'mergeStrategy': 'upsert',
        },
      ],
      'expectedVersion': 'v1',
      'reloadUserConfig': true,
    });
  });

  test('rejects a blank feature name', () async {
    final runner = CodexExperimentalFeatureRunner(
      CodexAppServerClient(MemoryJsonRpcTransport((_) => {})),
    );

    expect(
      () => runner.setFeatureEnabled(featureName: ' ', enabled: true),
      throwsArgumentError,
    );
  });
}
