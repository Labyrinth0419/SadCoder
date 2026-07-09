import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_skills_summary.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/skills/skill_list_reader.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test('buildSkillsSummary renders skills and load errors', () {
    final summary = buildSkillsSummary(
      l10n: l10n,
      page: SkillListPage.fromJson({
        'data': [
          {
            'cwd': '/repo',
            'skills': [
              {
                'name': 'pr-review',
                'description': 'Review PRs',
                'interface': {
                  'displayName': 'PR Babysitter',
                  'shortDescription': 'Review changed files',
                },
                'path': '/repo/.codex/skills/pr-review/SKILL.md',
                'scope': 'repo',
                'enabled': true,
              },
            ],
            'errors': [
              {'path': '/repo/broken/SKILL.md', 'message': 'bad skill'},
            ],
          },
        ],
      }),
    );

    expect(summary, contains('Skills'));
    expect(summary, contains('cwd: /repo'));
    expect(summary, contains('PR Babysitter (pr-review): enabled'));
    expect(summary, contains('Description: Review changed files'));
    expect(summary, contains('Path: /repo/.codex/skills/pr-review/SKILL.md'));
    expect(summary, contains('/repo/broken/SKILL.md: bad skill'));
  });

  test('buildSkillsSummary returns a concise empty state', () {
    final summary = buildSkillsSummary(
      l10n: l10n,
      page: const SkillListPage(entries: []),
    );

    expect(summary, 'Skills\nNo skills available.');
  });
}
