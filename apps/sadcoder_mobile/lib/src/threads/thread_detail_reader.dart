import 'thread_summary.dart';

abstract interface class ThreadDetailReader {
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  });
}
