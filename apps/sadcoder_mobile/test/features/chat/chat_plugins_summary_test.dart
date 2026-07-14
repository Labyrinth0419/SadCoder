import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_plugins_summary.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/plugins/marketplace_mutation_runner.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_detail_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_list_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_mutation_runner.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test('buildPluginsSummary renders marketplaces and plugin details', () {
    final summary = buildPluginsSummary(
      l10n: l10n,
      page: PluginListPage.fromJson({
        'marketplaces': [
          {
            'name': 'openai-curated',
            'interface': {'displayName': 'OpenAI curated'},
            'plugins': [
              {
                'id': 'linear',
                'name': 'linear',
                'version': '1.2.3',
                'source': {'type': 'remote'},
                'installed': true,
                'enabled': true,
                'installPolicy': 'AVAILABLE',
                'authPolicy': 'ON_USE',
                'interface': {
                  'displayName': 'Linear',
                  'shortDescription': 'Plan work',
                  'capabilities': ['mcp', 'skills'],
                },
              },
            ],
          },
        ],
        'marketplaceLoadErrors': [
          {'marketplacePath': '/bad.json', 'message': 'bad marketplace'},
        ],
      }),
    );

    expect(summary, contains('Plugins'));
    expect(summary, contains('Marketplace: OpenAI curated'));
    expect(summary, contains('Linear (linear): installed, enabled'));
    expect(summary, contains('Description: Plan work'));
    expect(summary, contains('Version: 1.2.3'));
    expect(summary, contains('Source: remote'));
    expect(summary, contains('Capabilities: mcp, skills'));
    expect(summary, contains('/bad.json: bad marketplace'));
  });

  test('buildPluginsSummary returns a concise empty state', () {
    final summary = buildPluginsSummary(
      l10n: l10n,
      page: const PluginListPage(marketplaces: []),
    );

    expect(summary, 'Plugins\nNo plugins available.');
  });

  test('buildPluginDetailSummary renders plugin/read details', () {
    final summary = buildPluginDetailSummary(
      l10n: l10n,
      detail: PluginDetail.fromJson(
        pluginId: 'linear',
        json: {
          'marketplaceName': 'openai-curated',
          'marketplacePath': '/marketplace/plugins.json',
          'readme': '# Linear',
          'plugin': {
            'id': 'linear',
            'name': 'linear',
            'version': '1.2.3',
            'localVersion': '1.2.0',
            'source': {'type': 'remote'},
            'installed': true,
            'enabled': true,
            'availability': 'AVAILABLE',
            'interface': {
              'displayName': 'Linear',
              'shortDescription': 'Plan work',
              'capabilities': ['mcp'],
            },
          },
        },
      ),
    );

    expect(summary, contains('Plugins'));
    expect(summary, contains('Linear (linear): installed, enabled'));
    expect(summary, contains('Description: Plan work'));
    expect(summary, contains('Marketplace: openai-curated'));
    expect(summary, contains('Marketplace path: /marketplace/plugins.json'));
    expect(summary, contains('Version: 1.2.3, local 1.2.0'));
    expect(summary, contains('Source: remote'));
    expect(summary, contains('Capabilities: mcp'));
    expect(summary, contains('README:\n# Linear'));
  });

  test('buildPluginDetailSummary localizes local plugin version label', () {
    const zh = AppLocalizations(Locale('zh', 'CN'));
    final summary = buildPluginDetailSummary(
      l10n: zh,
      detail: PluginDetail.fromJson(
        pluginId: 'linear',
        json: {
          'plugin': {
            'id': 'linear',
            'name': 'linear',
            'version': '1.2.3',
            'localVersion': '1.2.0',
            'installed': true,
            'enabled': true,
            'interface': {'displayName': 'Linear'},
          },
        },
      ),
    );

    expect(summary, contains('版本: 1.2.3, 本地 1.2.0'));
  });

  test('buildPluginMutationSummary renders operation and server message', () {
    final summary = buildPluginMutationSummary(
      l10n: l10n,
      result: const PluginMutationResult(
        operation: PluginMutationOperation.uninstall,
        pluginId: 'linear',
        message: 'removed from workspace',
        raw: <String, Object?>{},
      ),
    );

    expect(
      summary,
      'Uninstall requested for plugin linear.\nremoved from workspace',
    );
  });

  test('buildMarketplaceAddSummary distinguishes new and existing sources', () {
    expect(
      buildMarketplaceAddSummary(
        l10n: l10n,
        result: const MarketplaceAddResult(
          marketplaceName: 'team-tools',
          installedRoot: '/marketplaces/team-tools',
          alreadyAdded: false,
          raw: <String, Object?>{},
        ),
      ),
      'Added marketplace team-tools at /marketplaces/team-tools.',
    );
    expect(
      buildMarketplaceAddSummary(
        l10n: l10n,
        result: const MarketplaceAddResult(
          marketplaceName: 'team-tools',
          installedRoot: '/marketplaces/team-tools',
          alreadyAdded: true,
          raw: <String, Object?>{},
        ),
      ),
      'Marketplace team-tools is already installed at '
      '/marketplaces/team-tools.',
    );
  });

  test('buildMarketplaceRemoveSummary handles known and unknown roots', () {
    expect(
      buildMarketplaceRemoveSummary(
        l10n: l10n,
        result: const MarketplaceRemoveResult(
          marketplaceName: 'team-tools',
          installedRoot: '/marketplaces/team-tools',
          raw: <String, Object?>{},
        ),
      ),
      'Removed marketplace team-tools from /marketplaces/team-tools.',
    );
    expect(
      buildMarketplaceRemoveSummary(
        l10n: l10n,
        result: const MarketplaceRemoveResult(
          marketplaceName: 'team-tools',
          raw: <String, Object?>{},
        ),
      ),
      'Removed marketplace team-tools.',
    );
  });

  test('buildMarketplaceUpgradeSummary includes roots and partial errors', () {
    final summary = buildMarketplaceUpgradeSummary(
      l10n: l10n,
      result: const MarketplaceUpgradeResult(
        selectedMarketplaces: ['team-tools', 'shared-tools'],
        upgradedRoots: ['/marketplaces/team-tools'],
        errors: [
          MarketplaceUpgradeError(
            marketplaceName: 'shared-tools',
            message: 'authentication required',
          ),
        ],
        raw: <String, Object?>{},
      ),
    );

    expect(summary, contains('Selected: team-tools, shared-tools'));
    expect(summary, contains('Upgraded roots: /marketplaces/team-tools'));
    expect(summary, contains('shared-tools: authentication required'));
  });
}
