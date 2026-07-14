import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_skills_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/skills/skill_list_reader.dart';
import 'package:sadcoder_mobile/src/skills/skill_mutation_runner.dart';

void main() {
  testWidgets('manages skills with confirmation and forced reload', (
    tester,
  ) async {
    final reader = _RecordingSkillReader();
    final mutationRunner = _RecordingSkillMutationRunner(reader);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showChatSkillsSheet(
                  context: context,
                  reader: reader,
                  mutationRunner: mutationRunner,
                  cwds: const ['/repo'],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('PR Reviewer'), findsOneWidget);
    expect(reader.calls, hasLength(1));
    expect(reader.calls.single.cwds, ['/repo']);
    expect(reader.calls.single.forceReload, isFalse);

    const switchKey = ValueKey(
      'chat-skill-enabled-/repo/.codex/skills/review/SKILL.md',
    );
    await tester.tap(find.byKey(switchKey));
    await tester.pumpAndSettle();

    expect(find.text('Confirm skill change'), findsOneWidget);
    expect(find.textContaining('affects other Codex clients'), findsOneWidget);
    expect(mutationRunner.calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('chat-skill-mutation-confirm')));
    await tester.pumpAndSettle();

    expect(mutationRunner.calls, [
      (path: '/repo/.codex/skills/review/SKILL.md', name: null, enabled: false),
    ]);
    expect(reader.calls, hasLength(2));
    expect(reader.calls[0].cwds, ['/repo']);
    expect(reader.calls[0].forceReload, isFalse);
    expect(reader.calls[1].cwds, ['/repo']);
    expect(reader.calls[1].forceReload, isTrue);
    expect(tester.widget<Switch>(find.byKey(switchKey)).value, isFalse);
  });

  testWidgets('filters skills without changing server state', (tester) async {
    final reader = _RecordingSkillReader();
    final mutationRunner = _RecordingSkillMutationRunner(reader);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showChatSkillsSheet(
                context: context,
                reader: reader,
                mutationRunner: mutationRunner,
                cwds: const ['/repo'],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chat-skills-search')),
      'missing',
    );
    await tester.pump();

    expect(find.text('No matching skills.'), findsOneWidget);
    expect(find.text('PR Reviewer'), findsNothing);
    expect(mutationRunner.calls, isEmpty);
  });
}

class _RecordingSkillReader implements SkillListReader {
  final calls = <({List<String> cwds, bool forceReload})>[];
  bool enabled = true;

  @override
  Future<SkillListPage> listSkills({
    List<String> cwds = const [],
    bool forceReload = false,
  }) async {
    calls.add((cwds: List.unmodifiable(cwds), forceReload: forceReload));
    return SkillListPage.fromJson({
      'data': [
        {
          'cwd': '/repo',
          'skills': [
            {
              'name': 'review',
              'description': 'Review changed files',
              'interface': {
                'displayName': 'PR Reviewer',
                'shortDescription': 'Review changed files',
              },
              'path': '/repo/.codex/skills/review/SKILL.md',
              'scope': 'repo',
              'enabled': enabled,
            },
          ],
          'errors': <Object?>[],
        },
      ],
    });
  }
}

class _RecordingSkillMutationRunner implements SkillMutationRunner {
  _RecordingSkillMutationRunner(this.reader);

  final _RecordingSkillReader reader;
  final calls = <({String? path, String? name, bool enabled})>[];

  @override
  Future<SkillMutationResult> setSkillEnabled({
    String? path,
    String? name,
    required bool enabled,
  }) async {
    calls.add((path: path, name: name, enabled: enabled));
    reader.enabled = enabled;
    return SkillMutationResult(
      effectiveEnabled: enabled,
      raw: {'effectiveEnabled': enabled},
    );
  }
}
