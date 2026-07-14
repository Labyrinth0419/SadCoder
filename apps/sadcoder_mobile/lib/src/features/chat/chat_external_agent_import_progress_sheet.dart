import 'package:flutter/material.dart';

import '../../external_agents/external_agent_config_import_controller.dart';
import '../../external_agents/external_agent_config_runner.dart';
import '../../i18n/app_localizations.dart';

class ChatExternalAgentImportProgressSheet extends StatelessWidget {
  const ChatExternalAgentImportProgressSheet({
    super.key,
    required this.controller,
  });

  final ExternalAgentConfigImportController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final l10n = context.l10n;
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.externalAgentImportProgressTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey(
                          'external-agent-import-progress-close',
                        ),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _ImportStatusHeader(controller: controller),
                const Divider(height: 1),
                Expanded(
                  child: controller.results.isEmpty
                      ? Center(
                          child: Text(
                            _emptyStatusText(l10n, controller.status),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView(
                          children: [
                            for (final result in controller.results)
                              ..._resultTiles(l10n, result),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImportStatusHeader extends StatelessWidget {
  const _ImportStatusHeader({required this.controller});

  final ExternalAgentConfigImportController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = controller.status;
    final running =
        status == ExternalAgentConfigImportStatus.waiting ||
        status == ExternalAgentConfigImportStatus.running;
    final icon = switch (status) {
      ExternalAgentConfigImportStatus.waiting ||
      ExternalAgentConfigImportStatus.running => null,
      ExternalAgentConfigImportStatus.completed
          when controller.failureCount > 0 =>
        Icons.warning_amber_outlined,
      ExternalAgentConfigImportStatus.completed => Icons.check_circle_outline,
      ExternalAgentConfigImportStatus.failed => Icons.error_outline,
    };
    final color = switch (status) {
      ExternalAgentConfigImportStatus.completed
          when controller.failureCount == 0 =>
        Theme.of(context).colorScheme.primary,
      ExternalAgentConfigImportStatus.completed ||
      ExternalAgentConfigImportStatus.failed => Theme.of(
        context,
      ).colorScheme.error,
      _ => Theme.of(context).colorScheme.secondary,
    };
    return ListTile(
      leading: running
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Icon(icon, color: color),
      title: Text(_statusTitle(l10n, status)),
      subtitle: status == ExternalAgentConfigImportStatus.completed
          ? Text(
              l10n.externalAgentImportResultCounts(
                controller.successCount,
                controller.failureCount,
              ),
            )
          : null,
    );
  }
}

Iterable<Widget> _resultTiles(
  AppLocalizations l10n,
  ExternalAgentConfigImportTypeResult result,
) sync* {
  yield Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Text(
      l10n.externalAgentImportType(result.rawType),
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
  for (var index = 0; index < result.successes.length; index++) {
    final success = result.successes[index];
    yield ListTile(
      key: ValueKey('external-agent-import-success-${result.rawType}-$index'),
      leading: const Icon(Icons.check_circle_outline),
      title: Text(success.target ?? l10n.externalAgentImportSuccess),
      subtitle: _scopeText(l10n, success.cwd),
      dense: true,
    );
  }
  for (var index = 0; index < result.failures.length; index++) {
    final failure = result.failures[index];
    yield ListTile(
      key: ValueKey('external-agent-import-failure-${result.rawType}-$index'),
      leading: const Icon(Icons.error_outline),
      title: Text(failure.message),
      subtitle: Text(
        [
          failure.failureStage,
          if (failure.cwd != null)
            l10n.externalAgentImportRepoScope(failure.cwd!),
        ].join(' | '),
      ),
      dense: true,
    );
  }
}

Widget? _scopeText(AppLocalizations l10n, String? cwd) {
  return Text(
    cwd == null
        ? l10n.externalAgentImportHomeScope
        : l10n.externalAgentImportRepoScope(cwd),
  );
}

String _statusTitle(
  AppLocalizations l10n,
  ExternalAgentConfigImportStatus status,
) {
  return switch (status) {
    ExternalAgentConfigImportStatus.waiting => l10n.externalAgentImportStarting,
    ExternalAgentConfigImportStatus.running => l10n.externalAgentImportRunning,
    ExternalAgentConfigImportStatus.completed =>
      l10n.externalAgentImportCompleted,
    ExternalAgentConfigImportStatus.failed => l10n.externalAgentImportFailed,
  };
}

String _emptyStatusText(
  AppLocalizations l10n,
  ExternalAgentConfigImportStatus status,
) {
  return switch (status) {
    ExternalAgentConfigImportStatus.waiting => l10n.externalAgentImportStarting,
    ExternalAgentConfigImportStatus.running =>
      l10n.externalAgentImportWaitingForProgress,
    ExternalAgentConfigImportStatus.completed =>
      l10n.externalAgentImportNoResultDetails,
    ExternalAgentConfigImportStatus.failed => l10n.externalAgentImportFailed,
  };
}
