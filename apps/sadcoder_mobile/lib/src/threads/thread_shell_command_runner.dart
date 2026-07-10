abstract interface class ThreadShellCommandRunner {
  Future<void> runShellCommand({
    required String threadId,
    required String command,
  });
}
