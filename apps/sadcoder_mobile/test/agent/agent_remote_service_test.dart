import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/agent/agent_remote_service.dart';
import 'package:sadcoder_mobile/src/agent/agent_status.dart';
import 'package:sadcoder_mobile/src/ssh/remote_command_runner.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  test('readStatus parses sadcoder-agent status JSON', () async {
    final runner = _FakeRunner(
      result: const RemoteCommandResult(
        exitCode: 0,
        stdout: '''
{
  "agentVersion": "0.1.0",
  "platformOs": "linux",
  "platformArch": "x86_64",
  "codexPath": "codex",
  "codexAvailable": true,
  "codexVersion": "codex-cli 0.142.5",
  "backend": {
    "kind": "codex-app-server-stdio",
    "state": "ready",
    "detail": "ok"
  }
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    final status = await service.readStatus(_profile);

    expect(runner.lastCommand, 'sadcoder-agent status --json');
    expect(status.codexAvailable, true);
    expect(status.backendKind, BackendKind.codexAppServerStdio);
    expect(status.backendState, BackendState.ready);
  });

  test('readStatus throws on failed command', () async {
    final service = AgentRemoteService(
      _FakeRunner(
        result: const RemoteCommandResult(
          exitCode: 127,
          stdout: '',
          stderr: 'not found',
        ),
      ),
    );

    expect(
      service.readStatus(_profile),
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

class _FakeRunner implements RemoteCommandRunner {
  _FakeRunner({required this.result});

  final RemoteCommandResult result;
  String? lastCommand;

  @override
  Future<RemoteCommandResult> run(
    SshProfile profile,
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    lastCommand = command;
    return result;
  }
}
