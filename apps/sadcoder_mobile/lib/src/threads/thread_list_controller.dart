import 'package:flutter/foundation.dart';

import 'thread_list_reader.dart';
import 'thread_summary.dart';

typedef ThreadListReaderProvider = ThreadListReader? Function();

enum ThreadListStatus { idle, loading, loaded, failed }

class ThreadListController extends ChangeNotifier {
  ThreadListController({required ThreadListReaderProvider readerProvider})
    : _readerProvider = readerProvider;

  final ThreadListReaderProvider _readerProvider;
  ThreadListStatus _status = ThreadListStatus.idle;
  List<ThreadSummary> _threads = const [];
  Object? _error;
  bool _archived = false;
  int _generation = 0;

  ThreadListStatus get status => _status;
  List<ThreadSummary> get threads => _threads;
  Object? get error => _error;
  bool get archived => _archived;

  Future<void> refresh({int limit = 20, bool archived = false}) async {
    final reader = _readerProvider();
    if (reader == null) {
      _generation++;
      _setState(status: ThreadListStatus.idle, error: null);
      return;
    }

    final generation = ++_generation;
    _setState(status: ThreadListStatus.loading, error: null);
    try {
      final page = await reader.listThreads(limit: limit, archived: archived);
      if (generation != _generation) {
        return;
      }
      _archived = archived;
      _threads = page.threads;
      _setState(status: ThreadListStatus.loaded, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: ThreadListStatus.failed, error: error);
    }
  }

  bool restoreCached(List<ThreadSummary> threads) {
    final restoredThreads = [
      for (final thread in threads)
        if (thread.id.trim().isNotEmpty) thread,
    ];
    if (restoredThreads.isEmpty) {
      return false;
    }
    if (_status == ThreadListStatus.loaded &&
        !_archived &&
        _threads.length == restoredThreads.length &&
        _sameThreadIds(_threads, restoredThreads)) {
      return false;
    }

    _generation++;
    _archived = false;
    _threads = List.unmodifiable(restoredThreads);
    _setState(status: ThreadListStatus.loaded, error: null);
    return true;
  }

  bool _sameThreadIds(List<ThreadSummary> left, List<ThreadSummary> right) {
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id) {
        return false;
      }
    }
    return true;
  }

  void _setState({required ThreadListStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
