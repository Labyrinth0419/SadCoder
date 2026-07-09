abstract interface class ThreadMutationRunner {
  Future<void> setThreadName({required String threadId, required String name});
}
