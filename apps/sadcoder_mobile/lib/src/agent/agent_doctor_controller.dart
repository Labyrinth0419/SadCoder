import 'package:flutter/foundation.dart';

import '../ssh/ssh_profile.dart';
import 'agent_doctor.dart';
import 'agent_doctor_reader.dart';

typedef AgentDoctorReaderProvider = AgentDoctorReader? Function();
typedef AgentDoctorProfileProvider = SshProfile? Function();

enum AgentDoctorStatus { idle, loading, loaded, failed }

class AgentDoctorController extends ChangeNotifier {
  AgentDoctorController({
    required AgentDoctorReaderProvider readerProvider,
    required AgentDoctorProfileProvider profileProvider,
  }) : _readerProvider = readerProvider,
       _profileProvider = profileProvider;

  final AgentDoctorReaderProvider _readerProvider;
  final AgentDoctorProfileProvider _profileProvider;
  AgentDoctorStatus _status = AgentDoctorStatus.idle;
  AgentDoctorResult? _result;
  Object? _error;
  int _generation = 0;

  AgentDoctorStatus get status => _status;
  AgentDoctorResult? get result => _result;
  Object? get error => _error;

  Future<void> refresh() async {
    final reader = _readerProvider();
    final profile = _profileProvider();
    if (reader == null || profile == null) {
      _generation++;
      _result = null;
      _setState(status: AgentDoctorStatus.idle, error: null);
      return;
    }

    final generation = ++_generation;
    _setState(status: AgentDoctorStatus.loading, error: null);
    try {
      final result = await reader.readDoctor(profile);
      if (generation != _generation) {
        return;
      }
      _result = result;
      _setState(status: AgentDoctorStatus.loaded, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: AgentDoctorStatus.failed, error: error);
    }
  }

  void _setState({required AgentDoctorStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
