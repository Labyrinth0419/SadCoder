import 'package:flutter/foundation.dart';

import 'thread_detail_reader.dart';
import 'thread_summary.dart';

typedef ThreadDetailReaderProvider = ThreadDetailReader? Function();

enum ThreadDetailStatus { idle, loading, loaded, failed }

class ThreadDetailController extends ChangeNotifier {
  ThreadDetailController({required ThreadDetailReaderProvider readerProvider})
    : _readerProvider = readerProvider;

  final ThreadDetailReaderProvider _readerProvider;
  ThreadDetailStatus _status = ThreadDetailStatus.idle;
  ThreadDetail? _detail;
  Object? _error;
  String? _selectedThreadId;
  int _generation = 0;

  ThreadDetailStatus get status => _status;
  ThreadDetail? get detail => _detail;
  Object? get error => _error;
  String? get selectedThreadId => _selectedThreadId;

  Future<void> readThread(String threadId, {bool includeTurns = true}) async {
    final reader = _readerProvider();
    _selectedThreadId = threadId;
    _detail = null;
    if (reader == null) {
      _generation++;
      _setState(
        status: ThreadDetailStatus.failed,
        error: StateError('No active Codex session'),
      );
      return;
    }

    final generation = ++_generation;
    _setState(status: ThreadDetailStatus.loading, error: null);
    try {
      final detail = await reader.readThread(
        threadId: threadId,
        includeTurns: includeTurns,
      );
      if (generation != _generation) {
        return;
      }
      _detail = detail;
      _setState(status: ThreadDetailStatus.loaded, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: ThreadDetailStatus.failed, error: error);
    }
  }

  bool backfillTurns({
    required String threadId,
    required List<TurnSummary> turns,
  }) {
    final detail = _detail;
    if (_selectedThreadId != threadId || detail?.thread.id != threadId) {
      return false;
    }
    _detail = detail!.withTurns(turns);
    _setState(status: ThreadDetailStatus.loaded, error: null);
    return true;
  }

  void clear() {
    _generation++;
    _selectedThreadId = null;
    _detail = null;
    _setState(status: ThreadDetailStatus.idle, error: null);
  }

  void _setState({required ThreadDetailStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
