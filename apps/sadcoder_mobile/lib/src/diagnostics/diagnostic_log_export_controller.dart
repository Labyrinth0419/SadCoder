import 'dart:convert';

import 'package:flutter/services.dart';

import '../protocol/json_rpc_diagnostic_log.dart';

typedef DiagnosticLogEntryProvider = List<JsonRpcDiagnosticLogEntry> Function();
typedef DiagnosticLogClipboardSetter = Future<void> Function(String text);

class DiagnosticLogExportResult {
  const DiagnosticLogExportResult({
    required this.entryCount,
    required this.text,
    required this.copied,
  });

  final int entryCount;
  final String text;
  final bool copied;
}

class DiagnosticLogExportController {
  const DiagnosticLogExportController({
    required DiagnosticLogEntryProvider entriesProvider,
    DiagnosticLogClipboardSetter clipboardSetter = _setClipboardText,
  }) : _entriesProvider = entriesProvider,
       _clipboardSetter = clipboardSetter;

  final DiagnosticLogEntryProvider _entriesProvider;
  final DiagnosticLogClipboardSetter _clipboardSetter;

  int get entryCount => _entriesProvider().length;

  Future<DiagnosticLogExportResult> copyLogs() async {
    final entries = List<JsonRpcDiagnosticLogEntry>.of(_entriesProvider());
    if (entries.isEmpty) {
      return const DiagnosticLogExportResult(
        entryCount: 0,
        text: '',
        copied: false,
      );
    }

    final text = formatDiagnosticLogEntries(entries);
    await _clipboardSetter(text);
    return DiagnosticLogExportResult(
      entryCount: entries.length,
      text: text,
      copied: true,
    );
  }
}

String formatDiagnosticLogEntries(List<JsonRpcDiagnosticLogEntry> entries) {
  return entries
      .map(
        (entry) => jsonEncode({
          'capturedAt': entry.capturedAt.toUtc().toIso8601String(),
          'direction': entry.direction.name,
          'message': entry.redactedJson,
        }),
      )
      .join('\n');
}

Future<void> _setClipboardText(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}
