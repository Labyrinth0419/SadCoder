import '../protocol/codex_app_server_client.dart';
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
  Future<void> compactThread({required String threadId}) async {
    await _client.compactThread(threadId: threadId);
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
  Future<void> deleteThread({required String threadId}) async {
    await _client.deleteThread(threadId: threadId);
  }
}
