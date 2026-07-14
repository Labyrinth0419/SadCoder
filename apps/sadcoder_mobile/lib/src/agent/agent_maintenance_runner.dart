import '../ssh/ssh_profile.dart';
import 'agent_maintenance.dart';

abstract interface class AgentMaintenanceRunner {
  Future<AgentMaintenanceResult> run(
    SshProfile profile,
    AgentMaintenanceRequest request,
  );
}
