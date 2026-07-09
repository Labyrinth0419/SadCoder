import '../../diffs/git_diff_reader.dart';
import '../../i18n/app_localizations.dart';

String buildGitDiffSummary({
  required AppLocalizations l10n,
  required GitDiffResult result,
}) {
  if (!result.isGitRepository) {
    return [l10n.diffTitle, l10n.diffNotGitRepository].join('\n');
  }
  if (!result.hasChanges) {
    return [l10n.diffTitle, l10n.diffNoChanges].join('\n');
  }

  final parts = <String>[l10n.diffTitle];
  final stat = result.stat.trimRight();
  if (stat.isNotEmpty) {
    parts.add(stat);
  }
  final diff = result.diff.trimRight();
  if (diff.isNotEmpty) {
    parts.add(diff);
  }
  return parts.join('\n\n');
}
