import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/external_agents/codex_external_agent_config_runner.dart';
import 'package:sadcoder_mobile/src/external_agents/external_agent_config_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('detect preserves migration payloads for a future import', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'items': [
          {
            'itemType': 'PLUGINS',
            'description': 'Install supported plugins',
            'cwd': '/repo',
            'details': {
              'plugins': [
                {
                  'marketplaceName': 'team',
                  'pluginNames': ['linear'],
                },
              ],
              'futureEntries': [
                {'future': true},
              ],
            },
            'futureField': 'preserved',
          },
        ],
      };
    });
    final runner = CodexExternalAgentConfigRunner(
      CodexAppServerClient(transport),
    );

    final result = await runner.detect(
      cwds: [' /repo ', ' '],
      includeHome: true,
    );

    final item = result.items.single;
    expect(item.type, ExternalAgentConfigMigrationItemType.plugins);
    expect(item.rawType, 'PLUGINS');
    expect(item.cwd, '/repo');
    expect(item.detailCount, 2);
    expect(item.toJson()['futureField'], 'preserved');
    expect(requests.single.method, 'externalAgentConfig/detect');
    expect(requests.single.params, {
      'includeHome': true,
      'cwds': ['/repo'],
    });
  });

  test('unknown migration types remain selectable and round trip raw JSON', () {
    final item = ExternalAgentConfigMigrationItem.fromJson({
      'itemType': 'FUTURE_TYPE',
      'description': 'Future migration',
      'future': {'enabled': true},
    });

    expect(item, isNotNull);
    expect(item!.type, ExternalAgentConfigMigrationItemType.unknown);
    expect(item.rawType, 'FUTURE_TYPE');
    expect(item.toJson()['future'], {'enabled': true});
  });

  test('startImport and history use externalAgentConfig methods', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return switch (request.method) {
        'externalAgentConfig/import' => {'importId': 'import_1'},
        'externalAgentConfig/import/readHistories' => {
          'data': [
            {
              'importId': 'import_1',
              'completedAtMs': 1234,
              'successes': [
                {'itemType': 'CONFIG'},
              ],
              'failures': [
                {
                  'itemType': 'HOOKS',
                  'failureStage': 'write',
                  'message': 'Could not write hook',
                },
              ],
            },
          ],
        },
        _ => <String, Object?>{},
      };
    });
    final runner = CodexExternalAgentConfigRunner(
      CodexAppServerClient(transport),
    );
    final item = ExternalAgentConfigMigrationItem.fromJson({
      'itemType': 'CONFIG',
      'description': 'Import config',
      'cwd': null,
    })!;

    final start = await runner.startImport(items: [item], source: ' claude ');
    final histories = await runner.readImportHistories();

    expect(start.importId, 'import_1');
    expect(requests.first.method, 'externalAgentConfig/import');
    expect(requests.first.params, {
      'migrationItems': [item.toJson()],
      'source': 'claude',
    });
    expect(requests.last.method, 'externalAgentConfig/import/readHistories');
    expect(requests.last.params, isNull);
    expect(histories.single.importId, 'import_1');
    expect(histories.single.completedAtMs, 1234);
    expect(histories.single.successCount, 1);
    expect(histories.single.failureCount, 1);
    expect(histories.single.failures.single.message, 'Could not write hook');
  });

  test('startImport rejects an empty selection locally', () async {
    final runner = CodexExternalAgentConfigRunner(
      CodexAppServerClient(MemoryJsonRpcTransport((_) => {})),
    );

    await expectLater(
      runner.startImport(items: const []),
      throwsA(isA<ArgumentError>()),
    );
  });
}
