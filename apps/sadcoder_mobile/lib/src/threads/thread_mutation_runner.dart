abstract interface class ThreadMutationRunner {
  Future<void> setThreadName({required String threadId, required String name});

  Future<void> archiveThread({required String threadId});

  Future<void> deleteThread({required String threadId});
}
