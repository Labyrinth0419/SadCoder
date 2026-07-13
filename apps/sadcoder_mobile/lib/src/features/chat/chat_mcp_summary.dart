import '../../i18n/app_localizations.dart';
import '../../mcp/mcp_server_oauth_runner.dart';
import '../../mcp/mcp_server_status_controller.dart';
import '../../mcp/mcp_server_status_reader.dart';
import 'chat_summary_formatting.dart';

String buildMcpServerStatusSummary({
  required AppLocalizations l10n,
  McpServerStatusController? controller,
  bool verbose = false,
}) {
  final lines = <String>[l10n.mcpServersStatus];
  if (controller == null) {
    lines.add(l10n.mcpServersUnavailable);
    return lines.join('\n');
  }

  if (controller.status == McpServerStatusListStatus.failed) {
    lines.add(
      chatSummaryMessageWithOptionalDetail(
        l10n,
        l10n.mcpServersLoadFailed,
        controller.error,
      ),
    );
    return lines.join('\n');
  }

  final page = controller.page;
  if (page == null) {
    lines.add(l10n.mcpServersUnavailable);
    return lines.join('\n');
  }

  if (page.servers.isEmpty) {
    lines.add(l10n.mcpServersEmpty);
    return lines.join('\n');
  }

  for (final server in page.servers) {
    lines.add(_serverSummaryLine(l10n, server));
    if (verbose) {
      lines.addAll(_serverVerboseLines(l10n, server));
    }
  }

  if (page.nextCursor != null) {
    lines.add(l10n.mcpServersMore);
  }

  return lines.join('\n');
}

String buildMcpServerOAuthLoginSummary({
  required AppLocalizations l10n,
  required McpServerOAuthLoginResult result,
}) {
  final lines = <String>[l10n.mcpServersOAuthLoginStarted(result.serverName)];
  final message = result.message;
  if (message != null) {
    lines.add(message);
  }
  final url = result.bestUrl;
  if (url != null) {
    lines.add(l10n.mcpServersOAuthUrl(url));
  }
  final userCode = result.userCode;
  if (userCode != null) {
    lines.add(l10n.mcpServersOAuthUserCode(userCode));
  }
  return lines.join('\n');
}

String _serverSummaryLine(AppLocalizations l10n, McpServerStatus server) {
  final counts = [
    '${l10n.mcpServerTools}: ${server.tools.length}',
    '${l10n.mcpServerResources}: ${server.resources.length}',
    '${l10n.mcpServerResourceTemplates}: ${server.resourceTemplates.length}',
  ].join(', ');
  final startup = _startupSummary(l10n, server);
  return [
    '${server.name}: ${l10n.mcpServerAuthStatus}: ${server.authStatus}',
    if (startup.isNotEmpty) startup,
    counts,
  ].join(', ');
}

Iterable<String> _serverVerboseLines(
  AppLocalizations l10n,
  McpServerStatus server,
) sync* {
  final info = _serverInfoSummary(server.serverInfo);
  if (info.isNotEmpty) {
    yield '  ${l10n.mcpServerInfo}: $info';
  }

  if (server.tools.isNotEmpty) {
    yield '  ${l10n.mcpServerTools}: ${server.tools.values.map((tool) => tool.label).join(', ')}';
  }
  if (server.resources.isNotEmpty) {
    yield '  ${l10n.mcpServerResources}: ${server.resources.map((resource) => resource.label).join(', ')}';
  }
  if (server.resourceTemplates.isNotEmpty) {
    yield '  ${l10n.mcpServerResourceTemplates}: ${server.resourceTemplates.map((template) => template.label).join(', ')}';
  }
}

String _startupSummary(AppLocalizations l10n, McpServerStatus server) {
  final startupStatus = server.startupStatus;
  if (startupStatus == null || startupStatus.isEmpty) {
    return '';
  }
  final parts = <String>[
    '${l10n.mcpServerStartupStatus}: $startupStatus',
    if (server.startupError != null)
      '${l10n.mcpServerStartupError}: ${server.startupError}',
    if (server.startupFailureReason != null)
      '${l10n.mcpServerStartupFailureReason}: ${server.startupFailureReason}',
  ];
  return parts.join(', ');
}

String _serverInfoSummary(McpServerInfo? info) {
  if (info == null) {
    return '';
  }
  return [
    if (info.title != null) info.title!,
    '${info.name} ${info.version}',
    if (info.description != null) info.description!,
    if (info.websiteUrl != null) info.websiteUrl!,
  ].join(', ');
}
