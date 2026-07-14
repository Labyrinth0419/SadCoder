import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../accounts/account_snapshot_controller.dart';
import '../../commands/slash_command_action_dispatcher.dart';
import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_snapshot_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../mcp/mcp_server_status_controller.dart';
import '../../plugins/plugin_list_reader.dart';
import '../../session/codex_session_state_controller.dart';
import '../../threads/thread_detail_controller.dart';
import '../../threads/thread_list_controller.dart';
import '../../turns/turn_controller.dart';
import '../../usage/account_usage_snapshot_controller.dart';
import '../../usage/thread_token_usage_controller.dart';
import 'chat_background_terminal_commands.dart';
import 'chat_catalog_summary_commands.dart';
import 'chat_config_summary_commands.dart';
import 'chat_diff_command.dart';
import 'chat_experimental_feature_command.dart';
import 'chat_goal_command.dart';
import 'chat_hooks_sheet.dart';
import 'chat_mcp_command.dart';
import 'chat_memories_command.dart';
import 'chat_plugins_command.dart';
import 'chat_plugins_summary.dart' as plugins_summary;
import 'chat_review_command.dart';
import 'chat_rollout_diagnostics.dart';
import 'chat_skills_sheet.dart';
import 'chat_status_summary.dart';
import 'chat_summary_formatting.dart';
import 'chat_test_approval_command.dart';
import 'chat_timeline_controller.dart';
import 'chat_usage_summary.dart';

typedef ChatSummaryStringProvider = String? Function();
typedef ChatSummaryWorkspaceCwdsProvider = List<String> Function();
typedef ChatSummaryThreadUsageProvider = ThreadTokenUsageSnapshot? Function();
typedef ChatSummaryVisibleThreadsRefresher = void Function({int limit});

class ChatSummaryCommandHandler {
  const ChatSummaryCommandHandler({
    required this.context,
    required this.sessionController,
    required this.threadListController,
    required this.threadDetailController,
    required this.turnController,
    required this.timelineController,
    required this.configOverrideController,
    required this.configSnapshotController,
    required this.accountSnapshotController,
    required this.accountUsageSnapshotController,
    required this.mcpServerStatusController,
    required this.threadTokenUsageController,
    required this.currentThreadIdProvider,
    required this.currentWorkspaceCwdsProvider,
    required this.currentThreadUsageProvider,
    required this.refreshVisibleThreads,
  });

  final BuildContext context;
  final CodexSessionStateController? sessionController;
  final ThreadListController? threadListController;
  final ThreadDetailController? threadDetailController;
  final TurnController? turnController;
  final ChatTimelineController? timelineController;
  final CodexConfigOverrideController? configOverrideController;
  final CodexConfigSnapshotController? configSnapshotController;
  final AccountSnapshotController? accountSnapshotController;
  final AccountUsageSnapshotController? accountUsageSnapshotController;
  final McpServerStatusController? mcpServerStatusController;
  final ThreadTokenUsageController? threadTokenUsageController;
  final ChatSummaryStringProvider currentThreadIdProvider;
  final ChatSummaryWorkspaceCwdsProvider currentWorkspaceCwdsProvider;
  final ChatSummaryThreadUsageProvider currentThreadUsageProvider;
  final ChatSummaryVisibleThreadsRefresher refreshVisibleThreads;

  Future<String> buildStatusSummary() async {
    final l10n = context.l10n;
    await _refreshStatusSources();
    return buildChatStatusSummary(
      l10n: l10n,
      sessionController: sessionController,
      threadListController: threadListController,
      threadDetailController: threadDetailController,
      turnController: turnController,
      timelineController: timelineController,
      configOverrideController: configOverrideController,
      configSnapshotController: configSnapshotController,
      accountSnapshotController: accountSnapshotController,
      accountUsageSnapshotController: accountUsageSnapshotController,
      threadTokenUsageController: threadTokenUsageController,
    );
  }

  Future<String> buildUsageSummary() async {
    final l10n = context.l10n;
    final controller = accountUsageSnapshotController;
    if (controller != null) {
      await controller.refresh();
    }
    return buildAccountUsageSummary(
      l10n: l10n,
      controller: controller,
      threadUsage: currentThreadUsageProvider(),
    );
  }

  Future<String?> buildMcpSummary(String arguments) async {
    return buildMcpSummaryFromCommand(
      l10n: context.l10n,
      statusController: mcpServerStatusController,
      oauthRunner: sessionController?.mcpServerOAuthRunner,
      configRunner: sessionController?.mcpServerConfigRunner,
      threadId: currentThreadIdProvider(),
      arguments: arguments,
    );
  }

