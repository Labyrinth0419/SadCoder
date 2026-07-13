import 'package:flutter/foundation.dart';

import '../security/log_redactor.dart';
import '../ssh/ssh_profile.dart';
import 'agent_logs.dart';
import 'agent_logs_reader.dart';

typedef AgentLogsReaderProvider = AgentLogsReader? Function();
typedef AgentLogsProfileProvider = SshProfile? Function();

enum AgentLogsStatus { idle, loading, loaded, failed }

class AgentLogsController extends ChangeNotifier {
  AgentLogsController({
    required AgentLogsReaderProvider readerProvider,
    required AgentLogsProfileProvider profileProvider,
    this.tailBytes = 64 * 1024,
    this.redactor = LogRedactor.defaultRedactor,
  }) : _readerProvider = readerProvider,
       _profileProvider = profileProvider;

  final AgentLogsReaderProvider _readerProvider;
  final AgentLogsProfileProvider _profileProvider;
  final int tailBytes;
  final LogRedactor redactor;
  AgentLogsStatus _status = AgentLogsStatus.idle;
  AgentLogsResult? _result;
  Object? _error;
  int _generation = 0;

  AgentLogsStatus get status => _status;
  AgentLogsResult? get result => _result;
  Object? get error => _error;

  Future<void> refresh() async {
    final reader = _readerProvider();
    final profile = _profileProvider();
    if (reader == null || profile == null) {
      _generation++;
      _result = null;
      _setState(status: AgentLogsStatus.idle, error: null);
      return;
    }

    final generation = ++_generation;
    _setState(status: AgentLogsStatus.loading, error: null);
    try {
      final result = (await reader.readLogs(
        profile,
        tailBytes: tailBytes,
      )).redacted(redactor: redactor);
      if (generation != _generation) {
        return;
      }
      _result = result;
      _setState(status: AgentLogsStatus.loaded, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: AgentLogsStatus.failed, error: error);
    }
  }

  void _setState({required AgentLogsStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
