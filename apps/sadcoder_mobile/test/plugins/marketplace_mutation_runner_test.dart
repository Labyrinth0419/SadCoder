import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/plugins/codex_marketplace_mutation_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test(
    'addMarketplace normalizes params and parses camelCase response',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {
          'marketplaceName': 'team-tools',
          'installedRoot': '/home/dev/.codex/plugins/marketplaces/team-tools',
          'alreadyAdded': false,
        };
      });
      final runner = CodexMarketplaceMutationRunner(
        CodexAppServerClient(transport),
      );

      final result = await runner.addMarketplace(
        source: ' https://example.com/team-tools.git ',
        refName: ' main ',
        sparsePaths: [' plugins ', ' ', 'skills'],
      );

      expect(result.marketplaceName, 'team-tools');
      expect(
        result.installedRoot,
        '/home/dev/.codex/plugins/marketplaces/team-tools',
      );
      expect(result.alreadyAdded, isFalse);
      expect(requests.single.method, 'marketplace/add');
      expect(requests.single.params, {
        'source': 'https://example.com/team-tools.git',
        'refName': 'main',
        'sparsePaths': ['plugins', 'skills'],
      });
    },
  );

  test(
    'addMarketplace sends nullable optional params and parses snake_case',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {
          'marketplace_name': 'team-tools',
          'installed_root': '/marketplaces/team-tools',
          'already_added': true,
        };
      });
      final runner = CodexMarketplaceMutationRunner(
        CodexAppServerClient(transport),
      );

      final result = await runner.addMarketplace(
        source: 'team-tools',
        refName: ' ',
        sparsePaths: [' '],
      );

      expect(result.alreadyAdded, isTrue);
      expect(requests.single.params, {
        'source': 'team-tools',
        'refName': null,
        'sparsePaths': null,
      });
    },
  );

  test('removeMarketplace normalizes name and parses nullable root', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'marketplace_name': 'team-tools', 'installed_root': null};
    });
    final runner = CodexMarketplaceMutationRunner(
      CodexAppServerClient(transport),
    );

    final result = await runner.removeMarketplace(
      marketplaceName: ' team-tools ',
    );

    expect(result.marketplaceName, 'team-tools');
    expect(result.installedRoot, isNull);
    expect(requests.single.method, 'marketplace/remove');
    expect(requests.single.params, {'marketplaceName': 'team-tools'});
  });

  test(
    'upgradeMarketplaces preserves partial errors from both key styles',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {
          'selected_marketplaces': ['team-tools', 'shared-tools'],
          'upgraded_roots': ['/marketplaces/team-tools'],
          'errors': [
            {
              'marketplaceName': 'shared-tools',
              'message': 'authentication required',
            },
            {'marketplace_name': 'legacy-tools', 'message': 'invalid manifest'},
          ],
        };
      });
      final runner = CodexMarketplaceMutationRunner(
        CodexAppServerClient(transport),
      );

      final result = await runner.upgradeMarketplaces(
        marketplaceName: ' team-tools ',
      );

      expect(result.selectedMarketplaces, ['team-tools', 'shared-tools']);
      expect(result.upgradedRoots, ['/marketplaces/team-tools']);
      expect(result.errors, hasLength(2));
      expect(result.errors.first.marketplaceName, 'shared-tools');
      expect(result.errors.first.message, 'authentication required');
      expect(result.errors.last.marketplaceName, 'legacy-tools');
      expect(requests.single.method, 'marketplace/upgrade');
      expect(requests.single.params, {'marketplaceName': 'team-tools'});
    },
  );

  test(
    'upgradeMarketplaces sends null when upgrading every marketplace',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {
          'selectedMarketplaces': <Object?>[],
          'upgradedRoots': <Object?>[],
          'errors': <Object?>[],
        };
      });
      final runner = CodexMarketplaceMutationRunner(
        CodexAppServerClient(transport),
      );

      await runner.upgradeMarketplaces(marketplaceName: ' ');

      expect(requests.single.params, {'marketplaceName': null});
    },
  );
}
