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

  test('readCodexVersion runs codex --version and trims stdout', () async {
    final runner = _RecordingCommandRunner(
      const RemoteCommandResult(
        exitCode: 0,
        stdout: 'codex-cli 0.142.5\n',
        stderr: '',
      ),
    );
    final probe = RemoteCommandShellProbeRunner(runner);

    final version = await probe.readCodexVersion(_profile);

    expect(version, 'codex-cli 0.142.5');
    expect(runner.commands, ['codex --version']);
    expect(runner.timeouts, [const Duration(seconds: 20)]);
  });

  test('readCodexVersion throws on failed command', () async {
    final runner = _RecordingCommandRunner(
      const RemoteCommandResult(exitCode: 127, stdout: '', stderr: 'missing'),
    );
    final probe = RemoteCommandShellProbeRunner(runner);

    await expectLater(
      probe.readCodexVersion(_profile),
      throwsA(isA<RemoteCommandException>()),
    );
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
