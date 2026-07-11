import '../ssh/ssh_profile.dart';
import 'agent_codex_configure.dart';

abstract interface class AgentCodexConfigureRunner {
  Future<AgentCodexConfigureResult> configureCodex(
    SshProfile profile,
    AgentCodexConfigureRequest request,
  );
}
