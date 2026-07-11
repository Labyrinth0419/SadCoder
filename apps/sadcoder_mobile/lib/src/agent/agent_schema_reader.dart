import '../ssh/ssh_profile.dart';
import 'agent_schema.dart';

abstract interface class AgentSchemaReader {
  Future<AgentSchemaResult> readSchema(
    SshProfile profile, {
    bool refresh = false,
    bool experimental = false,
  });
}
