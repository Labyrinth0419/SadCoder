import 'package:flutter/material.dart';

import '../../agent/agent_remote_service.dart';
import '../../agent/agent_status.dart';
import '../../i18n/app_localizations.dart';
import '../../probe/m0_probe_coordinator.dart';
import '../../session/codex_session_state_controller.dart';
import '../../ssh/dart_ssh_proxy_connector.dart';
import '../../ssh/dart_ssh_remote_command_runner.dart';
import '../../ssh/ssh_profile.dart';
import '../../ssh/ssh_profile_store.dart';

const M0ProbeRunner _defaultProbeRunner = M0ProbeCoordinator(
  statusReader: AgentRemoteService(DartSshRemoteCommandRunner()),
  startRunner: AgentRemoteService(DartSshRemoteCommandRunner()),
  proxyConnector: DartSshProxyConnector(),
);

class HostsPage extends StatefulWidget {
  const HostsPage({
    super.key,
    this.probeRunner,
    this.sessionController,
    this.profileStore,
  });

  final M0ProbeRunner? probeRunner;
  final CodexSessionStateController? sessionController;
  final SshProfileStore? profileStore;

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
  final _privateKeyController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _agentCommandController = TextEditingController(text: 'sadcoder-agent');

  SshAuthType _authType = SshAuthType.password;
  bool _testing = false;
  bool _savingProfile = false;
  M0ProbeReport? _report;
  String? _error;
  String? _connectionActionError;
  String? _profileMessage;
  String? _profileError;

  M0ProbeRunner get _runner => widget.probeRunner ?? _defaultProbeRunner;

  SshProfileStore? get _profileStore => widget.profileStore;

  @override
  void initState() {
    super.initState();
    _loadSavedProfile();
  }

