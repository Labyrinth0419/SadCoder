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
    expect(decoded['redactionVersion'], 1);
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

  test('exports formatted logs through the injected file saver', () async {
    final saved = <({String fileName, String text, String dialogTitle})>[];
    final controller = DiagnosticLogExportController(
      entriesProvider: () => [
        JsonRpcDiagnosticLogEntry(
          direction: JsonRpcDiagnosticLogDirection.outgoing,
          capturedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
          redactedJson: const {'method': 'turn/start'},
        ),
      ],
      fileSaver:
          ({required fileName, required text, required dialogTitle}) async {
            saved.add((
              fileName: fileName,
              text: text,
              dialogTitle: dialogTitle,
            ));
            return '/tmp/$fileName';
          },
      clock: () => DateTime.utc(2026, 7, 10, 11, 12, 13),
    );

    final result = await controller.exportLogs(
      dialogTitle: 'Export diagnostic logs',
    );

    expect(result.exported, true);
    expect(
      result.savedPath,
      '/tmp/sadcoder-diagnostic-logs-20260710-111213.jsonl',
    );
    expect(result.entryCount, 1);
    expect(
      saved.single.fileName,
      'sadcoder-diagnostic-logs-20260710-111213.jsonl',
    );
    expect(saved.single.dialogTitle, 'Export diagnostic logs');
    expect(saved.single.text, result.text);
    expect(saved.single.text, contains('"method":"turn/start"'));
  });

  test(
    'does not write diagnostic log files when no logs are captured',
    () async {
      var fileSaverCalls = 0;
      final controller = DiagnosticLogExportController(
        entriesProvider: () => const [],
        fileSaver:
            ({required fileName, required text, required dialogTitle}) async {
              fileSaverCalls++;
              return '/tmp/$fileName';
            },
      );

      final result = await controller.exportLogs(
        dialogTitle: 'Export diagnostic logs',
      );

      expect(result.exported, false);
      expect(result.entryCount, 0);
      expect(result.text, isEmpty);
      expect(fileSaverCalls, 0);
    },
  );

  test('formats diagnostic log export filenames in UTC', () {
    expect(
      diagnosticLogFileName(DateTime.parse('2026-07-10T19:12:13+08:00')),
      'sadcoder-diagnostic-logs-20260710-111213.jsonl',
    );
  });
}
