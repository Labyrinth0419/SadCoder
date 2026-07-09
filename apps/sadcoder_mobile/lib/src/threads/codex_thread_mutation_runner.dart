import '../protocol/codex_app_server_client.dart';
import 'thread_mutation_runner.dart';

class CodexThreadMutationRunner implements ThreadMutationRunner {
  const CodexThreadMutationRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<void> setThreadName({
    required String threadId,
    required String name,
  }) async {
    await _client.setThreadName(threadId: threadId, name: name);
  }
}
