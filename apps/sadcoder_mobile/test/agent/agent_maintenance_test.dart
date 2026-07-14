import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/agent/agent_maintenance.dart';
import 'package:sadcoder_mobile/src/agent/agent_maintenance_controller.dart';
import 'package:sadcoder_mobile/src/agent/agent_maintenance_runner.dart';
import 'package:sadcoder_mobile/src/agent/agent_remote_service.dart';
import 'package:sadcoder_mobile/src/agent/agent_status.dart';
import 'package:sadcoder_mobile/src/ssh/remote_command_runner.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  test('builds a typed cloud diff command without shell interpolation', () {
    final request = AgentMaintenanceRequest.cloudDiff(
      taskId: 'task_123',
      attempt: 2,
    );

    expect(
      request.buildCommand(_profile),
      'sadcoder-agent codex --json cloud-diff \'task_123\' --attempt 2',
    );
  });

  test('rejects unsupported shell quoting characters', () {
    expect(
      () => AgentMaintenanceRequest.cloudStatus(
        taskId: "task'123",
      ).buildCommand(_profile),
      throwsA(isA<RemoteCommandException>()),
    );
  });

  test(
    'controller records structured failed results without throwing',
    () async {
      final runner = _FakeMaintenanceRunner(
        const AgentMaintenanceResult(
          operation: 'cloud-status',
          success: false,
          exitCode: 1,
          stdout: '',
          stderr: 'ChatGPT auth is missing',
          restartRequired: false,
          requiresChatGptAuth: true,
        ),
      );
      final controller = AgentMaintenanceController(
        runnerProvider: () => runner,
        profileProvider: () => _profile,
      );
      addTearDown(controller.dispose);

      final result = await controller.run(
        const AgentMaintenanceRequest.cloudStatus(taskId: 'task_1'),
      );

      expect(result?.success, false);
      expect(controller.status, AgentMaintenanceStatus.failed);
      expect(controller.result?.requiresChatGptAuth, true);
    },
  );

  test('controller restarts backend through typed lifecycle runners', () async {
    final controller = AgentMaintenanceController(
      runnerProvider: () => _FakeMaintenanceRunner(
        const AgentMaintenanceResult(
          operation: 'update',
          success: true,
          exitCode: 0,
          stdout: '',
          stderr: '',
          restartRequired: true,
          requiresChatGptAuth: false,
        ),
      ),
      profileProvider: () => _profile,
      startRunnerProvider: () => _FakeStartRunner(),
      stopRunnerProvider: () => _FakeStopRunner(),
    );
    addTearDown(controller.dispose);

    expect(await controller.restartBackend(), true);
  });
}

const _profile = SshProfile(
  id: 'host',
  name: 'Host',
  host: 'example.test',
  username: 'codex',
);

class _FakeMaintenanceRunner implements AgentMaintenanceRunner {
  const _FakeMaintenanceRunner(this.result);

  final AgentMaintenanceResult result;

  @override
  Future<AgentMaintenanceResult> run(
    SshProfile profile,
    AgentMaintenanceRequest request,
  ) async => result;
}

class _FakeStartRunner implements AgentStartRunner {
  @override
  Future<AgentStatus> start(SshProfile profile) async => AgentStatus(
    agentVersion: '0.1.0',
    platformOs: 'linux',
    platformArch: 'x64',
    codexPath: 'codex',
    codexAvailable: true,
    backendKind: BackendKind.sadcoderAgentService,
    backendState: BackendState.ready,
  );
}

class _FakeStopRunner implements AgentStopRunner {
  @override
  Future<AgentStopResult> stop(SshProfile profile) async =>
      const AgentStopResult(
        stopped: true,
        backendKind: BackendKind.sadcoderAgentService,
        backendState: BackendState.notStarted,
      );
}
