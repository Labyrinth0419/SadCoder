import '../agent/agent_remote_service.dart';
import '../agent/agent_status.dart';
import '../protocol/codex_app_session.dart';
import '../protocol/json_rpc.dart';
import '../ssh/known_host_verifier.dart';
import '../ssh/ssh_profile.dart';
import '../ssh/ssh_proxy_connector.dart';
import 'm0_probe_model.dart';

export 'm0_probe_model.dart';

class M0ProbeCoordinator implements M0ProbeRunner {
  const M0ProbeCoordinator({
    required SshConnectionProbeRunner sshProbeRunner,
    required RemoteShellProbeRunner shellProbeRunner,
    required AgentStatusReader statusReader,
    AgentStartRunner? startRunner,
    required AgentProxyConnector proxyConnector,
  }) : _sshProbeRunner = sshProbeRunner,
       _shellProbeRunner = shellProbeRunner,
       _statusReader = statusReader,
       _startRunner = startRunner,
       _proxyConnector = proxyConnector;

  final SshConnectionProbeRunner _sshProbeRunner;
  final RemoteShellProbeRunner _shellProbeRunner;
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
      final sshSteps = await _sshProbeRunner.probe(profile);
      steps.addAll(sshSteps);
      if (sshSteps.any((step) => !step.ok)) {
        return M0ProbeReport(agentStatus: status, steps: steps);
      }
    } on KnownHostVerificationException {
      rethrow;
    } on Object catch (error) {
      steps.add(
        M0ProbeStepResult(
          step: M0ProbeStep.tcpConnect,
          ok: false,
          detail: error.toString(),
          suggestion: M0ProbeSuggestion.checkNetwork,
        ),
      );
      return M0ProbeReport(agentStatus: status, steps: steps);
    }

    if (!await _recordVoidStep(
      steps,
      M0ProbeStep.remoteShell,
      () => _shellProbeRunner.probeShell(profile),
      suggestion: M0ProbeSuggestion.checkRemoteShell,
    )) {
      return M0ProbeReport(agentStatus: status, steps: steps);
    }

    try {
      status = await _statusReader.readStatus(profile);
      steps.add(
        M0ProbeStepResult(
          step: M0ProbeStep.agentStatus,
          ok: true,
          detail: status.agentVersion,
          suggestion: _statusSuggestion(status),
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
          suggestion: M0ProbeSuggestion.installAgent,
        ),
      );
      return M0ProbeReport(agentStatus: status, steps: steps);
    }
    steps.add(_codexVersionStepFromStatus(status));
    if (!status.codexAvailable) {
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
      await _recordStep(
        steps,
        M0ProbeStep.threadList,
        () => client.listThreads(limit: 1),
      );

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
          suggestion: M0ProbeSuggestion.retryProxy,
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
        M0ProbeStepResult(
          step: step,
          ok: false,
          detail: error.toString(),
          suggestion: _rpcSuggestion(step),
        ),
      );
      return false;
    }
  }

  Future<bool> _recordVoidStep(
    List<M0ProbeStepResult> steps,
    M0ProbeStep step,
    Future<void> Function() action, {
    M0ProbeSuggestion? suggestion,
  }) async {
    try {
      await action();
      steps.add(M0ProbeStepResult(step: step, ok: true));
      return true;
    } on KnownHostVerificationException {
      rethrow;
    } on Object catch (error) {
      steps.add(
        M0ProbeStepResult(
          step: step,
          ok: false,
          detail: error.toString(),
          suggestion: suggestion,
        ),
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
          suggestion: started.backendState == BackendState.ready
              ? null
              : _backendSuggestion(started),
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
          suggestion: M0ProbeSuggestion.startAgent,
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

M0ProbeStepResult _codexVersionStepFromStatus(AgentStatus status) {
  final version = status.codexVersion?.trim();
  final detail = version == null || version.isEmpty
      ? status.codexPath
      : version;
  if (!status.codexAvailable) {
    return M0ProbeStepResult(
      step: M0ProbeStep.codexVersion,
      ok: false,
      detail: detail,
      suggestion: M0ProbeSuggestion.installCodex,
    );
  }
  return M0ProbeStepResult(
    step: M0ProbeStep.codexVersion,
    ok: true,
    detail: detail,
    suggestion: _codexVersionSuggestion(detail),
  );
}

M0ProbeSuggestion? _codexVersionSuggestion(String version) {
  final lower = version.toLowerCase();
  if (lower.contains('unknown') || lower.contains('deprecated')) {
    return M0ProbeSuggestion.updateCodex;
  }
  return null;
}

M0ProbeSuggestion? _statusSuggestion(AgentStatus status) {
  if (!status.codexAvailable) {
    return M0ProbeSuggestion.installCodex;
  }
  return _backendSuggestion(status);
}

M0ProbeSuggestion? _backendSuggestion(AgentStatus status) {
  if (status.backendState == BackendState.ready) {
    return null;
  }
  return switch (status.backendKind) {
    BackendKind.sadcoderAgentService => M0ProbeSuggestion.startAgent,
    BackendKind.codexAppServerDaemon => M0ProbeSuggestion.checkDaemon,
    BackendKind.codexAppServerStdio => M0ProbeSuggestion.startAgent,
    BackendKind.unknown => M0ProbeSuggestion.installAgent,
  };
}

M0ProbeSuggestion? _rpcSuggestion(M0ProbeStep step) => switch (step) {
  M0ProbeStep.accountRead => M0ProbeSuggestion.loginCodex,
  M0ProbeStep.configRead ||
  M0ProbeStep.permissionProfileList => M0ProbeSuggestion.checkCwdOrPermissions,
  _ => null,
};
