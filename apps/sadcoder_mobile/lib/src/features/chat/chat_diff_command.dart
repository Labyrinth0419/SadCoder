import '../../diffs/git_diff_reader.dart';
import '../../i18n/app_localizations.dart';
import 'chat_diff_summary.dart';
import 'chat_summary_formatting.dart';

Future<String?> buildGitDiffSummaryFromCommand({
  required AppLocalizations l10n,
  required GitDiffReader? reader,
  required List<String> cwds,
  required String arguments,
}) async {
  if (arguments.trim().isNotEmpty) {
    return null;
  }
  if (reader == null) {
    return [l10n.diffTitle, l10n.diffUnavailable].join('\n');
  }

  try {
    final result = await reader.readDiff(cwd: cwds.isEmpty ? null : cwds.first);
    return buildGitDiffSummary(l10n: l10n, result: result);
  } on Object catch (error) {
    return [
      l10n.diffTitle,
      chatSummaryMessageWithOptionalDetail(l10n, l10n.diffLoadFailed, error),
    ].join('\n');
  }
}
