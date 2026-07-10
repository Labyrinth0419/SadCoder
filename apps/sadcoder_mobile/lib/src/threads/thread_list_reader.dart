import 'thread_summary.dart';

abstract interface class ThreadListReader {
  Future<ThreadListPage> listThreads({int limit = 20, bool archived = false});
}