  Future<String?> buildSkillsSummary(String arguments) async {
    final reader = sessionController?.skillListReader;
    final mutationRunner = sessionController?.skillMutationRunner;
    if (arguments.trim().isEmpty && reader != null && mutationRunner != null) {
      await showChatSkillsSheet(
        context: context,
        reader: reader,
        mutationRunner: mutationRunner,
        cwds: currentWorkspaceCwdsProvider(),
      );
      if (!context.mounted) {
        return null;
      }
      return context.l10n.skillsManagementClosed;
    }
    return buildSkillsSummaryFromCommand(
      l10n: context.l10n,
      reader: reader,
      cwds: currentWorkspaceCwdsProvider(),
      arguments: arguments,
    );
  }

  Future<String?> buildPluginsSummary(String arguments) async {
    final command = parseChatPluginsCommand(arguments);
    if (command == null) {
      return null;
    }

    final l10n = context.l10n;
    final reader = sessionController?.pluginListReader;
    final cwds = currentWorkspaceCwdsProvider();
    if (command case ChatPluginsSkillReadCommand(
      :final pluginId,
      :final skillName,
    )) {
      final skillReader = sessionController?.pluginSkillReader;
      if (skillReader == null || reader == null) {
        return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
      }
      try {
        final page = await reader.listPlugins(cwds: cwds);
        final target = page.resolveTarget(pluginId);
        final document = await skillReader.readSkill(
          target: target,
          skillName: skillName,
        );
        return plugins_summary.buildPluginSkillSummary(
          l10n: l10n,
          document: document,
        );
      } on Object catch (error) {
        return [
          l10n.pluginsTitle,
          chatSummaryMessageWithOptionalDetail(
            l10n,
            l10n.pluginSkillReadFailed,
            error,
          ),
        ].join('\n');
      }
    }
    if (command case ChatPluginsReadCommand(:final pluginId)) {
      final detailReader = sessionController?.pluginDetailReader;
      if (detailReader == null || reader == null) {
        return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
      }
      try {
        final page = await reader.listPlugins(cwds: cwds);
        final target = page.resolveTarget(pluginId);
        final detail = await detailReader.readPlugin(target: target);
        return plugins_summary.buildPluginDetailSummary(
          l10n: l10n,
          detail: detail,
        );
      } on Object catch (error) {
        return [
          l10n.pluginsTitle,
          chatSummaryMessageWithOptionalDetail(
            l10n,
            l10n.pluginsLoadFailed,
            error,
          ),
        ].join('\n');
      }
    }
    final mutationPluginId = switch (command) {
      ChatPluginsInstallCommand(:final pluginId) => pluginId,
      ChatPluginsUninstallCommand(:final pluginId) => pluginId,
      _ => null,
    };
    if (mutationPluginId != null) {
      final runner = sessionController?.pluginMutationRunner;
      if (runner == null) {
        return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
      }
      PluginCatalogTarget? installTarget;
      if (command is ChatPluginsInstallCommand) {
        if (reader == null) {
          return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
        }
        try {
          final page = await reader.listPlugins(cwds: cwds);
          installTarget = page.resolveTarget(mutationPluginId);
        } on Object catch (error) {
          return [
            l10n.pluginsTitle,
            chatSummaryMessageWithOptionalDetail(
              l10n,
              l10n.pluginMutationFailed,
              error,
            ),
          ].join('\n');
        }
      }
      if (!await _confirmPluginMutation(command)) {
        return l10n.pluginMutationCancelled;
      }
      try {
        final result = switch (command) {
          ChatPluginsInstallCommand() => await runner.installPlugin(
            target: installTarget!,
          ),
          ChatPluginsUninstallCommand() => await runner.uninstallPlugin(
            pluginId: mutationPluginId,
          ),
          _ => throw StateError('Unexpected plugin mutation command.'),
        };
        final lines = <String>[
          plugins_summary.buildPluginMutationSummary(
            l10n: l10n,
            result: result,
          ),
        ];
        if (reader != null) {
          final page = await reader.listPlugins(cwds: cwds);
          lines.add(
            plugins_summary.buildPluginsSummary(l10n: l10n, page: page),
          );
        }
        return lines.join('\n');
      } on Object catch (error) {
        return [
          l10n.pluginsTitle,
          chatSummaryMessageWithOptionalDetail(
            l10n,
            l10n.pluginMutationFailed,
            error,
          ),
        ].join('\n');
      }
    }

    if (command is ChatMarketplaceAddCommand ||
        command is ChatMarketplaceRemoveCommand ||
        command is ChatMarketplaceUpgradeCommand) {
      final runner = sessionController?.marketplaceMutationRunner;
      if (runner == null) {
        return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
      }
      if (!await _confirmPluginMutation(command)) {
        return l10n.pluginMutationCancelled;
      }
      try {
        final mutationSummary = switch (command) {
          ChatMarketplaceAddCommand(
            :final source,
            :final refName,
            :final sparsePaths,
          ) =>
            plugins_summary.buildMarketplaceAddSummary(
              l10n: l10n,
              result: await runner.addMarketplace(
                source: source,
                refName: refName,
                sparsePaths: sparsePaths,
              ),
            ),
          ChatMarketplaceRemoveCommand(:final marketplaceName) =>
            plugins_summary.buildMarketplaceRemoveSummary(
              l10n: l10n,
              result: await runner.removeMarketplace(
                marketplaceName: marketplaceName,
              ),
            ),
          ChatMarketplaceUpgradeCommand(:final marketplaceName) =>
            plugins_summary.buildMarketplaceUpgradeSummary(
              l10n: l10n,
              result: await runner.upgradeMarketplaces(
                marketplaceName: marketplaceName,
              ),
            ),
          _ => throw StateError('Unexpected marketplace mutation command.'),
        };
        final lines = <String>[mutationSummary];
        if (reader != null) {
          final page = await reader.listPlugins(cwds: cwds);
          lines.add(
            plugins_summary.buildPluginsSummary(l10n: l10n, page: page),
          );
        }
        return lines.join('\n');
      } on Object catch (error) {
        return [
          l10n.pluginsTitle,
          chatSummaryMessageWithOptionalDetail(
            l10n,
            l10n.pluginMutationFailed,
            error,
          ),
        ].join('\n');
      }
    }

    final marketplaceKinds = switch (command) {
      ChatPluginsListCommand(:final marketplaceKinds) => marketplaceKinds,
      _ => const <PluginMarketplaceKind>[],
    };
    if (reader == null) {
      return [l10n.pluginsTitle, l10n.pluginsUnavailable].join('\n');
    }

    try {
      final page = await reader.listPlugins(
        cwds: cwds,
        marketplaceKinds: marketplaceKinds,
      );
      return plugins_summary.buildPluginsSummary(l10n: l10n, page: page);
    } on Object catch (error) {
      return [
        l10n.pluginsTitle,
        chatSummaryMessageWithOptionalDetail(
          l10n,
          l10n.pluginsLoadFailed,
          error,
        ),
      ].join('\n');
    }
  }

