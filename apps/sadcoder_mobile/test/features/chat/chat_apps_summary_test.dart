import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/apps/app_list_reader.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_apps_summary.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test('buildAppsSummary renders app metadata', () {
    final summary = buildAppsSummary(
      l10n: l10n,
      page: AppListPage.fromJson({
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
            },
            'appMetadata': {
              'review': {'status': 'approved'},
              'version': '1.2.3',
            },
            'isAccessible': true,
            'isEnabled': false,
            'pluginDisplayNames': ['Linear plugin'],
          },
        ],
        'nextCursor': 'next-page',
      }),
    );

    expect(summary, contains('Apps'));
    expect(summary, contains('Linear (linear): accessible, disabled'));
    expect(summary, contains('Description: Plan work'));
    expect(summary, contains('Category: Project management'));
    expect(summary, contains('Developer: Linear'));
    expect(summary, contains('Version: 1.2.3'));
    expect(summary, contains('Distribution: marketplace'));
    expect(summary, contains('Review: approved'));
    expect(summary, contains('Plugins: Linear plugin'));
    expect(summary, contains('Website: https://linear.app'));
    expect(summary, contains('Install URL: https://linear.app/install'));
    expect(summary, contains('Next cursor: next-page'));
  });

  test('buildAppsSummary returns a concise empty state', () {
    final summary = buildAppsSummary(
      l10n: l10n,
      page: const AppListPage(apps: []),
    );

    expect(summary, 'Apps\nNo apps available.');
  });
}
