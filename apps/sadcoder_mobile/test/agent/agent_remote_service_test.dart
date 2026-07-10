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

  test('readStatus parses snake_case sadcoder-agent status JSON', () async {
    final runner = _FakeRunner(
      result: const RemoteCommandResult(
        exitCode: 0,
        stdout: '''
{
  "agent_version": "0.2.0",
  "platform_os": "windows",
  "platform_arch": "x64",
  "codex_path": "codex.exe",
  "codex_available": true,
  "codex_version": "codex-cli 0.143.0",
  "backend": {
    "kind": "codex-app-server-daemon",
    "state": "not-started",
    "detail": "daemon stopped"
  },
  "reconnect_cache": {
    "state_path": "C:/Users/tester/AppData/Local/SadCoder/agent-state.json",
    "schema_version": 2,
    "pending_approvals": 3,
    "recent_events": 9,
    "load_error": "cache warning"
  }
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    final status = await service.readStatus(_profile);

    expect(status.agentVersion, '0.2.0');
    expect(status.platformOs, 'windows');
    expect(status.platformArch, 'x64');
    expect(status.codexPath, 'codex.exe');
    expect(status.codexAvailable, true);
    expect(status.codexVersion, 'codex-cli 0.143.0');
    expect(status.backendKind, BackendKind.codexAppServerDaemon);
    expect(status.backendState, BackendState.notStarted);
    expect(status.backendDetail, 'daemon stopped');
    expect(
      status.reconnectCache.statePath,
      'C:/Users/tester/AppData/Local/SadCoder/agent-state.json',
    );
    expect(status.reconnectCache.schemaVersion, 2);
    expect(status.reconnectCache.pendingApprovals, 3);
    expect(status.reconnectCache.recentEvents, 9);
    expect(status.reconnectCache.loadError, 'cache warning');
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

  test('start runs sadcoder-agent start and parses returned status', () async {
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
    "kind": "codex-app-server-daemon",
    "state": "ready",
    "detail": "official daemon backend is running"
  },
  "reconnectCache": {
    "statePath": "/home/tester/.sadcoder/agent-state.json",
    "schemaVersion": 1,
    "pendingApprovals": 0,
    "recentEvents": 0,
    "loadError": null
  }
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    final status = await service.start(_profile);

    expect(runner.lastCommand, 'sadcoder-agent start --json');
    expect(runner.lastTimeout, const Duration(seconds: 60));
    expect(status.backendKind, BackendKind.codexAppServerDaemon);
    expect(status.backendState, BackendState.ready);
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

  test('readSnapshot parses snake_case cached payloads', () async {
    final runner = _FakeRunner(
      result: const RemoteCommandResult(
        exitCode: 0,
        stdout: '''
{
  "schema_version": 2,
  "pending_approvals": [
    {
      "id": "approval-2",
      "method": "item/fileChange/requestApproval",
      "params": { "path": "lib/main.dart" }
    }
  ],
  "recent_events": [
    {
      "method": "thread/turn/completed",
      "params": { "thread_id": "thr_2" }
    }
  ]
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    final snapshot = await service.readSnapshot(_profile);

    expect(snapshot.schemaVersion, 2);
    expect(snapshot.pendingApprovals.single.id, 'approval-2');
    expect(
      snapshot.pendingApprovals.single.method,
      'item/fileChange/requestApproval',
    );
    expect(snapshot.recentEvents.single.method, 'thread/turn/completed');
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
  Duration? lastTimeout;

  @override
  Future<RemoteCommandResult> run(
    SshProfile profile,
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    lastCommand = command;
    lastTimeout = timeout;
    return result;
  }
}
