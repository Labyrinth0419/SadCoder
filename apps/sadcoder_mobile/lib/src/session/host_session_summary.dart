import '../ssh/ssh_profile.dart';
import 'codex_session_state_controller.dart';

class HostSessionSummary {
  const HostSessionSummary({
    required this.profile,
    required this.status,
    this.selectedThreadId,
    this.selectedThreadTitle,
  });

  final SshProfile profile;
  final CodexSessionStatus status;
  final String? selectedThreadId;
  final String? selectedThreadTitle;

  String? get selectedThreadLabel {
    final title = selectedThreadTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    final threadId = selectedThreadId?.trim();
    return threadId == null || threadId.isEmpty ? null : threadId;
  }
}