  Future<bool> _confirmPluginMutation(ChatPluginsCommand command) async {
    final l10n = context.l10n;
    final action = switch (command) {
      ChatPluginsInstallCommand(:final pluginId) => l10n.pluginInstallAction(
        pluginId,
      ),
      ChatPluginsUninstallCommand(:final pluginId) =>
        l10n.pluginUninstallAction(pluginId),
      ChatMarketplaceAddCommand(
        :final source,
        :final refName,
        :final sparsePaths,
      ) =>
        [
          l10n.marketplaceAddAction(source),
          if (refName != null) '--ref $refName',
          for (final path in sparsePaths) '--sparse $path',
        ].join('\n'),
      ChatMarketplaceRemoveCommand(:final marketplaceName) =>
        l10n.marketplaceRemoveAction(marketplaceName),
      ChatMarketplaceUpgradeCommand(:final marketplaceName) =>
        l10n.marketplaceUpgradeAction(marketplaceName ?? l10n.marketplaceAll),
      _ => throw StateError('Expected a plugin mutation command.'),
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pluginMutationConfirmTitle),
        content: Text(l10n.pluginMutationConfirmBody(action)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('plugin-mutation-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.pluginMutationConfirmContinue),
          ),
        ],
      ),
    );
    return context.mounted && confirmed == true;
  }

  Future<String?> buildHooksSummary(String arguments) async {
    final mutationRunner = sessionController?.hookMutationRunner;
    final reader = sessionController?.hookListReader;
    if (arguments.trim().isEmpty && mutationRunner != null && reader != null) {
      await showChatHooksSheet(
        context: context,
        reader: reader,
        mutationRunner: mutationRunner,
        cwds: currentWorkspaceCwdsProvider(),
      );
      if (!context.mounted) {
        return null;
      }
      return context.l10n.hooksManagementClosed;
    }
    return buildHooksSummaryFromCommand(
      l10n: context.l10n,
      reader: reader,
      cwds: currentWorkspaceCwdsProvider(),
      arguments: arguments,
    );
  }

  Future<String?> buildAppsSummary(String arguments) async {
    return buildAppsSummaryFromCommand(
      l10n: context.l10n,
      reader: sessionController?.appListReader,
      threadId: currentThreadIdProvider(),
      arguments: arguments,
    );
  }

  Future<String?> buildDebugConfigSummary(String arguments) async {
    return buildDebugConfigSummaryFromCommand(
      l10n: context.l10n,
      controller: configSnapshotController,
      cwds: currentWorkspaceCwdsProvider(),
      arguments: arguments,
    );
  }

  Future<String?> buildExperimentalSummary(String arguments) async {
    return showExperimentalFeaturesFromCommand(
      context: context,
      runner: sessionController?.experimentalFeatureRunner,
      configController: configSnapshotController,
      cwds: currentWorkspaceCwdsProvider(),
      threadId: currentThreadIdProvider(),
      arguments: arguments,
    );
  }

  Future<String?> buildMemoriesSummary(String arguments) async {
    final threadId = currentThreadIdProvider();
    return showMemoriesFromCommand(
      context: context,
      runner: sessionController?.memoryRunner,
      configController: configSnapshotController,
      cwds: currentWorkspaceCwdsProvider(),
      threadId: threadId,
      threadRaw: threadDetailController?.detail?.thread.raw ?? const {},
      arguments: arguments,
      refreshThread: threadId == null || threadDetailController == null
          ? null
          : () => threadDetailController!.readThread(
              threadId,
              includeTurns: false,
            ),
    );
  }

  Future<String?> buildRolloutSummary(String arguments) async {
    if (arguments.trim().isNotEmpty) {
      return null;
    }
    final l10n = context.l10n;
    final rolloutPath = rolloutPathFromThreadRaw(
      threadDetailController?.detail?.thread.raw ?? const {},
    );
    if (rolloutPath != null) {
      return l10n.slashCommandRolloutCurrentPath(rolloutPath);
    }
    return l10n.slashCommandRolloutPathUnavailable;
  }

  Future<String?> testApprovalRequest(String arguments) async {
    return queueTestApprovalFromCommand(
      l10n: context.l10n,
      approvalController: sessionController?.approvalController,
      threadId: currentThreadIdProvider(),
      activeTurnId: turnController?.activeTurnId,
      now: DateTime.now(),
      arguments: arguments,
    );
  }

  Future<String?> buildDiffSummary(String arguments) async {
    return buildGitDiffSummaryFromCommand(
      l10n: context.l10n,
      reader: sessionController?.gitDiffReader,
      cwds: currentWorkspaceCwdsProvider(),
      arguments: arguments,
    );
  }

  Future<String?> handleGoalCommand(String arguments) async {
    return buildThreadGoalSummaryFromCommand(
      l10n: context.l10n,
      runner: sessionController?.threadGoalRunner,
      threadId: currentThreadIdProvider(),
      arguments: arguments,
    );
  }

  Future<String?> handleReviewCommand(String arguments) async {
    return startThreadReviewFromCommand(
      l10n: context.l10n,
      runner: sessionController?.threadReviewRunner,
      turnController: turnController,
      timelineController: timelineController,
      threadDetailController: threadDetailController,
      refreshVisibleThreads: refreshVisibleThreads,
      threadId: currentThreadIdProvider(),
      arguments: arguments,
    );
  }

  Future<SlashCommandCallbackResult> approveRecentAutoReviewDenial() async {
    final runner = sessionController?.threadMutationRunner;
    final threadId = currentThreadIdProvider();
    if (runner == null || timelineController == null || threadId == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    final denial = timelineController!.latestAutoReviewDenial(
      threadId: threadId,
    );
    if (denial == null) {
      return SlashCommandCallbackResult.unavailable;
    }

    await runner.approveGuardianDeniedAction(threadId: threadId, event: denial);
    timelineController!.removeAutoReviewDenial(denial.id);
    return SlashCommandCallbackResult.executed;
  }

  Future<String?> buildBackgroundTerminalsSummary(String arguments) async {
    return buildBackgroundTerminalsSummaryFromCommand(
      l10n: context.l10n,
      runner: sessionController?.threadBackgroundTerminalRunner,
      threadId: currentThreadIdProvider(),
      arguments: arguments,
    );
  }

  Future<String?> cleanBackgroundTerminals(String arguments) async {
    return cleanBackgroundTerminalsFromCommand(
      l10n: context.l10n,
      runner: sessionController?.threadBackgroundTerminalRunner,
      threadId: currentThreadIdProvider(),
      arguments: arguments,
    );
  }

  Future<bool> copyLastResponse() async {
    final markdown = timelineController?.lastAssistantMessageMarkdown();
    if (markdown == null || markdown.isEmpty) {
      return false;
    }
    await Clipboard.setData(ClipboardData(text: markdown));
    return true;
  }

  Future<void> _refreshStatusSources() async {
    final futures = <Future<void>>[];
    final threadId = currentThreadIdProvider();
    if (threadId != null && threadDetailController != null) {
      futures.add(
        threadDetailController!.readThread(threadId, includeTurns: false),
      );
    }
    if (configSnapshotController != null) {
      futures.add(
        configSnapshotController!.refresh(
          cwd: configOverrideController?.resolved.cwd,
        ),
      );
    }
    if (accountSnapshotController != null) {
      futures.add(accountSnapshotController!.refresh());
    }
    if (accountUsageSnapshotController != null) {
      futures.add(accountUsageSnapshotController!.refresh());
    }
    await Future.wait(futures);
  }
}
