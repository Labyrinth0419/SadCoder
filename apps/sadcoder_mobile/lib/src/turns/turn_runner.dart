import '../config/codex_config_overrides.dart';
import '../threads/thread_summary.dart';

abstract interface class TurnRunner {
  Future<ThreadSummary> startThread();

  Future<ThreadSummary> resumeThread({required String threadId});

  Future<TurnSummary> startTurn({
    required String threadId,
    required String text,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
  });

  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  });
}
