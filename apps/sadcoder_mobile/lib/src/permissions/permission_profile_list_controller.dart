import 'package:flutter/foundation.dart';

import 'permission_profile_list_reader.dart';

typedef PermissionProfileListReaderProvider =
    PermissionProfileListReader? Function();

enum PermissionProfileListStatus { idle, loading, loaded, failed }

class PermissionProfileListController extends ChangeNotifier {
  PermissionProfileListController({
    required PermissionProfileListReaderProvider readerProvider,
  }) : _readerProvider = readerProvider;

  final PermissionProfileListReaderProvider _readerProvider;
  PermissionProfileListStatus _status = PermissionProfileListStatus.idle;
  List<PermissionProfileSummary> _profiles = const [];
  Object? _error;
  int _generation = 0;

  PermissionProfileListStatus get status => _status;
  List<PermissionProfileSummary> get profiles => _profiles;
  Object? get error => _error;

  Future<void> refresh({String? cwd}) async {
    final reader = _readerProvider();
    if (reader == null) {
      _generation++;
      _profiles = const [];
      _setState(status: PermissionProfileListStatus.idle, error: null);
      return;
    }

    final generation = ++_generation;
    _setState(status: PermissionProfileListStatus.loading, error: null);
    try {
      final page = await reader.listPermissionProfiles(cwd: cwd);
      if (generation != _generation) {
        return;
      }
      _profiles = page.profiles;
      _setState(status: PermissionProfileListStatus.loaded, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: PermissionProfileListStatus.failed, error: error);
    }
  }

  void _setState({required PermissionProfileListStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
