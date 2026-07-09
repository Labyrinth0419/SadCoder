import '../protocol/codex_app_server_client.dart';
import 'thread_background_terminal.dart';
import 'thread_background_terminal_runner.dart';

class CodexThreadBackgroundTerminalRunner
    implements ThreadBackgroundTerminalRunner {
  const CodexThreadBackgroundTerminalRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ThreadBackgroundTerminalPage> listTerminals({
    required String threadId,
    String? cursor,
    int? limit,
  }) async {
    final response = await _client.listThreadBackgroundTerminals(
      threadId: threadId,
      cursor: cursor,
      limit: limit,
    );
    return ThreadBackgroundTerminalPage.fromJson(response);
  }

  @override
  Future<void> cleanTerminals({required String threadId}) async {
    await _client.cleanThreadBackgroundTerminals(threadId: threadId);
  }
}
