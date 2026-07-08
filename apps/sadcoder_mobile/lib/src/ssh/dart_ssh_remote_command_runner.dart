import 'dart:convert';

import 'dart_ssh_client_factory.dart';
import 'remote_command_runner.dart';
import 'ssh_profile.dart';

class DartSshRemoteCommandRunner implements RemoteCommandRunner {
  const DartSshRemoteCommandRunner({
    this.clientFactory = const DartSshClientFactory(),
  });

  final DartSshClientFactory clientFactory;

  @override
  Future<RemoteCommandResult> run(
    SshProfile profile,
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final client = await clientFactory.connect(profile);
    try {
      final result = await client.runWithResult(command).timeout(timeout);
      return RemoteCommandResult(
        exitCode: result.exitCode,
        stdout: utf8.decode(result.stdout, allowMalformed: true),
        stderr: utf8.decode(result.stderr, allowMalformed: true),
      );
    } finally {
      client.close();
      await client.done.catchError((_) {});
    }
  }
}
