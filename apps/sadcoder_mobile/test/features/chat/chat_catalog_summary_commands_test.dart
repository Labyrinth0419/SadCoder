import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/apps/app_list_reader.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_catalog_summary_commands.dart';
import 'package:sadcoder_mobile/src/hooks/hook_list_reader.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/skills/skill_list_reader.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test('skills command accepts reload and passes cwd context', () async {
    final reader = _RecordingSkillListReader(
      page: SkillListPage.fromJson({
        'data': [
          {
            'cwd': '/repo',
            'skills': [
              {'name': 'review', 'scope': 'repo', 'enabled': true},
            ],
          },
        ],
      }),
    );

    final summary = await buildSkillsSummaryFromCommand(
      l10n: l10n,
      reader: reader,
      cwds: const ['/repo'],
      arguments: 'reload',
    );

    expect(summary, contains('Skills'));
    expect(summary, contains('review'));
    expect(reader.calls, hasLength(1));
    expect(reader.calls.single.cwds, ['/repo']);
    expect(reader.calls.single.forceReload, isTrue);
  });

  test('skills command rejects unsupported arguments', () async {
    final summary = await buildSkillsSummaryFromCommand(
      l10n: l10n,
      reader: _RecordingSkillListReader(page: const SkillListPage(entries: [])),
      cwds: const [],
      arguments: 'unknown',
    );

    expect(summary, isNull);
  });

  test('skills command reports unavailable and load failures', () async {
    final unavailable = await buildSkillsSummaryFromCommand(
      l10n: l10n,
      reader: null,
      cwds: const [],
      arguments: '',
    );
    expect(unavailable, contains(l10n.skillsUnavailable));

    final failed = await buildSkillsSummaryFromCommand(
      l10n: l10n,
      reader: _RecordingSkillListReader(
        page: const SkillListPage(entries: []),
        error: StateError('boom'),
      ),
      cwds: const [],
      arguments: '',
    );
    expect(failed, contains(l10n.skillsLoadFailed));
    expect(failed, contains('boom'));
  });

  test('hooks command lists hooks and rejects inline arguments', () async {
    final reader = _RecordingHookListReader(
      page: HookListPage.fromJson({
        'data': [
          {'cwd': '/repo', 'hooks': const []},
        ],
      }),
    );

    final summary = await buildHooksSummaryFromCommand(
      l10n: l10n,
      reader: reader,
      cwds: const ['/repo'],
      arguments: '',
    );
    final unsupported = await buildHooksSummaryFromCommand(
      l10n: l10n,
      reader: reader,
      cwds: const ['/repo'],
      arguments: 'reload',
    );

    expect(summary, contains('Hooks'));
    expect(reader.calls.single, ['/repo']);
    expect(unsupported, isNull);
  });

  test(
    'apps command passes thread context and rejects inline arguments',
    () async {
      final reader = _RecordingAppListReader(page: const AppListPage(apps: []));

      final summary = await buildAppsSummaryFromCommand(
        l10n: l10n,
        reader: reader,
        threadId: 'thr_1',
        arguments: '',
      );
      final unsupported = await buildAppsSummaryFromCommand(
        l10n: l10n,
        reader: reader,
        threadId: 'thr_1',
        arguments: 'extra',
      );

      expect(summary, 'Apps\nNo apps available.');
      expect(reader.calls.single.threadId, 'thr_1');
      expect(reader.calls.single.limit, 25);
      expect(unsupported, isNull);
    },
  );
}

class _RecordingSkillListReader implements SkillListReader {
  _RecordingSkillListReader({required this.page, this.error});

  final SkillListPage page;
  final Object? error;
  final calls = <({List<String> cwds, bool forceReload})>[];

  @override
  Future<SkillListPage> listSkills({
    List<String> cwds = const [],
    bool forceReload = false,
  }) async {
    calls.add((cwds: List.unmodifiable(cwds), forceReload: forceReload));
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return page;
  }
}

class _RecordingHookListReader implements HookListReader {
  _RecordingHookListReader({required this.page});

  final HookListPage page;
  final calls = <List<String>>[];

  @override
  Future<HookListPage> listHooks({List<String> cwds = const []}) async {
    calls.add(List.unmodifiable(cwds));
    return page;
  }
}

class _RecordingAppListReader implements AppListReader {
  _RecordingAppListReader({required this.page});

  final AppListPage page;
  final calls = <({String? threadId, int? limit})>[];

  @override
  Future<AppListPage> listApps({
    String? cursor,
    int? limit,
    String? threadId,
    bool forceRefetch = false,
  }) async {
    calls.add((threadId: threadId, limit: limit));
    return page;
  }
}
