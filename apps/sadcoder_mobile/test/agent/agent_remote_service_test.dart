import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/agent/agent_codex_configure.dart';
import 'package:sadcoder_mobile/src/agent/agent_remote_service.dart';
import 'package:sadcoder_mobile/src/agent/agent_schema.dart';
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
    "threads": 4,
    "deliveredCursor": "event-7",
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
    expect(status.codexFailure, isNull);
    expect(status.backendKind, BackendKind.codexAppServerStdio);
    expect(status.backendState, BackendState.ready);
    expect(
      status.reconnectCache.statePath,
      '/home/tester/.sadcoder/agent-state.json',
    );
    expect(status.reconnectCache.pendingApprovals, 2);
    expect(status.reconnectCache.recentEvents, 7);
    expect(status.reconnectCache.threads, 4);
    expect(status.reconnectCache.deliveredCursor, 'event-7');
  });

  test('readStatus parses structured Codex failure diagnostics', () async {
    final runner = _FakeRunner(
      result: const RemoteCommandResult(
        exitCode: 0,
        stdout: '''
{
  "agentVersion": "0.1.0",
  "platformOs": "linux",
  "platformArch": "x86_64",
  "codexPath": "/home/tester/.nvm/versions/node/v24/bin/codex",
  "codexAvailable": false,
  "codexFailure": {
    "kind": "runtime-not-found",
    "detail": "node: SyntaxError: Unexpected token"
  },
  "backend": {
    "kind": "unknown",
    "state": "unavailable",
    "detail": "runtime-not-found: node: SyntaxError: Unexpected token"
  }
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    final status = await service.readStatus(_profile);

    expect(status.codexAvailable, false);
    expect(status.codexFailure?.kind, 'runtime-not-found');
    expect(status.codexFailure?.detail, 'node: SyntaxError: Unexpected token');
    expect(
      status.codexFailure?.message,
      'runtime-not-found: node: SyntaxError: Unexpected token',
    );
    expect(status.backendKind, BackendKind.unknown);
    expect(status.backendState, BackendState.unavailable);
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
  "codex_failure": null,
  "backend": {
    "kind": "sadcoder-agent-service",
    "state": "not-started",
    "detail": "SadCoder service is not running"
  },
  "reconnect_cache": {
    "state_path": "C:/Users/tester/AppData/Local/SadCoder/agent-state.json",
    "schema_version": 2,
    "pending_approvals": 3,
    "recent_events": 9,
    "threads": 5,
    "delivered_cursor": "event-9",
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
    expect(status.codexFailure, isNull);
    expect(status.backendKind, BackendKind.sadcoderAgentService);
    expect(status.backendState, BackendState.notStarted);
    expect(status.backendDetail, 'SadCoder service is not running');
    expect(
      status.reconnectCache.statePath,
      'C:/Users/tester/AppData/Local/SadCoder/agent-state.json',
    );
    expect(status.reconnectCache.schemaVersion, 2);
    expect(status.reconnectCache.pendingApprovals, 3);
    expect(status.reconnectCache.recentEvents, 9);
    expect(status.reconnectCache.threads, 5);
    expect(status.reconnectCache.deliveredCursor, 'event-9');
    expect(status.reconnectCache.loadError, 'cache warning');
  });

  test('readStatus still parses legacy daemon backend JSON', () async {
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
  "backend": {
    "kind": "codex-app-server-daemon",
    "state": "not-started",
    "detail": "daemon stopped"
  }
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    final status = await service.readStatus(_profile);

    expect(status.backendKind, BackendKind.codexAppServerDaemon);
    expect(status.backendState, BackendState.notStarted);
    expect(status.backendDetail, 'daemon stopped');
  });

  test('readDoctor parses sadcoder-agent doctor JSON', () async {
    final runner = _FakeRunner(
      result: const RemoteCommandResult(
        exitCode: 0,
        stdout: '''
{
  "configPath": "/home/tester/.config/sadcoder/agent.json",
  "codex": {
    "program": "/home/tester/.nvm/versions/node/v24/bin/codex",
    "args": ["--profile", "mobile"],
    "pathPrepend": ["/home/tester/.nvm/versions/node/v24/bin"],
    "source": "config",
    "available": true,
    "version": "codex-cli 0.143.0",
    "failure": null
  },
  "status": {
    "agentVersion": "0.2.0",
    "platformOs": "linux",
    "platformArch": "x86_64",
    "codexPath": "/home/tester/.nvm/versions/node/v24/bin/codex",
    "codexAvailable": true,
    "codexVersion": "codex-cli 0.143.0",
    "backend": {
      "kind": "sadcoder-agent-service",
      "state": "ready",
      "detail": "SadCoder service is listening"
    },
    "reconnectCache": {
      "statePath": "/home/tester/.sadcoder/agent-state.json",
      "schemaVersion": 1,
      "pendingApprovals": 1,
      "recentEvents": 4,
      "threads": 2,
      "loadError": null
    }
  }
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    final doctor = await service.readDoctor(_profile);

    expect(runner.lastCommand, 'sadcoder-agent doctor --json');
    expect(runner.lastTimeout, const Duration(seconds: 20));
    expect(doctor.configPath, '/home/tester/.config/sadcoder/agent.json');
    expect(
      doctor.codex.program,
      '/home/tester/.nvm/versions/node/v24/bin/codex',
    );
    expect(doctor.codex.args, ['--profile', 'mobile']);
    expect(doctor.codex.pathPrepend, [
      '/home/tester/.nvm/versions/node/v24/bin',
    ]);
    expect(doctor.codex.source, 'config');
    expect(doctor.codex.available, true);
    expect(doctor.codex.version, 'codex-cli 0.143.0');
    expect(doctor.codex.failure, isNull);
    expect(doctor.status.backendKind, BackendKind.sadcoderAgentService);
    expect(doctor.status.backendState, BackendState.ready);
    expect(doctor.status.reconnectCache.pendingApprovals, 1);
    expect(doctor.status.reconnectCache.recentEvents, 4);
    expect(doctor.status.reconnectCache.threads, 2);
  });

  test('readLogs parses bounded sadcoder-agent service logs', () async {
    final runner = _FakeRunner(
      result: const RemoteCommandResult(
        exitCode: 0,
        stdout: '''
{
  "schemaVersion": 1,
  "maxTailBytes": 262144,
  "logs": [
    {
      "name": "app-server.stderr",
      "path": "/home/tester/.sadcoder/app-server.stderr.log",
      "exists": true,
      "sizeBytes": 4096,
      "tailBytes": 128,
      "truncated": true,
      "content": "password=hunter2\\nAuthorization: Bearer access-secret\\nlast line\\n",
      "error": "api_key=sk-abcdefghijklmnopqrstuvwxyz"
    }
  ]
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    final logs = await service.readLogs(_profile, tailBytes: 8192);

    expect(runner.lastCommand, 'sadcoder-agent logs --tail-bytes 8192 --json');
    expect(runner.lastTimeout, const Duration(seconds: 20));
    expect(logs.schemaVersion, 1);
    expect(logs.maxTailBytes, 262144);
    expect(logs.logs.single.name, 'app-server.stderr');
    expect(
      logs.logs.single.path,
      '/home/tester/.sadcoder/app-server.stderr.log',
    );
    expect(logs.logs.single.exists, true);
    expect(logs.logs.single.sizeBytes, 4096);
    expect(logs.logs.single.tailBytes, 128);
    expect(logs.logs.single.truncated, true);
    expect(logs.logs.single.content, contains('password=[REDACTED]'));
    expect(
      logs.logs.single.content,
      contains('Authorization: Bearer [REDACTED]'),
    );
    expect(logs.logs.single.content, contains('last line'));
    expect(logs.logs.single.content, isNot(contains('hunter2')));
    expect(logs.logs.single.content, isNot(contains('access-secret')));
    expect(logs.logs.single.error, 'api_key=[REDACTED]');
  });

  test('readSchema parses cached app-server schema diagnostics', () async {
    final runner = _FakeRunner(
      result: const RemoteCommandResult(
        exitCode: 0,
        stdout: '''
{
  "schemaVersion": 1,
  "source": "codex app-server generate-json-schema",
  "experimental": true,
  "generated": true,
  "cacheDir": "/home/tester/.sadcoder/app-server-schema/json-experimental",
  "metadataPath": "/home/tester/.sadcoder/app-server-schema/json-experimental/sadcoder-schema-cache.json",
  "codexVersion": "codex-cli 1.2.3",
  "generatedAtUnixMs": 9,
  "bundlePath": "/home/tester/.sadcoder/app-server-schema/json-experimental/codex_app_server_protocol.schemas.json",
  "fileCount": 2,
  "totalBytes": 128,
  "digest": "0123456789abcdef",
  "files": [
    {
      "path": "codex_app_server_protocol.schemas.json",
      "sizeBytes": 64,
      "modifiedAtUnixMs": 9,
      "digest": "abcdef0123456789"
    }
  ]
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    final schema = await service.readSchema(
      _profile,
      refresh: true,
      experimental: true,
    );

    expect(
      runner.lastCommand,
      'sadcoder-agent schema --refresh --experimental --json',
    );
    expect(runner.lastTimeout, const Duration(seconds: 60));
    expect(schema, isA<AgentSchemaResult>());
    expect(schema.experimental, true);
    expect(schema.generated, true);
    expect(schema.codexVersion, 'codex-cli 1.2.3');
    expect(schema.fileCount, 2);
    expect(schema.totalBytes, 128);
    expect(schema.digest, '0123456789abcdef');
    expect(schema.files.single.path, 'codex_app_server_protocol.schemas.json');
    expect(schema.files.single.sizeBytes, 64);
  });

  test('readSchema omits refresh flags by default', () async {
    final runner = _FakeRunner(
      result: const RemoteCommandResult(
        exitCode: 0,
        stdout: '''
{
  "schemaVersion": 1,
  "source": "codex app-server generate-json-schema",
  "experimental": false,
  "generated": false,
  "cacheDir": "/home/tester/.sadcoder/app-server-schema/json",
  "metadataPath": "/home/tester/.sadcoder/app-server-schema/json/sadcoder-schema-cache.json",
  "fileCount": 1,
  "totalBytes": 64,
  "files": [
    {
      "path": "codex_app_server_protocol.schemas.json",
      "sizeBytes": 64,
      "digest": "abcdef0123456789"
    }
  ]
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    await service.readSchema(_profile);

    expect(runner.lastCommand, 'sadcoder-agent schema --json');
  });

  test('configureCodex assembles the agent configure command', () async {
    final runner = _FakeRunner(
      result: const RemoteCommandResult(
        exitCode: 0,
        stdout: '''
{
  "configPath": "/home/tester/.config/sadcoder/agent.json",
  "codex": {
    "program": "/home/tester/.nvm/versions/node/v24/bin/codex",
    "args": ["--profile", "mobile"],
    "pathPrepend": ["/home/tester/.nvm/versions/node/v24/bin"],
    "source": "config",
    "available": true,
    "version": "codex-cli 0.143.0",
    "failure": null
  }
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    final result = await service.configureCodex(
      _profile,
      const AgentCodexConfigureRequest(
        program: '/home/tester/.nvm/versions/node/v24/bin/codex',
        args: ['--profile', 'mobile'],
        pathPrepend: ['/home/tester/.nvm/versions/node/v24/bin'],
      ),
    );

    expect(
      runner.lastCommand,
      "sadcoder-agent configure --codex '/home/tester/.nvm/versions/node/v24/bin/codex' --codex-arg '--profile' --codex-arg 'mobile' --path-prepend '/home/tester/.nvm/versions/node/v24/bin' --json",
    );
    expect(result.configPath, '/home/tester/.config/sadcoder/agent.json');
    expect(result.codex.available, true);
    expect(result.codex.version, 'codex-cli 0.143.0');
  });

  test('configureCodex rejects single quotes in remote arguments', () async {
    final service = AgentRemoteService(_FakeRunner(result: _emptyResult));

    await expectLater(
      service.configureCodex(
        _profile,
        const AgentCodexConfigureRequest(
          program: "/home/tester/.nvm/versions/node/v24/bin/codex",
          args: ["--profile", "mo'bile"],
        ),
      ),
      throwsA(isA<RemoteCommandException>()),
    );
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
    "kind": "sadcoder-agent-service",
    "state": "ready",
    "detail": "SadCoder service is listening"
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
    expect(status.backendKind, BackendKind.sadcoderAgentService);
    expect(status.backendState, BackendState.ready);
  });

  test(
    'stop runs sadcoder-agent stop and parses returned backend status',
    () async {
      final runner = _FakeRunner(
        result: const RemoteCommandResult(
          exitCode: 0,
          stdout: '''
{
  "stopped": true,
  "backend": {
    "kind": "sadcoder-agent-service",
    "state": "not-started",
    "detail": "SadCoder service is not running"
  }
}
''',
          stderr: '',
        ),
      );
      final service = AgentRemoteService(runner);

      final result = await service.stop(_profile);

      expect(runner.lastCommand, 'sadcoder-agent stop --json');
      expect(runner.lastTimeout, const Duration(seconds: 20));
      expect(result.stopped, true);
      expect(result.backendKind, BackendKind.sadcoderAgentService);
      expect(result.backendState, BackendState.notStarted);
      expect(result.backendDetail, 'SadCoder service is not running');
    },
  );

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
      "cursor": "event-1",
      "method": "thread/item",
      "params": { "threadId": "thr_1" }
    }
  ],
  "threads": [
    {
      "threadId": "thr_1",
      "lastTurnId": "turn_1",
      "lastItemId": "item_1",
      "lastEventCursor": "event-1"
    }
  ],
  "deliveredCursor": "event-1",
  "retainedCursorFloor": "event-1",
  "cursorGap": true
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
    expect(snapshot.recentEvents.single.cursor, 'event-1');
    expect(snapshot.threads.single.threadId, 'thr_1');
    expect(snapshot.threads.single.lastTurnId, 'turn_1');
    expect(snapshot.threads.single.lastItemId, 'item_1');
    expect(snapshot.threads.single.lastEventCursor, 'event-1');
    expect(snapshot.deliveredCursor, 'event-1');
    expect(snapshot.retainedCursorFloor, 'event-1');
    expect(snapshot.cursorGap, true);
  });

  test('readSnapshot passes since cursor to the agent command', () async {
    final runner = _FakeRunner(
      result: const RemoteCommandResult(
        exitCode: 0,
        stdout: '''
{
  "schemaVersion": 1,
  "pendingApprovals": [],
  "recentEvents": [],
  "deliveredCursor": "event-7"
}
''',
        stderr: '',
      ),
    );
    final service = AgentRemoteService(runner);

    await service.readSnapshot(_profile, sinceCursor: ' event-6 ');

    expect(
      runner.lastCommand,
      "sadcoder-agent snapshot --since-cursor 'event-6' --json",
    );
  });

  test('readSnapshot rejects single quotes in since cursor', () async {
    final service = AgentRemoteService(_FakeRunner(result: _emptyResult));

    expect(
      () => service.readSnapshot(_profile, sinceCursor: "event-'6"),
      throwsA(isA<RemoteCommandException>()),
    );
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
      "cursor": "event-2",
      "method": "thread/turn/completed",
      "params": { "thread_id": "thr_2" }
    }
  ],
  "threads": [
    {
      "thread_id": "thr_2",
      "last_turn_id": "turn_2",
      "last_item_id": "item_2",
      "last_event_cursor": "event-2"
    }
  ],
  "delivered_cursor": "event-2",
  "retained_cursor_floor": "event-1",
  "cursor_gap": true
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
    expect(snapshot.recentEvents.single.cursor, 'event-2');
    expect(snapshot.threads.single.threadId, 'thr_2');
    expect(snapshot.threads.single.lastTurnId, 'turn_2');
    expect(snapshot.threads.single.lastItemId, 'item_2');
    expect(snapshot.threads.single.lastEventCursor, 'event-2');
    expect(snapshot.deliveredCursor, 'event-2');
    expect(snapshot.retainedCursorFloor, 'event-1');
    expect(snapshot.cursorGap, true);
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

const _emptyResult = RemoteCommandResult(
  exitCode: 0,
  stdout:
      '{"configPath":"","codex":{"program":"codex","args":[],"pathPrepend":[],"source":"unknown","available":false},"status":{"agentVersion":"unknown","platformOs":"unknown","platformArch":"unknown","codexPath":"codex","codexAvailable":false,"backend":{"kind":"unknown","state":"unavailable"}}}',
  stderr: '',
);