  @override
  void didUpdateWidget(HostsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileStore != widget.profileStore) {
      _loadSavedProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
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
          authType: _authType,
          onAuthTypeChanged: (value) => setState(() => _authType = value),
          passwordController: _passwordController,
          privateKeyController: _privateKeyController,
          passphraseController: _passphraseController,
          agentCommandController: _agentCommandController,
          testing: _testing,
          savingProfile: _savingProfile,
          onTest: _runProbe,
          onSaveProfile: _profileStore == null ? null : _saveProfile,
          sessionStatus: sessionController?.status,
          onConnect: sessionController == null ? null : _connect,
          onDisconnect: sessionController == null ? null : _disconnect,
        ),
        if (_profileMessage != null || _profileError != null) ...[
          const SizedBox(height: 8),
          Text(
            _profileError ?? _profileMessage!,
            style: TextStyle(
              color: _profileError == null
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
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

  Future<void> _loadSavedProfile() async {
    final store = _profileStore;
    if (store == null) {
      return;
    }
    try {
      final profile = await store.loadLastProfile();
      if (!mounted || profile == null) {
        return;
      }
      setState(() => _applyProfile(profile));
    } on Object catch (error) {
      if (mounted) {
        setState(() => _profileError = error.toString());
      }
    }
  }

  Future<void> _saveProfile() async {
    final store = _profileStore;
    if (store == null) {
      return;
    }
    final validationError = _profileValidationError(context.l10n);
    if (validationError != null) {
      setState(() {
        _profileMessage = null;
        _profileError = validationError;
      });
      return;
    }

    setState(() {
      _savingProfile = true;
      _profileMessage = null;
      _profileError = null;
    });

    try {
      await store.saveLastProfile(_buildProfile());
      if (mounted) {
        setState(() => _profileMessage = context.l10n.profileSaved);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _profileError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
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
      authType: _authType,
      password: _authType == SshAuthType.password
          ? _passwordController.text
          : null,
      privateKeyPem: _authType == SshAuthType.privateKey
          ? _privateKeyController.text
          : null,
      passphrase: _authType == SshAuthType.privateKey
          ? _passphraseController.text
          : null,
      agentCommand: _agentCommandController.text.trim(),
    );
  }

  void _applyProfile(SshProfile profile) {
    _nameController.text = profile.name;
    _hostController.text = profile.host;
    _portController.text = profile.port.toString();
    _usernameController.text = profile.username;
    _authType = profile.authType;
    _passwordController.text = profile.password ?? '';
    _privateKeyController.text = profile.privateKeyPem ?? '';
    _passphraseController.text = profile.passphrase ?? '';
    _agentCommandController.text = profile.agentCommand;
  }

  String? _profileValidationError(AppLocalizations l10n) {
    if (_hostController.text.trim().isEmpty) {
      return l10n.hostRequired;
    }
    if (_usernameController.text.trim().isEmpty) {
      return l10n.usernameRequired;
    }
    if (_agentCommandController.text.trim().isEmpty) {
      return l10n.agentCommandRequired;
    }
    final port = int.tryParse(_portController.text.trim());
    if (port == null || port < 1 || port > 65535) {
      return l10n.invalidPort;
    }
    return null;
  }
}

class _HostProfileForm extends StatelessWidget {
  const _HostProfileForm({
    required this.formKey,
    required this.nameController,
    required this.hostController,
    required this.portController,
    required this.usernameController,
    required this.authType,
    required this.onAuthTypeChanged,
    required this.passwordController,
    required this.privateKeyController,
    required this.passphraseController,
    required this.agentCommandController,
    required this.testing,
    required this.savingProfile,
    required this.onTest,
    required this.onSaveProfile,
    required this.sessionStatus,
    required this.onConnect,
    required this.onDisconnect,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController usernameController;
  final SshAuthType authType;
  final ValueChanged<SshAuthType> onAuthTypeChanged;
  final TextEditingController passwordController;
  final TextEditingController privateKeyController;
  final TextEditingController passphraseController;
  final TextEditingController agentCommandController;
  final bool testing;
  final bool savingProfile;
  final VoidCallback onTest;
  final VoidCallback? onSaveProfile;
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
              SegmentedButton<SshAuthType>(
                key: const ValueKey('auth-type-segmented-button'),
                segments: [
                  ButtonSegment(
                    value: SshAuthType.password,
                    icon: const Icon(Icons.password),
                    label: Text(l10n.authPassword),
                  ),
                  ButtonSegment(
                    value: SshAuthType.privateKey,
                    icon: const Icon(Icons.vpn_key_outlined),
                    label: Text(l10n.authPrivateKey),
                  ),
                ],
                selected: {authType},
                onSelectionChanged: (values) =>
                    onAuthTypeChanged(values.single),
              ),
              const SizedBox(height: 12),
              if (authType == SshAuthType.password) ...[
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
              ] else ...[
                TextFormField(
                  key: const ValueKey('private-key-field'),
                  controller: privateKeyController,
                  autocorrect: false,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: l10n.privateKey,
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                  ),
                  validator: _required(l10n.privateKeyRequired),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('passphrase-field'),
                  controller: passphraseController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.passphrase,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
              ],
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
                    if (onSaveProfile != null)
                      OutlinedButton.icon(
                        key: const ValueKey('host-save-profile-button'),
                        onPressed: savingProfile ? null : onSaveProfile,
                        icon: savingProfile
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          savingProfile ? l10n.savingProfile : l10n.saveProfile,
                        ),
                      ),
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
        status == CodexSessionStatus.reconnecting ||
        status == CodexSessionStatus.disconnecting) {
      return FilledButton.icon(
        key: const ValueKey('session-disconnect-button'),
        onPressed: status == CodexSessionStatus.disconnecting
            ? null
            : onDisconnect,
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
    CodexSessionStatus.reconnecting => Icons.sync,
    CodexSessionStatus.connecting ||
    CodexSessionStatus.disconnecting => Icons.sync,
    CodexSessionStatus.failed => Icons.error_outline,
    CodexSessionStatus.idle => Icons.info_outline,
  };

  Color? _colorForState(BuildContext context) => switch (controller.status) {
    CodexSessionStatus.connected => Theme.of(context).colorScheme.primary,
    CodexSessionStatus.failed => Theme.of(context).colorScheme.error,
    CodexSessionStatus.connecting ||
    CodexSessionStatus.reconnecting ||
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
      CodexSessionStatus.reconnecting => _reconnectingText(l10n, endpoint),
      CodexSessionStatus.disconnecting => l10n.disconnecting,
      CodexSessionStatus.failed =>
        endpoint == null
            ? l10n.connectionFailed
            : '${l10n.connectionFailed}: $endpoint',
    };
  }

  String _reconnectingText(AppLocalizations l10n, String? endpoint) {
    final delay = controller.nextReconnectDelay;
    final prefix = endpoint == null
        ? l10n.reconnecting
        : '${l10n.reconnecting}: $endpoint';
    if (delay == null) {
      return prefix;
    }
    return '$prefix (${delay.inSeconds}s)';
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
              const SizedBox(height: 4),
              Text(_reconnectCacheSummary(l10n, report.agentStatus!)),
              if (report.agentStatus!.reconnectCache.statePath.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.statePath(report.agentStatus!.reconnectCache.statePath),
                ),
              ],
              if (report.agentStatus!.reconnectCache.loadError != null) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.reconnectCacheLoadError(
                    report.agentStatus!.reconnectCache.loadError!,
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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

  String _reconnectCacheSummary(AppLocalizations l10n, AgentStatus status) {
    final cache = status.reconnectCache;
    return l10n.reconnectCacheSummary(
      cache.pendingApprovals,
      cache.recentEvents,
    );
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
        M0ProbeStep.agentStart => l10n.agentStart,
        M0ProbeStep.proxyConnect => l10n.proxyConnect,
        M0ProbeStep.initialize => l10n.initialize,
        M0ProbeStep.accountRead => l10n.accountRead,
        M0ProbeStep.modelList => l10n.modelList,
        M0ProbeStep.configRead => l10n.configRead,
        M0ProbeStep.permissionProfileList => l10n.permissionProfileList,
        M0ProbeStep.threadList => l10n.threadList,
      };
}
