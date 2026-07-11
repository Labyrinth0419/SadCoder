import '../ssh/ssh_profile.dart';
import 'agent_logs.dart';

abstract interface class AgentLogsReader {
  Future<AgentLogsResult> readLogs(SshProfile profile, {int? tailBytes});
}
