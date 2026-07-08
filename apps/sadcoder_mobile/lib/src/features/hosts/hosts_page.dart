import 'package:flutter/material.dart';

import '../../agent/agent_remote_service.dart';
import '../../agent/agent_status.dart';
import '../../i18n/app_localizations.dart';
import '../../probe/m0_probe_coordinator.dart';
import '../../session/codex_session_state_controller.dart';
import '../../ssh/dart_ssh_proxy_connector.dart';
import '../../ssh/dart_ssh_remote_command_runner.dart';
import '../../ssh/ssh_profile.dart';

const M0ProbeRunner _defaultProbeRunner = M0ProbeCoordinator(
  statusReader: AgentRemoteService(DartSshRemoteCommandRunner()),
  proxyConnector: DartSshProxyConnector(),
);

class HostsPage extends StatefulWidget {
  const HostsPage({super.key, this.probeRunner, this.sessionController});

  final M0ProbeRunner? probeRunner;
  final CodexSessionStateController? sessionController;

  @override
  State<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends State<HostsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _agentCommandController = TextEditingController(text: 'sadcoder-agent');

  bool _testing = false;
  M0ProbeReport? _report;
  String? _error;
  String? _connectionActionError;

  M0ProbeRunner get _runner => widget.probeRunner ?? _defaultProbeRunner;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _agentCommandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionController = widget.sessionController;
    if (sessionController == null) {
      return _buildContent(context, null);
    }
    return AnimatedBuilder(
      animation: sessionController,
      builder: (context, _) => _buildContent(context, sessionController),
    );
  }

  Widget _buildContent(
    BuildContext context,
    CodexSessionStateController? sessionController,
  ) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.hosts, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        _HostProfileForm(
          formKey: _formKey,
          nameController: _nameController,
          hostController: _hostController,
          portController: _portController,
          usernameController: _usernameController,
          passwordController: _passwordController,
          agentCommandController: _agentCommandController,
          testing: _testing,
          onTest: _runProbe,
          sessionStatus: sessionController?.status,
          onConnect: sessionController == null ? null : _connect,
          onDisconnect: sessionController == null ? null : _disconnect,
        ),
        const SizedBox(height: 12),
        if (sessionController != null) ...[
          _SessionStatusPanel(
            controller: sessionController,
            actionError: _connectionActionError,
          ),
          const SizedBox(height: 12),
        ],
        _ProbeResultPanel(testing: _testing, report: _report, error: _error),
      ],
    );
  }

  Future<void> _runProbe() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _testing = true;
      _report = null;
      _error = null;
    });

    try {
      final report = await _runner.run(_buildProfile());
      if (!mounted) {
        return;
      }
      setState(() => _report = report);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _connect() async {
    final sessionController = widget.sessionController;
    if (sessionController == null ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _connectionActionError = null);
    try {
      await sessionController.connect(_buildProfile());
    } on Object catch (error) {
      if (mounted) {
        setState(() => _connectionActionError = error.toString());
      }
    }
  }

  Future<void> _disconnect() async {
    final sessionController = widget.sessionController;
    if (sessionController == null) {
      return;
    }

    setState(() => _connectionActionError = null);
    try {
      await sessionController.disconnect();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _connectionActionError = error.toString());
      }
    }
  }

  SshProfile _buildProfile() {
    final host = _hostController.text.trim();
    final name = _nameController.text.trim();
    return SshProfile(
      id: 'manual',
      name: name.isEmpty ? host : name,
      host: host,
      port: int.tryParse(_portController.text.trim()) ?? 22,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      agentCommand: _agentCommandController.text.trim(),
    );
  }
}

class _HostProfileForm extends StatelessWidget {
  const _HostProfileForm({
    required this.formKey,
    required this.nameController,
    required this.hostController,
    required this.portController,
    required this.usernameController,
    required this.passwordController,
    required this.agentCommandController,
    required this.testing,
    required this.onTest,
    required this.sessionStatus,
    required this.onConnect,
    required this.onDisconnect,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController agentCommandController;
  final bool testing;
  final VoidCallback onTest;
  final CodexSessionStatus? sessionStatus;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.sshProfile,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('host-name-field'),
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.name,
                  prefixIcon: const Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('host-field'),
                controller: hostController,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.host,
                  prefixIcon: const Icon(Icons.dns_outlined),
                ),
                validator: _required(l10n.hostRequired),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('port-field'),
                      controller: portController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.port,
                        prefixIcon: const Icon(Icons.tag),
                      ),
                      validator: (value) =>
                          _portValidator(value, l10n.invalidPort),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: const ValueKey('username-field'),
                      controller: usernameController,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.username,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: _required(l10n.usernameRequired),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('password-field'),
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.key_outlined),
                ),
                validator: _required(l10n.passwordRequired),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('agent-command-field'),
                controller: agentCommandController,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.agentCommand,
                  prefixIcon: const Icon(Icons.terminal),
                ),
                validator: _required(l10n.agentCommandRequired),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('probe-test-button'),
                      onPressed: testing ? null : onTest,
                      icon: testing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(testing ? l10n.testing : l10n.test),
                    ),
                    if (onConnect != null && onDisconnect != null)
                      _SessionActionButton(
                        status: sessionStatus ?? CodexSessionStatus.idle,
                        onConnect: onConnect!,
                        onDisconnect: onDisconnect!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static FormFieldValidator<String> _required(String message) {
    return (value) => value == null || value.trim().isEmpty ? message : null;
  }

  static String? _portValidator(String? value, String message) {
    final port = int.tryParse(value?.trim() ?? '');
    if (port == null || port < 1 || port > 65535) {
      return message;
    }
    return null;
  }
}

