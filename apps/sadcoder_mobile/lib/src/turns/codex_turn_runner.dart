import '../config/codex_config_overrides.dart';
import '../protocol/codex_app_server_client.dart';
import '../threads/thread_summary.dart';
import 'turn_runner.dart';
import 'turn_text_element.dart';

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
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
    List<TurnTextElement> textElements = const [],
  }) async {
    final result = await _client.startTurn(
      threadId: threadId,
      text: text,
      overrides: overrides,
      textElements: textElements,
    );
    return TurnSummary.fromTurnResponse(result);
  }

  @override
  Future<String> steerTurn({
    required String threadId,
    required String turnId,
    required String text,
    List<TurnTextElement> textElements = const [],
  }) async {
    final result = await _client.steerTurn(
      threadId: threadId,
      turnId: turnId,
      text: text,
      textElements: textElements,
    );
    final returnedTurnId = result['turnId'];
    return returnedTurnId is String ? returnedTurnId : '';
  }

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) async {
    await _client.interruptTurn(threadId: threadId, turnId: turnId);
  }
}
