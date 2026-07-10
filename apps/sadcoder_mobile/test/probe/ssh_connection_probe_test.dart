import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/probe/ssh_connection_probe.dart';
import 'package:sadcoder_mobile/src/ssh/remote_command_runner.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  test('probeShell runs a cross-platform echo command', () async {
    final runner = _RecordingCommandRunner(
      const RemoteCommandResult(
        exitCode: 0,
        stdout: 'sadcoder-shell-ready\n',
        stderr: '',
      ),
    );
    final probe = RemoteCommandShellProbeRunner(runner);

    await probe.probeShell(_profile);

    expect(runner.commands, ['echo sadcoder-shell-ready']);
    expect(runner.timeouts, [const Duration(seconds: 10)]);
  });
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

class _RecordingCommandRunner implements RemoteCommandRunner {
  _RecordingCommandRunner(this.result);

  final RemoteCommandResult result;
  final commands = <String>[];
  final timeouts = <Duration>[];

  @override
  Future<RemoteCommandResult> run(
    SshProfile profile,
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    commands.add(command);
    timeouts.add(timeout);
    return result;
  }
}
