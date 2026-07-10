import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../protocol/json_rpc_diagnostic_log.dart';

typedef DiagnosticLogEntryProvider = List<JsonRpcDiagnosticLogEntry> Function();
typedef DiagnosticLogClipboardSetter = Future<void> Function(String text);
typedef DiagnosticLogFileSaver =
    Future<String?> Function({
      required String fileName,
      required String text,
      required String dialogTitle,
    });
typedef DiagnosticLogClock = DateTime Function();

class DiagnosticLogExportResult {
  const DiagnosticLogExportResult({
    required this.entryCount,
    required this.text,
    this.copied = false,
    this.exported = false,
    this.savedPath,
  });

  final int entryCount;
  final String text;
  final bool copied;
  final bool exported;
  final String? savedPath;
}

class DiagnosticLogExportController {
  const DiagnosticLogExportController({
    required DiagnosticLogEntryProvider entriesProvider,
    DiagnosticLogClipboardSetter clipboardSetter = _setClipboardText,
    DiagnosticLogFileSaver fileSaver = _saveDiagnosticLogFile,
    DiagnosticLogClock clock = _now,
  }) : _entriesProvider = entriesProvider,
       _clipboardSetter = clipboardSetter,
       _fileSaver = fileSaver,
       _clock = clock;

  final DiagnosticLogEntryProvider _entriesProvider;
  final DiagnosticLogClipboardSetter _clipboardSetter;
  final DiagnosticLogFileSaver _fileSaver;
  final DiagnosticLogClock _clock;

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

  Future<DiagnosticLogExportResult> exportLogs({
    required String dialogTitle,
  }) async {
    final entries = List<JsonRpcDiagnosticLogEntry>.of(_entriesProvider());
    if (entries.isEmpty) {
      return const DiagnosticLogExportResult(entryCount: 0, text: '');
    }

    final text = formatDiagnosticLogEntries(entries);
    final savedPath = await _fileSaver(
      fileName: diagnosticLogFileName(_clock()),
      text: text,
      dialogTitle: dialogTitle,
    );
    return DiagnosticLogExportResult(
      entryCount: entries.length,
      text: text,
      exported: savedPath != null,
      savedPath: savedPath,
    );
  }
}

String diagnosticLogFileName(DateTime timestamp) {
  final utc = timestamp.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  final date = [
    utc.year.toString().padLeft(4, '0'),
    two(utc.month),
    two(utc.day),
  ].join('');
  final time = [two(utc.hour), two(utc.minute), two(utc.second)].join('');
  return 'sadcoder-diagnostic-logs-$date-$time.jsonl';
}

String formatDiagnosticLogEntries(List<JsonRpcDiagnosticLogEntry> entries) {
  return entries
      .map(
        (entry) => jsonEncode({
          'capturedAt': entry.capturedAt.toUtc().toIso8601String(),
          'direction': entry.direction.name,
          'redactionVersion': entry.redactionVersion,
          'message': entry.redactedJson,
        }),
      )
      .join('\n');
}

Future<void> _setClipboardText(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}

Future<String?> _saveDiagnosticLogFile({
  required String fileName,
  required String text,
  required String dialogTitle,
}) {
  return FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: const ['jsonl'],
    bytes: Uint8List.fromList(utf8.encode('$text\n')),
  );
}

DateTime _now() => DateTime.now();
