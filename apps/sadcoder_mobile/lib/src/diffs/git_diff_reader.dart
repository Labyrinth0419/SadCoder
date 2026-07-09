class GitDiffResult {
  const GitDiffResult({
    required this.isGitRepository,
    required this.stat,
    required this.diff,
  });

  final bool isGitRepository;
  final String stat;
  final String diff;

  bool get hasChanges => stat.trim().isNotEmpty || diff.trim().isNotEmpty;
}

abstract interface class GitDiffReader {
  Future<GitDiffResult> readDiff({String? cwd});
}
