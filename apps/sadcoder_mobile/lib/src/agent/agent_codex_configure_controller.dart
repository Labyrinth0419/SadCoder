import 'package:flutter/foundation.dart';

import '../ssh/ssh_profile.dart';
import 'agent_codex_configure.dart';
import 'agent_codex_configure_runner.dart';

typedef AgentCodexConfigureRunnerProvider =
    AgentCodexConfigureRunner? Function();
typedef AgentCodexConfigureProfileProvider = SshProfile? Function();

enum AgentCodexConfigureStatus { idle, saving, saved, failed }

class AgentCodexConfigureController extends ChangeNotifier {
  AgentCodexConfigureController({
    required AgentCodexConfigureRunnerProvider runnerProvider,
    required AgentCodexConfigureProfileProvider profileProvider,
  }) : _runnerProvider = runnerProvider,
       _profileProvider = profileProvider;

  final AgentCodexConfigureRunnerProvider _runnerProvider;
  final AgentCodexConfigureProfileProvider _profileProvider;
  AgentCodexConfigureStatus _status = AgentCodexConfigureStatus.idle;
  AgentCodexConfigureResult? _result;
  Object? _error;
  int _generation = 0;

  AgentCodexConfigureStatus get status => _status;
  AgentCodexConfigureResult? get result => _result;
  Object? get error => _error;

  Future<AgentCodexConfigureResult?> configure(
    AgentCodexConfigureRequest request,
  ) async {
    final runner = _runnerProvider();
    final profile = _profileProvider();
    if (runner == null || profile == null) {
      _generation++;
      _result = null;
      _setState(status: AgentCodexConfigureStatus.idle, error: null);
      return null;
    }

    final generation = ++_generation;
    _setState(status: AgentCodexConfigureStatus.saving, error: null);
    try {
      final result = await runner.configureCodex(profile, request);
      if (generation != _generation) {
        return null;
      }
      _result = result;
      _setState(status: AgentCodexConfigureStatus.saved, error: null);
      return result;
    } on Object catch (error) {
      if (generation != _generation) {
        return null;
      }
      _setState(status: AgentCodexConfigureStatus.failed, error: error);
      return null;
    }
  }

  void _setState({required AgentCodexConfigureStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
