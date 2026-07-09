import 'thread_background_terminal.dart';

abstract interface class ThreadBackgroundTerminalRunner {
  Future<ThreadBackgroundTerminalPage> listTerminals({
    required String threadId,
    String? cursor,
    int? limit,
  });

  Future<void> cleanTerminals({required String threadId});
}
