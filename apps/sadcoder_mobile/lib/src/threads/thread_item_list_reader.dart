import 'thread_summary.dart';

abstract interface class ThreadItemListReader {
  Future<ThreadItemsPage> listItems({
    required String threadId,
    String? turnId,
    String? cursor,
    int? limit,
    String? sortDirection,
  });
}
