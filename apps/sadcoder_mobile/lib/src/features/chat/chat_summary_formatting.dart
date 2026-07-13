import '../../i18n/app_localizations.dart';

String chatSummaryMessageWithOptionalDetail(
  AppLocalizations l10n,
  String message,
  Object? detail,
) {
  return detail == null ? message : l10n.messageWithDetail(message, detail);
}
