import '../threads/thread_summary.dart';

abstract interface class TurnRunner {
  Future<ThreadSummary> startThread();

  Future<ThreadSummary> resumeThread({required String threadId});

  Future<TurnSummary> startTurn({
    required String threadId,
    required String text,
  });

  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  });
}
