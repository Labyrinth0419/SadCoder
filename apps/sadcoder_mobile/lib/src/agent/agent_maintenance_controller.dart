import 'package:flutter/foundation.dart';

import '../ssh/ssh_profile.dart';
import 'agent_maintenance.dart';
import 'agent_maintenance_runner.dart';
import 'agent_remote_service.dart';
import 'agent_status.dart';

typedef AgentMaintenanceRunnerProvider = AgentMaintenanceRunner? Function();
typedef AgentMaintenanceProfileProvider = SshProfile? Function();
typedef AgentMaintenanceStartRunnerProvider = AgentStartRunner? Function();
typedef AgentMaintenanceStopRunnerProvider = AgentStopRunner? Function();

enum AgentMaintenanceStatus { idle, running, completed, failed }

class AgentMaintenanceController extends ChangeNotifier {
  AgentMaintenanceController({
    required AgentMaintenanceRunnerProvider runnerProvider,
    required AgentMaintenanceProfileProvider profileProvider,
    AgentMaintenanceStartRunnerProvider? startRunnerProvider,
    AgentMaintenanceStopRunnerProvider? stopRunnerProvider,
  }) : _runnerProvider = runnerProvider,
       _profileProvider = profileProvider,
       _startRunnerProvider = startRunnerProvider,
       _stopRunnerProvider = stopRunnerProvider;

  final AgentMaintenanceRunnerProvider _runnerProvider;
  final AgentMaintenanceProfileProvider _profileProvider;
  final AgentMaintenanceStartRunnerProvider? _startRunnerProvider;
  final AgentMaintenanceStopRunnerProvider? _stopRunnerProvider;

  AgentMaintenanceStatus _status = AgentMaintenanceStatus.idle;
  AgentMaintenanceRequest? _request;
  AgentMaintenanceResult? _result;
  Object? _error;
  bool _restartingBackend = false;
  int _generation = 0;

  AgentMaintenanceStatus get status => _status;
  AgentMaintenanceRequest? get request => _request;
  AgentMaintenanceResult? get result => _result;
  Object? get error => _error;
  bool get restartingBackend => _restartingBackend;
  bool get busy =>
      _status == AgentMaintenanceStatus.running || _restartingBackend;
  SshProfile? get profile => _profileProvider();

  Future<AgentMaintenanceResult?> run(AgentMaintenanceRequest request) async {
    final runner = _runnerProvider();
    final profile = _profileProvider();
    if (runner == null || profile == null) {
      _generation++;
      _request = request;
      _result = null;
      _setState(status: AgentMaintenanceStatus.idle, error: null);
      return null;
    }

    final generation = ++_generation;
    _request = request;
    _result = null;
    _setState(status: AgentMaintenanceStatus.running, error: null);
    try {
      final result = await runner.run(profile, request);
      if (generation != _generation) {
        return null;
      }
      _result = result;
      _setState(
        status: result.success
            ? AgentMaintenanceStatus.completed
            : AgentMaintenanceStatus.failed,
        error: null,
      );
      return result;
    } on Object catch (error) {
      if (generation != _generation) {
        return null;
      }
      _setState(status: AgentMaintenanceStatus.failed, error: error);
      return null;
    }
  }

  Future<bool> restartBackend() async {
    final startRunner = _startRunnerProvider?.call();
    final stopRunner = _stopRunnerProvider?.call();
    final profile = _profileProvider();
    if (startRunner == null || stopRunner == null || profile == null || busy) {
      return false;
    }

    _restartingBackend = true;
    _error = null;
    notifyListeners();
    try {
      await stopRunner.stop(profile);
      final status = await startRunner.start(profile);
      if (!status.codexAvailable || status.backendState != BackendState.ready) {
        throw StateError(
          status.backendDetail ?? 'Codex backend did not become ready.',
        );
      }
      return true;
    } on Object catch (error) {
      _error = error;
      return false;
    } finally {
      _restartingBackend = false;
      notifyListeners();
    }
  }

  void _setState({
    required AgentMaintenanceStatus status,
    required Object? error,
  }) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