class _SessionActionButton extends StatelessWidget {
  const _SessionActionButton({
    required this.status,
    required this.onConnect,
    required this.onDisconnect,
  });

  final CodexSessionStatus status;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final transitioning =
        status == CodexSessionStatus.connecting ||
        status == CodexSessionStatus.disconnecting;

    if (status == CodexSessionStatus.connected ||
        status == CodexSessionStatus.disconnecting) {
      return FilledButton.icon(
        key: const ValueKey('session-disconnect-button'),
        onPressed: transitioning ? null : onDisconnect,
        icon: transitioning
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.link_off),
        label: Text(
          status == CodexSessionStatus.disconnecting
              ? l10n.disconnecting
              : l10n.disconnect,
        ),
      );
    }

    return FilledButton.icon(
      key: const ValueKey('session-connect-button'),
      onPressed: transitioning ? null : onConnect,
      icon: transitioning
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.link),
      label: Text(
        status == CodexSessionStatus.connecting
            ? l10n.connecting
            : l10n.connect,
      ),
    );
  }
}

class _SessionStatusPanel extends StatelessWidget {
  const _SessionStatusPanel({required this.controller, this.actionError});

  final CodexSessionStateController controller;
  final String? actionError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final error = controller.error?.toString() ?? actionError;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconForState(), color: _colorForState(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.connectionStatus,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(_statusText(l10n)),
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForState() => switch (controller.status) {
    CodexSessionStatus.connected => Icons.check_circle_outline,
    CodexSessionStatus.connecting ||
    CodexSessionStatus.disconnecting => Icons.sync,
    CodexSessionStatus.failed => Icons.error_outline,
    CodexSessionStatus.idle => Icons.info_outline,
  };

  Color? _colorForState(BuildContext context) => switch (controller.status) {
    CodexSessionStatus.connected => Theme.of(context).colorScheme.primary,
    CodexSessionStatus.failed => Theme.of(context).colorScheme.error,
    CodexSessionStatus.connecting ||
    CodexSessionStatus.disconnecting ||
    CodexSessionStatus.idle => null,
  };

  String _statusText(AppLocalizations l10n) {
    final endpoint = controller.profile?.endpoint;
    return switch (controller.status) {
      CodexSessionStatus.idle => l10n.noActiveConnection,
      CodexSessionStatus.connecting =>
        endpoint == null ? l10n.connecting : '${l10n.connecting}: $endpoint',
      CodexSessionStatus.connected =>
        endpoint == null
            ? l10n.connected
            : '${l10n.activeConnection}: $endpoint',
      CodexSessionStatus.disconnecting => l10n.disconnecting,
      CodexSessionStatus.failed =>
        endpoint == null
            ? l10n.connectionFailed
            : '${l10n.connectionFailed}: $endpoint',
    };
  }
}

class _ProbeResultPanel extends StatelessWidget {
  const _ProbeResultPanel({
    required this.testing,
    required this.report,
    required this.error,
  });

  final bool testing;
  final M0ProbeReport? report;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_iconForState(), color: _colorForState(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _title(l10n),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (testing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: TextStyle(color: _colorForState(context))),
            ],
            if (report?.agentStatus != null) ...[
              const SizedBox(height: 8),
              Text(
                '${report!.agentStatus!.platformOs}/${report.agentStatus!.platformArch} - ${report.agentStatus!.codexVersion ?? report.agentStatus!.codexPath}',
              ),
              const SizedBox(height: 4),
              Text(_backendSummary(l10n, report.agentStatus!)),
              if (report.agentStatus!.backendDetail != null) ...[
                const SizedBox(height: 4),
                Text(report.agentStatus!.backendDetail!),
              ],
            ],
            if (report != null) ...[
              const SizedBox(height: 12),
              for (final step in report.steps) _ProbeStepTile(step: step),
            ],
          ],
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n) {
    if (testing) {
      return l10n.testingConnection;
    }
    if (error != null) {
      return l10n.probeFailed;
    }
    final report = this.report;
    if (report == null) {
      return l10n.notTested;
    }
    return report.ok ? l10n.probePassed : l10n.probeFailed;
  }

  IconData _iconForState() {
    if (testing) {
      return Icons.sync;
    }
    if (error != null || report?.ok == false) {
      return Icons.error_outline;
    }
    if (report?.ok == true) {
      return Icons.check_circle_outline;
    }
    return Icons.info_outline;
  }

  Color? _colorForState(BuildContext context) {
    if (error != null || report?.ok == false) {
      return Theme.of(context).colorScheme.error;
    }
    if (report?.ok == true) {
      return Theme.of(context).colorScheme.primary;
    }
    return null;
  }

  String _backendSummary(AppLocalizations l10n, AgentStatus status) {
    final kind = switch (status.backendKind) {
      BackendKind.codexAppServerDaemon => l10n.backendDaemon,
      BackendKind.codexAppServerStdio => l10n.backendStdioFallback,
      BackendKind.unknown => l10n.backendUnknown,
    };
    return '${l10n.backend}: $kind';
  }
}

class _ProbeStepTile extends StatelessWidget {
  const _ProbeStepTile({required this.step});

  final M0ProbeStepResult step;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        step.ok ? Icons.check_circle_outline : Icons.error_outline,
        color: step.ok
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
      title: Text(_labelFor(step.step, l10n)),
      subtitle: step.detail == null ? null : Text(step.detail!),
    );
  }

  static String _labelFor(M0ProbeStep step, AppLocalizations l10n) =>
      switch (step) {
        M0ProbeStep.agentStatus => l10n.agentStatus,
        M0ProbeStep.proxyConnect => l10n.proxyConnect,
        M0ProbeStep.initialize => l10n.initialize,
        M0ProbeStep.modelList => l10n.modelList,
        M0ProbeStep.threadList => l10n.threadList,
      };
}
