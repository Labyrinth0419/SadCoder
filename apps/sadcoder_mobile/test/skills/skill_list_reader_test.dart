import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/skills/codex_skill_list_reader.dart';
import 'package:sadcoder_mobile/src/skills/skill_list_reader.dart';

void main() {
  test('SkillListPage parses skill inventory payloads', () {
    final page = SkillListPage.fromJson({
      'data': [
        {
          'cwd': '/repo',
          'skills': [
            {
              'name': 'pr-review',
              'description': 'Review pull requests carefully',
              'shortDescription': 'Review PRs',
              'interface': {
                'displayName': 'PR Babysitter',
                'shortDescription': 'Review changed files',
                'brandColor': '#0F766E',
                'defaultPrompt': 'Review this PR',
              },
              'path': '/repo/.codex/skills/pr-review/SKILL.md',
              'scope': 'repo',
              'enabled': false,
            },
            {'description': 'missing name'},
          ],
          'errors': [
            {
              'path': '/repo/.codex/skills/broken/SKILL.md',
              'message': 'invalid frontmatter',
            },
          ],
        },
        {'skills': []},
      ],
    });

    expect(page.entries, hasLength(1));
    final entry = page.entries.single;
    expect(entry.cwd, '/repo');
    expect(entry.skills, hasLength(1));
    expect(entry.errors.single.message, 'invalid frontmatter');

    final skill = entry.skills.single;
    expect(skill.name, 'pr-review');
    expect(skill.displayName, 'PR Babysitter');
    expect(skill.summary, 'Review changed files');
    expect(skill.scope, 'repo');
    expect(skill.enabled, false);
    expect(skill.interface?.brandColor, '#0F766E');
  });

  test('CodexSkillListReader calls app-server skills/list', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'data': [
          {
            'cwd': '/repo',
            'skills': [
              {
                'name': 'doc',
                'description': 'Write docs',
                'path': '/repo/.codex/skills/doc/SKILL.md',
                'scope': 'repo',
                'enabled': true,
              },
            ],
            'errors': <Object?>[],
          },
        ],
      };
    });
    final reader = CodexSkillListReader(CodexAppServerClient(transport));

    final page = await reader.listSkills(
      cwds: [' /repo ', ' '],
      forceReload: true,
    );

    expect(page.entries.single.skills.single.name, 'doc');
    expect(requests.single.method, 'skills/list');
    expect(requests.single.params, {
      'cwds': ['/repo'],
      'forceReload': true,
    });
  });
}
