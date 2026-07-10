import '../ssh/ssh_profile.dart';
import 'codex_session_state_controller.dart';

class HostSessionSummary {
  const HostSessionSummary({required this.profile, required this.status});

  final SshProfile profile;
  final CodexSessionStatus status;
}
