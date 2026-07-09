import 'package:flutter/foundation.dart';

import 'model_list_reader.dart';

typedef ModelListReaderProvider = ModelListReader? Function();

enum ModelListStatus { idle, loading, loaded, failed }

class ModelListController extends ChangeNotifier {
  ModelListController({required ModelListReaderProvider readerProvider})
    : _readerProvider = readerProvider;

  final ModelListReaderProvider _readerProvider;
  ModelListStatus _status = ModelListStatus.idle;
  List<CodexModelSummary> _models = const [];
  Object? _error;
  int _generation = 0;

  ModelListStatus get status => _status;
  List<CodexModelSummary> get models => _models;
  Object? get error => _error;

  Future<void> refresh() async {
    final reader = _readerProvider();
    if (reader == null) {
      _generation++;
      _models = const [];
      _setState(status: ModelListStatus.idle, error: null);
      return;
    }

    final generation = ++_generation;
    _setState(status: ModelListStatus.loading, error: null);
    try {
      final page = await reader.listModels();
      if (generation != _generation) {
        return;
      }
      _models = page.models;
      _setState(status: ModelListStatus.loaded, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: ModelListStatus.failed, error: error);
    }
  }

  void _setState({required ModelListStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
