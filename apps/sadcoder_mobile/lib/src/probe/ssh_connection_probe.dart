import '../ssh/dart_ssh_client_factory.dart';
import '../ssh/known_host_verifier.dart';
import '../ssh/remote_command_runner.dart';
import '../ssh/ssh_profile.dart';
import 'm0_probe_model.dart';

class DartSshConnectionProbeRunner implements SshConnectionProbeRunner {
  const DartSshConnectionProbeRunner({
    this.clientFactory = const DartSshClientFactory(),
  });

  final DartSshClientFactory clientFactory;

  @override
  Future<List<M0ProbeStepResult>> probe(SshProfile profile) async {
    final steps = <M0ProbeStepResult>[];
    final observer = SshConnectionObserver(
      onTcpConnected: () => _addOnce(
        steps,
        const M0ProbeStepResult(step: M0ProbeStep.tcpConnect, ok: true),
      ),
      onHostKeyReceived: (keyType, fingerprintSha256) => _addOnce(
        steps,
        M0ProbeStepResult(
          step: M0ProbeStep.sshHandshake,
          ok: true,
          detail: '$keyType $fingerprintSha256',
        ),
      ),
      onHostKeyVerified: (keyType, fingerprintSha256) => _addOnce(
        steps,
        M0ProbeStepResult(
          step: M0ProbeStep.hostKey,
          ok: true,
          detail: '$keyType $fingerprintSha256',
        ),
      ),
      onAuthenticated: () => _addOnce(
        steps,
        const M0ProbeStepResult(step: M0ProbeStep.auth, ok: true),
      ),
    );

    try {
      final client = await clientFactory.connect(profile, observer: observer);
      client.close();
      await client.done.catchError((_) {});
    } on KnownHostVerificationException {
      rethrow;
    } on Object catch (error) {
      if (!_hasStep(steps, M0ProbeStep.tcpConnect)) {
        steps.add(
          M0ProbeStepResult(
            step: M0ProbeStep.tcpConnect,
            ok: false,
            detail: error.toString(),
            suggestion: M0ProbeSuggestion.checkNetwork,
          ),
        );
      } else if (!_hasStep(steps, M0ProbeStep.sshHandshake)) {
        steps.add(
          M0ProbeStepResult(
            step: M0ProbeStep.sshHandshake,
            ok: false,
            detail: error.toString(),
            suggestion: M0ProbeSuggestion.checkSshServer,
          ),
        );
      } else if (!_hasStep(steps, M0ProbeStep.hostKey)) {
        steps.add(
          M0ProbeStepResult(
            step: M0ProbeStep.hostKey,
            ok: false,
            detail: error.toString(),
            suggestion: M0ProbeSuggestion.verifyHostKey,
          ),
        );
      } else {
        steps.add(
          M0ProbeStepResult(
            step: M0ProbeStep.auth,
            ok: false,
            detail: error.toString(),
            suggestion: M0ProbeSuggestion.checkAuth,
          ),
        );
      }
    }

    return steps;
  }
}

class RemoteCommandShellProbeRunner implements RemoteShellProbeRunner {
  const RemoteCommandShellProbeRunner(this._runner);

  final RemoteCommandRunner _runner;

  @override
  Future<void> probeShell(SshProfile profile) async {
    final result = await _runner.run(
      profile,
      'echo sadcoder-shell-ready',
      timeout: const Duration(seconds: 10),
    );
    if (!result.succeeded || result.stdout.trim() != 'sadcoder-shell-ready') {
      throw RemoteCommandException(
        'Remote shell probe failed with exit code ${result.exitCode}: '
        '${result.stderr.trim().isEmpty ? result.stdout : result.stderr}',
      );
    }
  }

  @override
  Future<String> readCodexVersion(SshProfile profile) async {
    final result = await _runner.run(
      profile,
      'codex --version',
      timeout: const Duration(seconds: 20),
    );
    if (!result.succeeded) {
      throw RemoteCommandException(
        'codex --version failed with exit code ${result.exitCode}: '
        '${result.stderr.trim().isEmpty ? result.stdout : result.stderr}',
      );
    }
    return result.stdout.trim();
  }
}

bool _hasStep(List<M0ProbeStepResult> steps, M0ProbeStep step) {
  return steps.any((result) => result.step == step);
}

void _addOnce(List<M0ProbeStepResult> steps, M0ProbeStepResult result) {
  if (!_hasStep(steps, result.step)) {
    steps.add(result);
  }
}
