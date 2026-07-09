import '../agent/agent_remote_service.dart';
import '../agent/agent_status.dart';
import '../protocol/codex_app_session.dart';
import '../protocol/json_rpc.dart';
import '../ssh/known_host_verifier.dart';
import '../ssh/ssh_profile.dart';
import '../ssh/ssh_proxy_connector.dart';

enum M0ProbeStep {
  agentStatus,
  agentStart,
  proxyConnect,
  initialize,
  accountRead,
  modelList,
  configRead,
  permissionProfileList,
  threadList,
}

class M0ProbeStepResult {
  const M0ProbeStepResult({required this.step, required this.ok, this.detail});

  final M0ProbeStep step;
  final bool ok;
  final String? detail;
}

class M0ProbeReport {
  const M0ProbeReport({required this.steps, this.agentStatus});

  final AgentStatus? agentStatus;
  final List<M0ProbeStepResult> steps;

  bool get ok =>
      steps.every((step) => step.ok) &&
      _requiredSteps.every(
        (requiredStep) => steps.any((step) => step.step == requiredStep),
      );
}

const _requiredSteps = {
  M0ProbeStep.agentStatus,
  M0ProbeStep.proxyConnect,
  M0ProbeStep.initialize,
  M0ProbeStep.accountRead,
  M0ProbeStep.modelList,
  M0ProbeStep.configRead,
  M0ProbeStep.permissionProfileList,
  M0ProbeStep.threadList,
};

abstract interface class M0ProbeRunner {
  Future<M0ProbeReport> run(SshProfile profile);
}

class M0ProbeCoordinator implements M0ProbeRunner {
  const M0ProbeCoordinator({
    required AgentStatusReader statusReader,
    AgentStartRunner? startRunner,
    required AgentProxyConnector proxyConnector,
  }) : _statusReader = statusReader,
       _startRunner = startRunner,
       _proxyConnector = proxyConnector;

  final AgentStatusReader _statusReader;
  final AgentStartRunner? _startRunner;
  final AgentProxyConnector _proxyConnector;

  @override
  Future<M0ProbeReport> run(SshProfile profile) async {
    final steps = <M0ProbeStepResult>[];
    AgentStatus? status;
    AgentProxyConnection? connection;
    JsonRpcTransport? transport;
    CodexAppSession? session;

    try {
      status = await _statusReader.readStatus(profile);
      steps.add(
        M0ProbeStepResult(
          step: M0ProbeStep.agentStatus,
          ok: true,
          detail: status.codexVersion,
        ),
      );
    } on Object catch (error) {
      if (error is KnownHostVerificationException) {
        rethrow;
      }
      steps.add(
        M0ProbeStepResult(
          step: M0ProbeStep.agentStatus,
          ok: false,
          detail: error.toString(),
        ),
      );
      return M0ProbeReport(agentStatus: status, steps: steps);
    }

    status = await _startBackendIfNeeded(profile, status, steps);
    if (status.backendState != BackendState.ready) {
      return M0ProbeReport(agentStatus: status, steps: steps);
    }

    try {
      connection = await _proxyConnector.connect(profile);
      steps.add(
        const M0ProbeStepResult(step: M0ProbeStep.proxyConnect, ok: true),
      );
      transport = connection.asJsonRpcTransport();
      session = CodexAppSession(transport);
      final client = session.client;

      if (!await _recordStep(
        steps,
        M0ProbeStep.initialize,
        session.initialize,
      )) {
        return M0ProbeReport(agentStatus: status, steps: steps);
      }
      if (!await _recordStep(
        steps,
        M0ProbeStep.accountRead,
        client.readAccount,
      )) {
        return M0ProbeReport(agentStatus: status, steps: steps);
      }
      if (!await _recordStep(steps, M0ProbeStep.modelList, client.listModels)) {
        return M0ProbeReport(agentStatus: status, steps: steps);
      }
      if (!await _recordStep(
        steps,
        M0ProbeStep.configRead,
        client.readConfig,
      )) {
        return M0ProbeReport(agentStatus: status, steps: steps);
      }
      if (!await _recordStep(
        steps,
        M0ProbeStep.permissionProfileList,
        client.listPermissionProfiles,
      )) {
        return M0ProbeReport(agentStatus: status, steps: steps);
      }
      await _recordStep(steps, M0ProbeStep.threadList, client.listThreads);

      return M0ProbeReport(agentStatus: status, steps: steps);
    } on Object catch (error) {
      if (error is KnownHostVerificationException) {
        rethrow;
      }
      steps.add(
        M0ProbeStepResult(
          step: M0ProbeStep.proxyConnect,
          ok: false,
          detail: error.toString(),
        ),
      );
      return M0ProbeReport(agentStatus: status, steps: steps);
    } finally {
      await _closeQuietly(session?.close ?? transport?.close);
      await _closeQuietly(connection?.close);
    }
  }

  Future<bool> _recordStep(
    List<M0ProbeStepResult> steps,
    M0ProbeStep step,
    Future<Map<String, Object?>> Function() action,
  ) async {
    try {
      await action();
      steps.add(M0ProbeStepResult(step: step, ok: true));
      return true;
    } on Object catch (error) {
      steps.add(
        M0ProbeStepResult(step: step, ok: false, detail: error.toString()),
      );
      return false;
    }
  }

  Future<AgentStatus> _startBackendIfNeeded(
    SshProfile profile,
    AgentStatus status,
    List<M0ProbeStepResult> steps,
  ) async {
    final startRunner = _startRunner;
    if (startRunner == null || status.backendState != BackendState.notStarted) {
      return status;
    }

    try {
      final started = await startRunner.start(profile);
      steps.add(
        M0ProbeStepResult(
          step: M0ProbeStep.agentStart,
          ok: started.backendState == BackendState.ready,
          detail: started.backendDetail,
        ),
      );
      return started;
    } on Object catch (error) {
      if (error is KnownHostVerificationException) {
        rethrow;
      }
      steps.add(
        M0ProbeStepResult(
          step: M0ProbeStep.agentStart,
          ok: false,
          detail: error.toString(),
        ),
      );
      return status;
    }
  }

  Future<void> _closeQuietly(Future<void> Function()? close) async {
    if (close == null) {
      return;
    }
    try {
      await close();
    } catch (_) {
      // Best-effort cleanup after a failed probe.
    }
  }
}
