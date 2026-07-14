import 'dart:async';

import 'package:flutter/foundation.dart';

import '../events/codex_event.dart';
import 'external_agent_config_runner.dart';

enum ExternalAgentConfigImportStatus { waiting, running, completed, failed }

class ExternalAgentConfigImportController extends ChangeNotifier {
  ExternalAgentConfigImportController({Stream<CodexEvent>? events}) {
    _subscription = events?.listen(ingest);
  }

  StreamSubscription<CodexEvent>? _subscription;
  final List<CodexEvent> _pendingEvents = [];
  String? _importId;
  ExternalAgentConfigImportStatus _status =
      ExternalAgentConfigImportStatus.waiting;
  List<ExternalAgentConfigImportTypeResult> _results = const [];
  Object? _error;
  bool _disposed = false;

  String? get importId => _importId;

  ExternalAgentConfigImportStatus get status => _status;

  List<ExternalAgentConfigImportTypeResult> get results => _results;

  Object? get error => _error;

  int get successCount =>
      _results.fold(0, (count, result) => count + result.successes.length);

  int get failureCount =>
      _results.fold(0, (count, result) => count + result.failures.length);

  void track(String importId) {
    final normalized = importId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(importId, 'importId', 'must not be blank');
    }
    _importId = normalized;
    _status = ExternalAgentConfigImportStatus.running;
    _error = null;
    final pending = List<CodexEvent>.of(_pendingEvents);
    _pendingEvents.clear();
    for (final event in pending) {
      _apply(event);
    }
    _notify();
  }

  void fail(Object error) {
    _error = error;
    _status = ExternalAgentConfigImportStatus.failed;
    _notify();
  }

  void ingest(CodexEvent event) {
    if (event.kind != CodexEventKind.externalAgentConfigImportProgress &&
        event.kind != CodexEventKind.externalAgentConfigImportCompleted) {
      return;
    }
    if (_importId == null) {
      if (_pendingEvents.length == 32) {
        _pendingEvents.removeAt(0);
      }
      _pendingEvents.add(event);
      return;
    }
    if (_apply(event)) {
      _notify();
    }
  }

  bool _apply(CodexEvent event) {
    final update = ExternalAgentConfigImportUpdate.fromJson(event.payload);
    if (update == null || update.importId != _importId) {
      return false;
    }
    if (event.kind == CodexEventKind.externalAgentConfigImportCompleted) {
      _results = List.unmodifiable(update.results);
      _status = ExternalAgentConfigImportStatus.completed;
      return true;
    }
    if (_status == ExternalAgentConfigImportStatus.completed) {
      return false;
    }
    _results = _mergeResults(_results, update.results);
    return true;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _pendingEvents.clear();
    super.dispose();
  }
}

List<ExternalAgentConfigImportTypeResult> _mergeResults(
  List<ExternalAgentConfigImportTypeResult> existing,
  List<ExternalAgentConfigImportTypeResult> incoming,
) {
  final successes = <String, ExternalAgentConfigImportSuccess>{};
  final failures = <String, ExternalAgentConfigImportFailure>{};
  final rawTypes = <String>[];
  final types = <String, ExternalAgentConfigMigrationItemType>{};
  final raw = <String, Map<String, Object?>>{};
  for (final result in [...existing, ...incoming]) {
    if (!rawTypes.contains(result.rawType)) {
      rawTypes.add(result.rawType);
    }
    types[result.rawType] = result.type;
    raw[result.rawType] = result.raw;
    for (final success in result.successes) {
      successes['${result.rawType}\u0000${success.identity}'] = success;
    }
    for (final failure in result.failures) {
      failures['${result.rawType}\u0000${failure.identity}'] = failure;
    }
  }
  return List.unmodifiable([
    for (final rawType in rawTypes)
      ExternalAgentConfigImportTypeResult(
        type: types[rawType]!,
        rawType: rawType,
        successes: List.unmodifiable(
          successes.entries
              .where((entry) => entry.key.startsWith('$rawType\u0000'))
              .map((entry) => entry.value),
        ),
        failures: List.unmodifiable(
          failures.entries
              .where((entry) => entry.key.startsWith('$rawType\u0000'))
              .map((entry) => entry.value),
        ),
        raw: raw[rawType]!,
      ),
  ]);
}
