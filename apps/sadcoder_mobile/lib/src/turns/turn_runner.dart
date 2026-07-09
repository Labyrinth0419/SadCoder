import '../config/codex_config_overrides.dart';
import '../threads/thread_summary.dart';
import 'turn_text_element.dart';

abstract interface class TurnRunner {
  Future<ThreadSummary> startThread();

  Future<ThreadSummary> resumeThread({required String threadId});

  Future<TurnSummary> startTurn({
    required String threadId,
    required String text,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
    List<TurnTextElement> textElements = const [],
  });

  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  });
}
