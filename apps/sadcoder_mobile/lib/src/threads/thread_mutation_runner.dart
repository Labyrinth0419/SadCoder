import '../config/codex_config_overrides.dart';
import '../events/guardian_assessment_event.dart';
import 'thread_summary.dart';

abstract interface class ThreadMutationRunner {
  Future<ThreadSummary> forkThread({
    required String threadId,
    String? lastTurnId,
    bool ephemeral = false,
  });

  Future<ThreadSummary> duplicateThread({required String threadId});

  Future<ThreadSummary> rewindThread({
    required String threadId,
    required String lastTurnId,
  });

  Future<ThreadSummary> startSideConversation({required String threadId});

  Future<void> compactThread({required String threadId});

  Future<void> updateThreadSettings({
    required String threadId,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
  });

  Future<void> approveGuardianDeniedAction({
    required String threadId,
    required GuardianAssessmentEvent event,
  });

  Future<void> setThreadName({required String threadId, required String name});

  Future<void> archiveThread({required String threadId});

  Future<ThreadSummary> unarchiveThread({required String threadId});

  Future<void> deleteThread({required String threadId});
}
