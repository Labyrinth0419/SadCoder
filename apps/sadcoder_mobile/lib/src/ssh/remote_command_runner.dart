import 'ssh_profile.dart';

class RemoteCommandResult {
  const RemoteCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int? exitCode;
  final String stdout;
  final String stderr;

  bool get succeeded => exitCode == 0;
}

abstract interface class RemoteCommandRunner {
  Future<RemoteCommandResult> run(
    SshProfile profile,
    String command, {
    Duration timeout,
  });
}

class RemoteCommandException implements Exception {
  const RemoteCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}
