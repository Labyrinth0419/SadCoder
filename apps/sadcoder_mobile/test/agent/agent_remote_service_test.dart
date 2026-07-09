import 'dart:io';

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
  },
  "reconnectCache": {
    "statePath": "/home/tester/.sadcoder/agent-state.json",
    "schemaVersion": 1,
    "pendingApprovals": 2,
    "recentEvents": 7,
    "loadError": null
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
    expect(
      status.reconnectCache.statePath,
      '/home/tester/.sadcoder/agent-state.json',
    );
    expect(status.reconnectCache.pendingApprovals, 2);
    expect(status.reconnectCache.recentEvents, 7);
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

  test('readSlashCommands parses shared slash command manifest JSON', () async {
    final stdout = File(
      '../../resources/slash_commands_manifest.json',
    ).readAsStringSync();
    final runner = _FakeRunner(
      result: RemoteCommandResult(exitCode: 0, stdout: stdout, stderr: ''),
    );
    final service = AgentRemoteService(runner);

    final manifest = await service.readSlashCommands(_profile);

    expect(runner.lastCommand, 'sadcoder-agent slash-commands --json');
    expect(manifest.source, 'refs/codex/codex-rs/tui/src/slash_command.rs');
    expect(manifest.commands.first.command, 'model');
    expect(manifest.asRegistry().find('/clean')?.command, 'stop');
  });

  test('readSnapshot parses pending approvals and recent events', () async {
    final runner = _FakeRunner(
      result: const RemoteCommandResult(
        exitCode: 0,
        stdout: '''
{
  "schemaVersion": 1,
  "pendingApprovals": [
    {
      "id": "approval-1",
      "method": "item/commandExecution/requestApproval",
      "params": { "command": "cargo test" }
    }
  ],
  "recentEvents": [
    {
      "method": "thread/item",
      "params": { "threadId": "thr_1" }
    }
  ]
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    final snapshot = await service.readSnapshot(_profile);

    expect(runner.lastCommand, 'sadcoder-agent snapshot --json');
    expect(snapshot.schemaVersion, 1);
    expect(snapshot.pendingApprovals.single.id, 'approval-1');
    expect(
      snapshot.pendingApprovals.single.method,
      'item/commandExecution/requestApproval',
    );
    expect(snapshot.recentEvents.single.method, 'thread/item');
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
