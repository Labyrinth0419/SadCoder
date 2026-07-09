import 'package:flutter/foundation.dart';

import 'codex_config_snapshot.dart';
import 'codex_config_snapshot_reader.dart';

typedef CodexConfigSnapshotReaderProvider =
    CodexConfigSnapshotReader? Function();

enum CodexConfigSnapshotStatus { idle, loading, loaded, failed }

class CodexConfigSnapshotController extends ChangeNotifier {
  CodexConfigSnapshotController({
    required CodexConfigSnapshotReaderProvider readerProvider,
  }) : _readerProvider = readerProvider;

  final CodexConfigSnapshotReaderProvider _readerProvider;
  CodexConfigSnapshotStatus _status = CodexConfigSnapshotStatus.idle;
  CodexConfigSnapshot? _snapshot;
  Object? _error;
  int _generation = 0;

  CodexConfigSnapshotStatus get status => _status;
  CodexConfigSnapshot? get snapshot => _snapshot;
  Object? get error => _error;

  Future<void> refresh({String? cwd}) async {
    final reader = _readerProvider();
    if (reader == null) {
      _generation++;
      _setState(status: CodexConfigSnapshotStatus.idle, error: null);
      return;
    }

    final generation = ++_generation;
    _setState(status: CodexConfigSnapshotStatus.loading, error: null);
    try {
      final snapshot = await reader.readConfig(cwd: cwd);
      if (generation != _generation) {
        return;
      }
      _snapshot = snapshot;
      _setState(status: CodexConfigSnapshotStatus.loaded, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: CodexConfigSnapshotStatus.failed, error: error);
    }
  }

  void _setState({required CodexConfigSnapshotStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
