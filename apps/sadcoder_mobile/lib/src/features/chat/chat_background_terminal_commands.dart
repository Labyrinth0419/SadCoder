import '../../background_terminals/thread_background_terminal_runner.dart';
import '../../i18n/app_localizations.dart';
import 'chat_background_terminal_summary.dart';

Future<String?> buildBackgroundTerminalsSummaryFromCommand({
  required AppLocalizations l10n,
  required ThreadBackgroundTerminalRunner? runner,
  required String? threadId,
  required String arguments,
  int limit = 25,
}) async {
  if (arguments.trim().isNotEmpty) {
    return null;
  }
  if (runner == null || threadId == null) {
    return null;
  }
  final page = await runner.listTerminals(threadId: threadId, limit: limit);
  return buildThreadBackgroundTerminalsSummary(l10n: l10n, page: page);
}

Future<String?> cleanBackgroundTerminalsFromCommand({
  required AppLocalizations l10n,
  required ThreadBackgroundTerminalRunner? runner,
  required String? threadId,
  required String arguments,
}) async {
  if (arguments.trim().isNotEmpty) {
    return null;
  }
  if (runner == null || threadId == null) {
    return null;
  }
  await runner.cleanTerminals(threadId: threadId);
  return buildThreadBackgroundTerminalsCleanSummary(l10n);
}
