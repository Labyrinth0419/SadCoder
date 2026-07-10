import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_plugins_summary.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
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
}
