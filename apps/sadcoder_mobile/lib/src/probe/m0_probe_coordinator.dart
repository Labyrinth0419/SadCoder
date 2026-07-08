import '../agent/agent_remote_service.dart';
import '../agent/agent_status.dart';
import '../protocol/codex_app_server_client.dart';
import '../protocol/json_rpc.dart';
import '../ssh/ssh_profile.dart';
import '../ssh/ssh_proxy_connector.dart';

enum M0ProbeStep {
  agentStatus,
  proxyConnect,
  initialize,
  modelList,
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
      steps.length == M0ProbeStep.values.length &&
      steps.every((step) => step.ok);
}

class M0ProbeCoordinator {
  const M0ProbeCoordinator({
    required AgentStatusReader statusReader,
    required AgentProxyConnector proxyConnector,
  }) : _statusReader = statusReader,
       _proxyConnector = proxyConnector;

  final AgentStatusReader _statusReader;
  final AgentProxyConnector _proxyConnector;

  Future<M0ProbeReport> run(SshProfile profile) async {
    final steps = <M0ProbeStepResult>[];
    AgentStatus? status;
    AgentProxyConnection? connection;
    JsonRpcTransport? transport;

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
      steps.add(
        M0ProbeStepResult(
          step: M0ProbeStep.agentStatus,
          ok: false,
          detail: error.toString(),
        ),
      );
      return M0ProbeReport(agentStatus: status, steps: steps);
    }

    try {
      connection = await _proxyConnector.connect(profile);
      steps.add(
        const M0ProbeStepResult(step: M0ProbeStep.proxyConnect, ok: true),
      );
      transport = connection.asJsonRpcTransport();
      final client = CodexAppServerClient(transport);

      if (!await _recordStep(
        steps,
        M0ProbeStep.initialize,
        client.initialize,
      )) {
        return M0ProbeReport(agentStatus: status, steps: steps);
      }
      if (!await _recordStep(steps, M0ProbeStep.modelList, client.listModels)) {
        return M0ProbeReport(agentStatus: status, steps: steps);
      }
      await _recordStep(steps, M0ProbeStep.threadList, client.listThreads);

      return M0ProbeReport(agentStatus: status, steps: steps);
    } on Object catch (error) {
      steps.add(
        M0ProbeStepResult(
          step: M0ProbeStep.proxyConnect,
          ok: false,
          detail: error.toString(),
        ),
      );
      return M0ProbeReport(agentStatus: status, steps: steps);
    } finally {
      await _closeQuietly(transport?.close);
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
