import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/diagnostics/diagnostic_log_export_controller.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc_diagnostic_log.dart';

void main() {
  test('formats diagnostic logs as JSON lines', () {
    final text = formatDiagnosticLogEntries([
      JsonRpcDiagnosticLogEntry(
        direction: JsonRpcDiagnosticLogDirection.outgoing,
        capturedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        redactedJson: const {
          'jsonrpc': '2.0',
          'method': 'turn/start',
          'params': {'cwd': '/repo', 'accessToken': '[REDACTED]'},
        },
      ),
    ]);

    final decoded = jsonDecode(text) as Map<String, Object?>;
    expect(decoded['capturedAt'], '2026-01-02T03:04:05.000Z');
    expect(decoded['direction'], 'outgoing');
    expect((decoded['message'] as Map)['method'], 'turn/start');
    expect(
      ((decoded['message'] as Map)['params'] as Map)['accessToken'],
      '[REDACTED]',
    );
  });

  test('copies formatted logs through the injected clipboard setter', () async {
    final copied = <String>[];
    final controller = DiagnosticLogExportController(
      entriesProvider: () => [
        JsonRpcDiagnosticLogEntry(
          direction: JsonRpcDiagnosticLogDirection.incoming,
          capturedAt: DateTime.utc(2026),
          redactedJson: const {'result': <String, Object?>{}},
        ),
      ],
      clipboardSetter: (text) async => copied.add(text),
    );

    final result = await controller.copyLogs();

    expect(result.copied, true);
    expect(result.entryCount, 1);
    expect(copied, [result.text]);
    expect(result.text, contains('"direction":"incoming"'));
  });

  test('does not write clipboard content when no logs are captured', () async {
    final copied = <String>[];
    final controller = DiagnosticLogExportController(
      entriesProvider: () => const [],
      clipboardSetter: (text) async => copied.add(text),
    );

    final result = await controller.copyLogs();

    expect(result.copied, false);
    expect(result.entryCount, 0);
    expect(result.text, isEmpty);
    expect(copied, isEmpty);
  });
}
