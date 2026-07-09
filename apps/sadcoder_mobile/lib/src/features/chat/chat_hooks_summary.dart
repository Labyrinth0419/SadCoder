import '../../hooks/hook_list_reader.dart';
import '../../i18n/app_localizations.dart';

String buildHooksSummary({
  required AppLocalizations l10n,
  required HookListPage page,
}) {
  final lines = <String>[l10n.hooksTitle];
  if (page.entries.isEmpty) {
    lines.add(l10n.hooksEmpty);
    return lines.join('\n');
  }

  var hasHooks = false;
  for (final entry in page.entries) {
    lines.add('${l10n.hooksCwd}: ${entry.cwd}');
    if (entry.hooks.isEmpty) {
      lines.add('  ${l10n.hooksEmpty}');
    } else {
      hasHooks = true;
      final hooks = [...entry.hooks]
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      for (final hook in hooks) {
        lines.add(_hookLine(l10n, hook));
        if (hook.matcher != null) {
          lines.add('  ${l10n.hookMatcher}: ${hook.matcher}');
        }
        if (hook.command != null) {
          lines.add('  ${l10n.hookCommand}: ${hook.command}');
        }
        if (hook.statusMessage != null) {
          lines.add('  ${l10n.hookStatusMessage}: ${hook.statusMessage}');
        }
        if (hook.sourcePath.isNotEmpty) {
          lines.add('  ${l10n.hookSourcePath}: ${hook.sourcePath}');
        }
        if (hook.pluginId != null) {
          lines.add('  ${l10n.hookPlugin}: ${hook.pluginId}');
        }
        if (hook.timeoutSec > 0) {
          lines.add('  ${l10n.hookTimeout}: ${hook.timeoutSec}s');
        }
      }
    }

    if (entry.warnings.isNotEmpty) {
      lines.add('  ${l10n.hookWarnings}:');
      for (final warning in entry.warnings) {
        lines.add('  $warning');
      }
    }

    if (entry.errors.isNotEmpty) {
      lines.add('  ${l10n.hookErrors}:');
      for (final error in entry.errors) {
        lines.add('  ${error.path}: ${error.message}');
      }
    }
  }

  if (!hasHooks &&
      page.entries.every(
        (entry) => entry.warnings.isEmpty && entry.errors.isEmpty,
      )) {
    return [l10n.hooksTitle, l10n.hooksEmpty].join('\n');
  }
  return lines.join('\n');
}

String _hookLine(AppLocalizations l10n, HookSummary hook) {
  final enabled = hook.enabled ? l10n.hookEnabled : l10n.hookDisabled;
  final managed = hook.isManaged ? l10n.hookManaged : l10n.hookUserManaged;
  return '${hook.eventName} (${hook.key}): ${hook.handlerType}, $enabled, $managed, ${l10n.hookTrust}: ${hook.trustStatus}, ${l10n.hookSource}: ${hook.source}';
}
