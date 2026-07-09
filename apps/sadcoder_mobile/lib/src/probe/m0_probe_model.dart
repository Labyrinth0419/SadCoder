import '../agent/agent_status.dart';
import '../ssh/ssh_profile.dart';

enum M0ProbeStep {
  tcpConnect,
  sshHandshake,
  hostKey,
  auth,
  remoteShell,
  codexVersion,
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

enum M0ProbeSuggestion {
  checkNetwork,
  checkSshServer,
  verifyHostKey,
  checkAuth,
  checkRemoteShell,
  installCodex,
  updateCodex,
  installAgent,
  startAgent,
  checkDaemon,
  loginCodex,
  checkCwdOrPermissions,
  retryProxy,
}

class M0ProbeStepResult {
  const M0ProbeStepResult({
    required this.step,
    required this.ok,
    this.detail,
    this.suggestion,
  });

  final M0ProbeStep step;
  final bool ok;
  final String? detail;
  final M0ProbeSuggestion? suggestion;
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
  M0ProbeStep.tcpConnect,
  M0ProbeStep.sshHandshake,
  M0ProbeStep.hostKey,
  M0ProbeStep.auth,
  M0ProbeStep.remoteShell,
  M0ProbeStep.codexVersion,
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

abstract interface class SshConnectionProbeRunner {
  Future<List<M0ProbeStepResult>> probe(SshProfile profile);
}

abstract interface class RemoteShellProbeRunner {
  Future<void> probeShell(SshProfile profile);

  Future<String> readCodexVersion(SshProfile profile);
}
