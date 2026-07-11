import '../ssh/ssh_profile.dart';
import 'agent_doctor.dart';

abstract interface class AgentDoctorReader {
  Future<AgentDoctorResult> readDoctor(SshProfile profile);
}
