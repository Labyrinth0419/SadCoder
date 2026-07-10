import 'thread_summary.dart';

abstract interface class ThreadTurnListReader {
  Future<ThreadTurnsPage> listTurns({
    required String threadId,
    String? cursor,
    int? limit,
    String? sortDirection,
    String? itemsView,
  });
}
