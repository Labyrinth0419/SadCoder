import 'package:flutter/foundation.dart';

import '../ssh/ssh_profile.dart';
import 'agent_schema.dart';
import 'agent_schema_reader.dart';

typedef AgentSchemaReaderProvider = AgentSchemaReader? Function();
typedef AgentSchemaProfileProvider = SshProfile? Function();

enum AgentSchemaStatus { idle, loading, loaded, failed }

class AgentSchemaController extends ChangeNotifier {
  AgentSchemaController({
    required AgentSchemaReaderProvider readerProvider,
    required AgentSchemaProfileProvider profileProvider,
  }) : _readerProvider = readerProvider,
       _profileProvider = profileProvider;

  final AgentSchemaReaderProvider _readerProvider;
  final AgentSchemaProfileProvider _profileProvider;
  AgentSchemaStatus _status = AgentSchemaStatus.idle;
  AgentSchemaResult? _result;
  Object? _error;
  int _generation = 0;

  AgentSchemaStatus get status => _status;
  AgentSchemaResult? get result => _result;
  Object? get error => _error;

  Future<void> refresh({
    bool refreshCache = false,
    bool experimental = false,
  }) async {
    final reader = _readerProvider();
    final profile = _profileProvider();
    if (reader == null || profile == null) {
      _generation++;
      _result = null;
      _setState(status: AgentSchemaStatus.idle, error: null);
      return;
    }

    final generation = ++_generation;
    _setState(status: AgentSchemaStatus.loading, error: null);
    try {
      final result = await reader.readSchema(
        profile,
        refresh: refreshCache,
        experimental: experimental,
      );
      if (generation != _generation) {
        return;
      }
      _result = result;
      _setState(status: AgentSchemaStatus.loaded, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: AgentSchemaStatus.failed, error: error);
    }
  }

  void _setState({required AgentSchemaStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
