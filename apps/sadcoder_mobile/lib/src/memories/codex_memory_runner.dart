import '../protocol/codex_app_server_client.dart';
import 'memory_runner.dart';

class CodexMemoryRunner implements MemoryRunner {
  const CodexMemoryRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<void> setThreadMemoryMode({
    required String threadId,
    required ThreadMemoryMode mode,
  }) async {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'threadId must not be blank',
      );
    }
    await _client.setThreadMemoryMode(
      threadId: normalizedThreadId,
      mode: mode.wireName,
    );
  }

  @override
  Future<void> resetMemory() async {
    await _client.resetMemory();
  }
}
