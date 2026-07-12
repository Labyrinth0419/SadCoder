import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_mcp_summary.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_controller.dart';

void main() {
  test('MCP summary includes startup status updates', () {
    final controller = McpServerStatusController(readerProvider: () => null);
    addTearDown(controller.dispose);
    controller.ingestStartupStatusUpdated({
      'name': 'github',
      'status': 'failed',
      'error': 'missing command',
      'failureReason': 'reauthenticationRequired',
    });

    final summary = buildMcpServerStatusSummary(
      l10n: const AppLocalizations(Locale('en', 'US')),
      controller: controller,
    );

    expect(summary, contains('github'));
    expect(summary, contains('startup: failed'));
    expect(summary, contains('error: missing command'));
    expect(summary, contains('reason: reauthenticationRequired'));
  });
}
