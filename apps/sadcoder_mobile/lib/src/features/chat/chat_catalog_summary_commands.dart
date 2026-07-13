import '../../apps/app_list_reader.dart';
import '../../hooks/hook_list_reader.dart';
import '../../i18n/app_localizations.dart';
import '../../skills/skill_list_reader.dart';
import 'chat_summary_formatting.dart';
import 'chat_apps_summary.dart';
import 'chat_hooks_summary.dart';
import 'chat_skills_summary.dart';

Future<String?> buildSkillsSummaryFromCommand({
  required AppLocalizations l10n,
  required SkillListReader? reader,
  required List<String> cwds,
  required String arguments,
}) async {
  final normalized = arguments.trim().toLowerCase();
  final forceReload = normalized == 'reload' || normalized == 'refresh';
  if (normalized.isNotEmpty && !forceReload) {
    return null;
  }
  return _buildCatalogSummary(
    l10n: l10n,
    title: l10n.skillsTitle,
    unavailableMessage: l10n.skillsUnavailable,
    loadFailedMessage: l10n.skillsLoadFailed,
    reader: reader,
    load: () => reader!.listSkills(cwds: cwds, forceReload: forceReload),
    render: (page) => buildSkillsSummary(l10n: l10n, page: page),
  );
}

Future<String?> buildHooksSummaryFromCommand({
  required AppLocalizations l10n,
  required HookListReader? reader,
  required List<String> cwds,
  required String arguments,
}) async {
  if (arguments.trim().isNotEmpty) {
    return null;
  }
  return _buildCatalogSummary(
    l10n: l10n,
    title: l10n.hooksTitle,
    unavailableMessage: l10n.hooksUnavailable,
    loadFailedMessage: l10n.hooksLoadFailed,
    reader: reader,
    load: () => reader!.listHooks(cwds: cwds),
    render: (page) => buildHooksSummary(l10n: l10n, page: page),
  );
}

Future<String?> buildAppsSummaryFromCommand({
  required AppLocalizations l10n,
  required AppListReader? reader,
  required String? threadId,
  required String arguments,
}) async {
  if (arguments.trim().isNotEmpty) {
    return null;
  }
  return _buildCatalogSummary(
    l10n: l10n,
    title: l10n.appsTitle,
    unavailableMessage: l10n.appsUnavailable,
    loadFailedMessage: l10n.appsLoadFailed,
    reader: reader,
    load: () => reader!.listApps(threadId: threadId, limit: 25),
    render: (page) => buildAppsSummary(l10n: l10n, page: page),
  );
}

Future<String?> _buildCatalogSummary<T>({
  required AppLocalizations l10n,
  required String title,
  required String unavailableMessage,
  required String loadFailedMessage,
  required Object? reader,
  required Future<T> Function() load,
  required String Function(T page) render,
}) async {
  if (reader == null) {
    return [title, unavailableMessage].join('\n');
  }
  try {
    return render(await load());
  } on Object catch (error) {
    return [
      title,
      chatSummaryMessageWithOptionalDetail(l10n, loadFailedMessage, error),
    ].join('\n');
  }
}
