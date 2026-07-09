import '../protocol/codex_app_server_client.dart';
import '../threads/thread_summary.dart';
import 'turn_runner.dart';

class CodexTurnRunner implements TurnRunner {
  const CodexTurnRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ThreadSummary> startThread() async {
    final result = await _client.startThread();
    return ThreadSummary.fromThreadResponse(result);
  }

  @override
  Future<ThreadSummary> resumeThread({required String threadId}) async {
    final result = await _client.resumeThread(threadId: threadId);
    return ThreadSummary.fromThreadResponse(result);
  }

  @override
  Future<TurnSummary> startTurn({
    required String threadId,
    required String text,
  }) async {
    final result = await _client.startTurn(threadId: threadId, text: text);
    return TurnSummary.fromTurnResponse(result);
  }

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    await _client.interruptTurn(threadId: threadId, turnId: turnId);
  }
}
