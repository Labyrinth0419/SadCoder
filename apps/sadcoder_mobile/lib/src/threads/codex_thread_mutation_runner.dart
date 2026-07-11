import '../config/codex_config_overrides.dart';
import '../events/guardian_assessment_event.dart';
import '../protocol/codex_app_server_client.dart';
import 'side_conversation.dart';
import 'thread_mutation_runner.dart';
import 'thread_summary.dart';

class CodexThreadMutationRunner implements ThreadMutationRunner {
  const CodexThreadMutationRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ThreadSummary> forkThread({
    required String threadId,
    String? lastTurnId,
    bool ephemeral = false,
  }) async {
    final response = await _client.forkThread(
      threadId: threadId,
      lastTurnId: lastTurnId,
      ephemeral: ephemeral,
    );
    return ThreadSummary.fromThreadResponse(response);
  }

  @override
  Future<ThreadSummary> duplicateThread({required String threadId}) async {
    final response = await _client.forkThread(threadId: threadId);
    return ThreadSummary.fromThreadResponse(response);
  }

  @override
  Future<ThreadSummary> rewindThread({
    required String threadId,
    required String lastTurnId,
  }) async {
    final response = await _client.forkThread(
      threadId: threadId,
      lastTurnId: lastTurnId,
    );
    return ThreadSummary.fromThreadResponse(response);
  }

  @override
  Future<ThreadSummary> startSideConversation({
    required String threadId,
  }) async {
    final response = await _client.forkThread(
      threadId: threadId,
      ephemeral: true,
      developerInstructions: SideConversationPrompts.developerInstructions,
    );
    final sideThread = ThreadSummary.fromThreadResponse(response);
    if (sideThread.id.trim().isEmpty) {
      return sideThread;
    }
    try {
      await _client.injectThreadItems(
        threadId: sideThread.id,
        items: [SideConversationPrompts.boundaryPromptItem()],
      );
    } on Object catch (error, stackTrace) {
      try {
        await _client.deleteThread(threadId: sideThread.id);
      } on Object {
        // Preserve the injection failure; cleanup is best-effort.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    return sideThread;
  }

  @override
  Future<void> compactThread({required String threadId}) async {
    await _client.compactThread(threadId: threadId);
  }

  @override
  Future<void> updateThreadSettings({
    required String threadId,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
  }) async {
    await _client.updateThreadSettings(
      threadId: threadId,
      overrides: overrides,
    );
  }

  @override
  Future<void> approveGuardianDeniedAction({
    required String threadId,
    required GuardianAssessmentEvent event,
  }) async {
    await _client.approveGuardianDeniedAction(threadId: threadId, event: event);
  }

  @override
  Future<void> setThreadName({
    required String threadId,
    required String name,
  }) async {
    await _client.setThreadName(threadId: threadId, name: name);
  }

  @override
  Future<void> archiveThread({required String threadId}) async {
    await _client.archiveThread(threadId: threadId);
  }

  @override
  Future<ThreadSummary> unarchiveThread({required String threadId}) async {
    final response = await _client.unarchiveThread(threadId: threadId);
    return ThreadSummary.fromThreadResponse(response);
  }

  @override
  Future<void> deleteThread({required String threadId}) async {
    await _client.deleteThread(threadId: threadId);
  }
}
