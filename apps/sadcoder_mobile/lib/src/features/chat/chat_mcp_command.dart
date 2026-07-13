import '../../i18n/app_localizations.dart';
import '../../mcp/mcp_server_config_runner.dart';
import '../../mcp/mcp_server_oauth_runner.dart';
import '../../mcp/mcp_server_status_controller.dart';
import '../../mcp/mcp_server_status_reader.dart';
import 'chat_mcp_summary.dart';

sealed class ChatMcpCommand {
  const ChatMcpCommand();
}

final class ChatMcpSummaryCommand extends ChatMcpCommand {
  const ChatMcpSummaryCommand({required this.verbose});

  final bool verbose;
}

final class ChatMcpReloadCommand extends ChatMcpCommand {
  const ChatMcpReloadCommand({required this.verbose});

  final bool verbose;
}

final class ChatMcpLoginCommand extends ChatMcpCommand {
  const ChatMcpLoginCommand({required this.serverName});

  final String serverName;
}

ChatMcpCommand? parseChatMcpCommand(String arguments) {
  final parts = arguments
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return const ChatMcpSummaryCommand(verbose: false);
  }

  final command = parts.first.toLowerCase();
  if (parts.length == 1 && command == 'verbose') {
    return const ChatMcpSummaryCommand(verbose: true);
  }
  if (parts.length == 1 && (command == 'reload' || command == 'refresh')) {
    return const ChatMcpReloadCommand(verbose: false);
  }
  if (parts.length == 2 &&
      (command == 'login' || command == 'oauth' || command == 'auth')) {
    return ChatMcpLoginCommand(serverName: parts[1]);
  }
  return null;
}

Future<String?> buildMcpSummaryFromCommand({
  required AppLocalizations l10n,
  required McpServerStatusController? statusController,
  required McpServerOAuthRunner? oauthRunner,
  required McpServerConfigRunner? configRunner,
  required String? threadId,
  required String arguments,
  int limit = 25,
}) async {
  final command = parseChatMcpCommand(arguments);
  if (command == null) {
    return null;
  }

  return switch (command) {
    ChatMcpLoginCommand(:final serverName) => _startLogin(
      l10n: l10n,
      oauthRunner: oauthRunner,
      serverName: serverName,
    ),
    ChatMcpReloadCommand(:final verbose) => _reloadAndSummarize(
      l10n: l10n,
      statusController: statusController,
      configRunner: configRunner,
      threadId: threadId,
      verbose: verbose,
      limit: limit,
    ),
    ChatMcpSummaryCommand(:final verbose) => _summarize(
      l10n: l10n,
      statusController: statusController,
      threadId: threadId,
      verbose: verbose,
      limit: limit,
    ),
  };
}

Future<String?> _startLogin({
  required AppLocalizations l10n,
  required McpServerOAuthRunner? oauthRunner,
  required String serverName,
}) async {
  final runner = oauthRunner;
  if (runner == null) {
    return null;
  }
  final result = await runner.startOAuthLogin(serverName: serverName);
  return buildMcpServerOAuthLoginSummary(l10n: l10n, result: result);
}

Future<String?> _reloadAndSummarize({
  required AppLocalizations l10n,
  required McpServerStatusController? statusController,
  required McpServerConfigRunner? configRunner,
  required String? threadId,
  required bool verbose,
  required int limit,
}) async {
  final runner = configRunner;
  if (runner == null) {
    return null;
  }
  await runner.reloadMcpServers();
  return _summarize(
    l10n: l10n,
    statusController: statusController,
    threadId: threadId,
    verbose: verbose,
    limit: limit,
    prefix: l10n.mcpServersReloaded,
  );
}

Future<String> _summarize({
  required AppLocalizations l10n,
  required McpServerStatusController? statusController,
  required String? threadId,
  required bool verbose,
  required int limit,
  String? prefix,
}) async {
  final controller = statusController;
  if (controller != null) {
    await controller.refresh(
      threadId: threadId,
      limit: limit,
      detail: verbose
          ? McpServerStatusDetail.full
          : McpServerStatusDetail.toolsAndAuthOnly,
    );
  }
  final summary = buildMcpServerStatusSummary(
    l10n: l10n,
    controller: controller,
    verbose: verbose,
  );
  if (prefix != null) {
    return [prefix, summary].join('\n');
  }
  return summary;
}
