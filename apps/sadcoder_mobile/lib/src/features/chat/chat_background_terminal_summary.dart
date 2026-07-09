import '../../background_terminals/thread_background_terminal.dart';
import '../../i18n/app_localizations.dart';

String buildThreadBackgroundTerminalsSummary({
  required AppLocalizations l10n,
  required ThreadBackgroundTerminalPage page,
}) {
  final lines = <String>[l10n.backgroundTerminalsTitle];
  if (page.terminals.isEmpty) {
    lines.add(l10n.backgroundTerminalsEmpty);
    return lines.join('\n');
  }

  for (final terminal in page.terminals) {
    lines.add(_terminalSummaryLine(l10n, terminal));
    if (terminal.cwd.isNotEmpty) {
      lines.add('  ${l10n.backgroundTerminalCwd}: ${terminal.cwd}');
    }
    lines.add('  ${l10n.backgroundTerminalItem}: ${terminal.itemId}');
    if (terminal.osPid != null) {
      lines.add('  ${l10n.backgroundTerminalOsPid}: ${terminal.osPid}');
    }
    if (terminal.cpuPercent != null) {
      lines.add(
        '  ${l10n.backgroundTerminalCpu}: ${terminal.cpuPercent!.toStringAsFixed(1)}%',
      );
    }
    if (terminal.rssKb != null) {
      lines.add('  ${l10n.backgroundTerminalRss}: ${terminal.rssKb} KB');
    }
  }

  if (page.nextCursor != null) {
    lines.add(l10n.backgroundTerminalsMore);
  }
  return lines.join('\n');
}

String buildThreadBackgroundTerminalsCleanSummary(AppLocalizations l10n) {
  return l10n.backgroundTerminalsCleanRequested;
}

String _terminalSummaryLine(
  AppLocalizations l10n,
  ThreadBackgroundTerminal terminal,
) {
  final command = terminal.command.isEmpty ? '-' : terminal.command;
  return '${l10n.backgroundTerminalProcess} ${terminal.processId}: $command';
}
