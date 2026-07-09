import '../security/log_redactor.dart';

enum JsonRpcDiagnosticLogDirection { incoming, outgoing }

class JsonRpcDiagnosticLogEntry {
  const JsonRpcDiagnosticLogEntry({
    required this.direction,
    required this.capturedAt,
    required this.redactedJson,
  });

  final JsonRpcDiagnosticLogDirection direction;
  final DateTime capturedAt;
  final Map<String, Object?> redactedJson;
}

abstract interface class JsonRpcDiagnosticLogSink {
  void record({
    required JsonRpcDiagnosticLogDirection direction,
    required Map<String, Object?> message,
  });
}

class RedactingJsonRpcDiagnosticLogSink implements JsonRpcDiagnosticLogSink {
  const RedactingJsonRpcDiagnosticLogSink({
    required this.onEntry,
    this.redactor = LogRedactor.defaultRedactor,
    this.clock = DateTime.now,
  });

  final void Function(JsonRpcDiagnosticLogEntry entry) onEntry;
  final LogRedactor redactor;
  final DateTime Function() clock;

  @override
  void record({
    required JsonRpcDiagnosticLogDirection direction,
    required Map<String, Object?> message,
  }) {
    final redacted = redactor.redactValue(message);
    onEntry(
      JsonRpcDiagnosticLogEntry(
        direction: direction,
        capturedAt: clock(),
        redactedJson: _objectMap(redacted),
      ),
    );
  }
}

class RedactingJsonRpcDiagnosticLogBuffer implements JsonRpcDiagnosticLogSink {
  RedactingJsonRpcDiagnosticLogBuffer({
    this.maxEntries = 500,
    this.redactor = LogRedactor.defaultRedactor,
    this.clock = DateTime.now,
  }) : assert(maxEntries >= 0);

  final int maxEntries;
  final LogRedactor redactor;
  final DateTime Function() clock;
  final List<JsonRpcDiagnosticLogEntry> _entries = [];

  List<JsonRpcDiagnosticLogEntry> snapshot() {
    return List.unmodifiable(_entries);
  }

  void clear() {
    _entries.clear();
  }

  @override
  void record({
    required JsonRpcDiagnosticLogDirection direction,
    required Map<String, Object?> message,
  }) {
    if (maxEntries == 0) {
      return;
    }
    final redacted = redactor.redactValue(message);
    if (_entries.length == maxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(
      JsonRpcDiagnosticLogEntry(
        direction: direction,
        capturedAt: clock(),
        redactedJson: _objectMap(redacted),
      ),
    );
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return Map.unmodifiable(value);
  }
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value as Object?)),
    );
  }
  return const {};
}
