import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/diffs/git_diff_reader.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_diff_summary.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test('builds not-repository summary', () {
    final summary = buildGitDiffSummary(
      l10n: l10n,
      result: const GitDiffResult(isGitRepository: false, stat: '', diff: ''),
    );

    expect(summary, contains('Git diff'));
    expect(summary, contains('not inside a Git repository'));
  });

  test('builds no-changes summary', () {
    final summary = buildGitDiffSummary(
      l10n: l10n,
      result: const GitDiffResult(isGitRepository: true, stat: '', diff: ''),
    );

    expect(summary, contains('No tracked or untracked changes.'));
  });

  test('builds changed summary with stat and diff', () {
    final summary = buildGitDiffSummary(
      l10n: l10n,
      result: const GitDiffResult(
        isGitRepository: true,
        stat: ' lib/main.dart | 2 +-',
        diff: 'diff --git a/lib/main.dart b/lib/main.dart',
      ),
    );

    expect(summary, contains(' lib/main.dart | 2 +-'));
    expect(summary, contains('diff --git a/lib/main.dart b/lib/main.dart'));
  });
}
