import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/diffs/git_diff_reader.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_diff_command.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test('diff command reads selected cwd and renders diff summary', () async {
    final reader = _RecordingGitDiffReader(
      result: const GitDiffResult(
        isGitRepository: true,
        stat: ' lib/main.dart | 2 +-',
        diff: 'diff --git a/lib/main.dart b/lib/main.dart',
      ),
    );

    final summary = await buildGitDiffSummaryFromCommand(
      l10n: l10n,
      reader: reader,
      cwds: const ['/repo', '/other'],
      arguments: '',
    );

    expect(summary, contains('Git diff'));
    expect(summary, contains('lib/main.dart | 2 +-'));
    expect(summary, contains('diff --git'));
    expect(reader.cwdValues, ['/repo']);
  });

  test('diff command uses null cwd when no workspace is selected', () async {
    final reader = _RecordingGitDiffReader(
      result: const GitDiffResult(isGitRepository: true, stat: '', diff: ''),
    );

    final summary = await buildGitDiffSummaryFromCommand(
      l10n: l10n,
      reader: reader,
      cwds: const [],
      arguments: '',
    );

    expect(summary, contains('No tracked or untracked changes.'));
    expect(reader.cwdValues, [isNull]);
  });

  test('diff command rejects unsupported arguments', () async {
    final reader = _RecordingGitDiffReader(
      result: const GitDiffResult(isGitRepository: true, stat: '', diff: ''),
    );

    final summary = await buildGitDiffSummaryFromCommand(
      l10n: l10n,
      reader: reader,
      cwds: const ['/repo'],
      arguments: '--cached',
    );

    expect(summary, isNull);
    expect(reader.cwdValues, isEmpty);
  });

  test('diff command reports unavailable and load failures', () async {
    final unavailable = await buildGitDiffSummaryFromCommand(
      l10n: l10n,
      reader: null,
      cwds: const ['/repo'],
      arguments: '',
    );
    expect(unavailable, 'Git diff\nConnect to a host to compute git diff.');

    final failed = await buildGitDiffSummaryFromCommand(
      l10n: l10n,
      reader: _RecordingGitDiffReader(
        result: const GitDiffResult(isGitRepository: true, stat: '', diff: ''),
        error: StateError('boom'),
      ),
      cwds: const ['/repo'],
      arguments: '',
    );
    expect(failed, contains('Failed to compute diff'));
    expect(failed, contains('boom'));
  });
}

class _RecordingGitDiffReader implements GitDiffReader {
  _RecordingGitDiffReader({required this.result, this.error});

  final GitDiffResult result;
  final Object? error;
  final cwdValues = <String?>[];

  @override
  Future<GitDiffResult> readDiff({String? cwd}) async {
    cwdValues.add(cwd);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return result;
  }
}
