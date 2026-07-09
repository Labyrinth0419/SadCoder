import '../../i18n/app_localizations.dart';
import '../../skills/skill_list_reader.dart';

String buildSkillsSummary({
  required AppLocalizations l10n,
  required SkillListPage page,
}) {
  final lines = <String>[l10n.skillsTitle];
  if (page.entries.isEmpty) {
    lines.add(l10n.skillsEmpty);
    return lines.join('\n');
  }

  var hasSkills = false;
  for (final entry in page.entries) {
    lines.add('${l10n.skillsCwd}: ${entry.cwd}');
    if (entry.skills.isEmpty) {
      lines.add('  ${l10n.skillsEmpty}');
    } else {
      hasSkills = true;
      for (final skill in entry.skills) {
        lines.add(_skillLine(l10n, skill));
        final summary = skill.summary;
        if (summary.isNotEmpty) {
          lines.add('  ${l10n.skillDescription}: $summary');
        }
        if (skill.path.isNotEmpty) {
          lines.add('  ${l10n.skillPath}: ${skill.path}');
        }
      }
    }

    if (entry.errors.isNotEmpty) {
      lines.add('  ${l10n.skillErrors}:');
      for (final error in entry.errors) {
        lines.add('  ${error.path}: ${error.message}');
      }
    }
  }

  if (!hasSkills && page.entries.every((entry) => entry.errors.isEmpty)) {
    return [l10n.skillsTitle, l10n.skillsEmpty].join('\n');
  }
  return lines.join('\n');
}

String _skillLine(AppLocalizations l10n, SkillSummary skill) {
  final state = skill.enabled ? l10n.skillEnabled : l10n.skillDisabled;
  return '${skill.displayName} (${skill.name}): $state, ${l10n.skillScope}: ${skill.scope}';
}
