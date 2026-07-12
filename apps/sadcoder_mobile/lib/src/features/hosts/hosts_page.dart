import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../agent/agent_remote_service.dart';
import '../../agent/agent_status.dart';
import '../../commands/slash_command_manifest_store.dart';
import '../../i18n/app_localizations.dart';
import '../../probe/m0_probe_coordinator.dart';
import '../../probe/ssh_connection_probe.dart';
import '../../session/codex_session_state_controller.dart';
import '../../session/host_session_manager.dart';
import '../../session/host_session_summary.dart';
import '../../ssh/dart_ssh_proxy_connector.dart';
import '../../ssh/dart_ssh_remote_command_runner.dart';
import '../../ssh/known_host_verifier.dart';
import '../../ssh/open_ssh_config_parser.dart';
import '../../ssh/shared_preferences_known_host_store.dart';
import '../../ssh/ssh_import_file_source.dart';
import '../../ssh/ssh_key_generator.dart';
import '../../ssh/ssh_profile.dart';
import '../../ssh/ssh_profile_store.dart';
import '../../ssh/ssh_public_key_exporter.dart';
import '../../threads/thread_cache_store.dart';
import '../../threads/thread_item_cache_store.dart';
import '../../threads/thread_timeline_cursor_store.dart';

typedef HostProfileConnector = Future<void> Function(SshProfile profile);

const M0ProbeRunner _defaultProbeRunner = M0ProbeCoordinator(
  sshProbeRunner: DartSshConnectionProbeRunner(),
  shellProbeRunner: RemoteCommandShellProbeRunner(DartSshRemoteCommandRunner()),
  statusReader: AgentRemoteService(DartSshRemoteCommandRunner()),
  startRunner: AgentRemoteService(DartSshRemoteCommandRunner()),
  proxyConnector: DartSshProxyConnector(),
);
const KnownHostVerifier _defaultKnownHostVerifier = KnownHostVerifier(
  store: SharedPreferencesKnownHostStore(),
);

class HostsPage extends StatefulWidget {
  const HostsPage({
    super.key,
    this.probeRunner,
    this.sessionController,
    this.hostSessionManager,
    this.profileStore,
    this.knownHostVerifier,
    this.importFileSource = const FilePickerSshImportFileSource(),
    this.keyGenerator = const DartSshKeyGenerator(),
    this.publicKeyExporter = const FilePickerSshPublicKeyExporter(),
    this.threadCacheStore,
    this.threadItemCacheStore,
    this.threadTimelineCursorStore,
    this.slashCommandManifestStore,
    this.hostSessions = const [],
    this.profileConnector,
  });

  final M0ProbeRunner? probeRunner;
  final CodexSessionStateController? sessionController;
  final HostSessionManager? hostSessionManager;
  final SshProfileStore? profileStore;
  final KnownHostVerifier? knownHostVerifier;
  final SshImportFileSource importFileSource;
  final SshKeyGenerator keyGenerator;
  final SshPublicKeyExporter publicKeyExporter;
  final ThreadCacheStore? threadCacheStore;
  final ThreadItemCacheStore? threadItemCacheStore;
  final ThreadTimelineCursorStore? threadTimelineCursorStore;
  final SlashCommandManifestStore? slashCommandManifestStore;
  final List<HostSessionSummary> hostSessions;
  final HostProfileConnector? profileConnector;

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
  bool _restartingBackend = false;
  bool _importingSshConfig = false;
  bool _importingPrivateKey = false;
  bool _generatingKey = false;
  bool _exportingPublicKey = false;
  GeneratedSshKeyPair? _generatedKeyPair;
  M0ProbeReport? _report;
  List<SshProfile> _profiles = const [];
  final Set<String> _collapsedHosts = {};
  String? _error;
  String? _connectionActionError;
  String? _profileMessage;
  String? _profileError;

  M0ProbeRunner get _runner => widget.probeRunner ?? _defaultProbeRunner;

  SshProfileStore? get _profileStore => widget.profileStore;

  KnownHostVerifier get _knownHostVerifier =>
      widget.knownHostVerifier ?? _defaultKnownHostVerifier;

  SshImportFileSource get _importFileSource => widget.importFileSource;

  SshKeyGenerator get _keyGenerator => widget.keyGenerator;

  SshPublicKeyExporter get _publicKeyExporter => widget.publicKeyExporter;

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
        if (_profileStore != null) ...[
          _SavedHostProfilesPanel(
            profiles: _profiles,
            collapsedHosts: _collapsedHosts,
            hostSessions: widget.hostSessions,
            onHostExpandedChanged: _setSavedHostExpanded,
            onProfileSelected: _selectProfile,
            onProfileDeleted: _deleteProfile,
          ),
          const SizedBox(height: 12),
        ],
        _HostImportActionsPanel(
          importingSshConfig: _importingSshConfig,
          importingPrivateKey: _importingPrivateKey,
          generatingKey: _generatingKey,
          exportingPublicKey: _exportingPublicKey,
          generatedKeyPair: _generatedKeyPair,
          onImportSshConfig: _importSshConfig,
          onImportPrivateKey: _importPrivateKey,
          onGenerateKey: _generateSshKey,
          onCopyPublicKey: _generatedKeyPair == null
              ? null
              : _copyGeneratedPublicKey,
          onExportPublicKey: _generatedKeyPair == null
              ? null
              : _exportGeneratedPublicKey,
        ),
        const SizedBox(height: 12),
        _HostProfileForm(
          formKey: _formKey,
          nameController: _nameController,
          hostController: _hostController,
          portController: _portController,
          usernameController: _usernameController,
          authType: _authType,
          onAuthTypeChanged: (value) => setState(() {
            _authType = value;
            if (value != SshAuthType.privateKey) {
              _generatedKeyPair = null;
            }
          }),
          passwordController: _passwordController,
          privateKeyController: _privateKeyController,
          passphraseController: _passphraseController,
          agentCommandController: _agentCommandController,
          testing: _testing,
          savingProfile: _savingProfile,
          restartingBackend: _restartingBackend,
          onTest: _runProbe,
          onSaveProfile: _profileStore == null ? null : _saveProfile,
          sessionStatus: sessionController?.status,
          onConnect:
              sessionController == null && widget.profileConnector == null
              ? null
              : _connect,
          onDisconnect: sessionController == null ? null : _disconnect,
          onRestartBackend: sessionController == null ? null : _restartBackend,
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

  Future<void> _importSshConfig() async {
    if (_importingSshConfig) {
      return;
    }
    final l10n = context.l10n;
    setState(() {
      _importingSshConfig = true;
      _profileMessage = null;
      _profileError = null;
    });

    try {
      final text = await _importFileSource.pickTextFile(
        allowedExtensions: const ['config', 'ssh', 'txt'],
        dialogTitle: l10n.importSshConfig,
      );
      if (text == null) {
        return;
      }
      final importedProfiles = const OpenSshConfigParser().parseProfiles(text);
      if (importedProfiles.isEmpty) {
        throw const FormatException('No importable SSH Host entries found.');
      }

      final store = _profileStore;
      if (store is SshProfileListStore) {
        for (final profile in importedProfiles) {
          await store.saveProfile(profile);
        }
        final profiles = await store.loadProfiles();
        if (mounted) {
          setState(() => _profiles = profiles);
        }
      } else if (store != null) {
        await store.saveLastProfile(importedProfiles.first);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _applyProfile(importedProfiles.first);
        _profileMessage = l10n.sshConfigImported(importedProfiles.length);
        _profileError = null;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() => _profileError = '${l10n.sshConfigImportFailed}: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _importingSshConfig = false);
      }
    }
  }

  Future<void> _importPrivateKey() async {
    if (_importingPrivateKey) {
      return;
    }
    final l10n = context.l10n;
    setState(() {
      _importingPrivateKey = true;
      _profileMessage = null;
      _profileError = null;
    });

    try {
      final text = await _importFileSource.pickTextFile(
        allowedExtensions: const ['pem', 'key', 'txt'],
        dialogTitle: l10n.importPrivateKeyFile,
      );
      if (text == null) {
        return;
      }
      final privateKeyPem = parseSshPrivateKeyPem(text);
      _authType = SshAuthType.privateKey;
      _privateKeyController.text = privateKeyPem;
      _generatedKeyPair = null;

      final store = _profileStore;
      final validationError = _profileValidationError(l10n);
      if (store != null && validationError == null) {
        await _persistProfile(_buildProfile());
        if (mounted) {
          setState(() {
            _profileMessage = l10n.privateKeyImportedAndSaved;
            _profileError = null;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _profileMessage = l10n.privateKeyImportNeedsProfile;
          _profileError = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _profileError = '${l10n.privateKeyImportFailed}: $error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importingPrivateKey = false);
      }
    }
  }

  Future<void> _generateSshKey(SshKeyGenerationAlgorithm algorithm) async {
    if (_generatingKey) {
      return;
    }
    final l10n = context.l10n;
    setState(() {
      _generatingKey = true;
      _profileMessage = null;
      _profileError = null;
    });

    try {
      final generated = await _keyGenerator.generate(
        algorithm: algorithm,
        comment: _sshKeyComment(),
      );
      _authType = SshAuthType.privateKey;
      _privateKeyController.text = generated.privateKeyPem;
      _generatedKeyPair = generated;

      final store = _profileStore;
      final validationError = _profileValidationError(l10n);
      if (store != null && validationError == null) {
        await _persistProfile(_buildProfile());
        if (!mounted) {
          return;
        }
        setState(() {
          _profileMessage = l10n.sshKeyGeneratedAndSaved;
          _profileError = null;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _profileMessage = l10n.sshKeyGenerationNeedsProfile;
          _profileError = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _profileError = '${l10n.sshKeyGenerationFailed}: $error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generatingKey = false);
      }
    }
  }

  Future<void> _copyGeneratedPublicKey() async {
    final publicKey = _generatedKeyPair?.publicKeyOpenSsh;
    if (publicKey == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: publicKey));
    if (!mounted) {
      return;
    }
    _showSnackBar(context.l10n.publicKeyCopied);
  }

  Future<void> _exportGeneratedPublicKey() async {
    final generated = _generatedKeyPair;
    if (generated == null || _exportingPublicKey) {
      return;
    }
    final l10n = context.l10n;
    setState(() {
      _exportingPublicKey = true;
      _profileError = null;
    });

    try {
      final savedPath = await _publicKeyExporter.exportPublicKey(
        publicKeyOpenSsh: generated.publicKeyOpenSsh,
        fileName: _publicKeyFileName(generated),
        dialogTitle: l10n.exportPublicKey,
      );
      if (!mounted || savedPath == null) {
        return;
      }
      _showSnackBar(l10n.publicKeyExported);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _profileError = '${l10n.publicKeyExportFailed}: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _exportingPublicKey = false);
      }
    }
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
      final report = await _runWithKnownHostConfirmation(
        action: () => _runner.run(_buildProfile()),
      );
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
      if (mounted) {
        setState(() => _profiles = const []);
      }
      return;
    }
    try {
      final profiles = store is SshProfileListStore
          ? await store.loadProfiles()
          : const <SshProfile>[];
      final profile = await store.loadLastProfile();
      if (!mounted) {
        return;
      }
      setState(() {
        _profiles = profiles;
        if (profile != null) {
          _applyProfile(profile);
        }
      });
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
      final profile = _buildProfile();
      await _persistProfile(profile);
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
    final connector = widget.profileConnector;
    if ((sessionController == null && connector == null) ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _connectionActionError = null);
    try {
      await _runWithKnownHostConfirmation(
        action: () {
          final profile = _buildProfile();
          if (connector != null) {
            return connector(profile);
          }
          return sessionController!.connect(profile);
        },
      );
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

  Future<void> _restartBackend() async {
    final sessionController = widget.sessionController;
    if (sessionController == null || _restartingBackend) {
      return;
    }

    setState(() {
      _restartingBackend = true;
      _connectionActionError = null;
    });
    try {
      await sessionController.restartBackend();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _connectionActionError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _restartingBackend = false);
      }
    }
  }

  SshProfile _buildProfile() {
    final host = _hostController.text.trim();
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 22;
    return SshProfile(
      id: sshProfileId(host: host, port: port, username: username),
      name: name.isEmpty ? host : name,
      host: host,
      port: port,
      username: username,
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
    _generatedKeyPair = null;
  }

  void _selectProfile(SshProfile profile) {
    setState(() {
      _applyProfile(profile);
      _profileError = null;
      _profileMessage = context.l10n.profileLoaded;
    });
  }

  void _setSavedHostExpanded(String hostKey, bool expanded) {
    setState(() {
      if (expanded) {
        _collapsedHosts.remove(hostKey);
      } else {
        _collapsedHosts.add(hostKey);
      }
    });
  }

  Future<void> _deleteProfile(SshProfile profile) async {
    final store = _profileStore;
    if (store is! SshProfileListStore) {
      return;
    }
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text(l10n.deleteSshProfileTitle),
        content: Text(l10n.deleteSshProfileBody(_profileTitle(profile))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteSshProfile),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }

    try {
      await store.deleteProfile(profile.id);
      final hostSessionManager = widget.hostSessionManager;
      if (hostSessionManager != null) {
        await hostSessionManager.closeSession(profile.id);
      } else if (widget.sessionController?.profile?.id == profile.id) {
        await widget.sessionController!.disconnect();
      }
      await _deleteProfileCaches(profile.id);
      final profiles = await store.loadProfiles();
      if (!mounted) {
        return;
      }
      setState(() {
        _profiles = profiles;
        _profileMessage = l10n.sshProfileDeleted;
        _profileError = null;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _profileMessage = null;
          _profileError = '${l10n.sshProfileDeleteFailed}: $error';
        });
      }
    }
  }

  Future<void> _deleteProfileCaches(String profileId) async {
    Future<void> deleteBestEffort(Future<void> Function() action) async {
      try {
        await action();
      } on Object {
        // Reconnect caches are best-effort local state; profile deletion should
        // not fail after the primary profile store has already been updated.
      }
    }

    final threadCacheStore = widget.threadCacheStore;
    if (threadCacheStore is ThreadCacheProfileCleaner) {
      final cleaner = threadCacheStore as ThreadCacheProfileCleaner;
      await deleteBestEffort(() => cleaner.deleteProfileCache(profileId));
    }
    final threadItemCacheStore = widget.threadItemCacheStore;
    if (threadItemCacheStore is ThreadItemCacheProfileCleaner) {
      final cleaner = threadItemCacheStore as ThreadItemCacheProfileCleaner;
      await deleteBestEffort(() => cleaner.deleteProfileItems(profileId));
    }
    final timelineCursorStore = widget.threadTimelineCursorStore;
    if (timelineCursorStore is ThreadTimelineCursorProfileCleaner) {
      final cleaner = timelineCursorStore as ThreadTimelineCursorProfileCleaner;
      await deleteBestEffort(() => cleaner.deleteProfileCursors(profileId));
    }
    final slashCommandManifestStore = widget.slashCommandManifestStore;
    if (slashCommandManifestStore is SlashCommandManifestProfileCleaner) {
      final cleaner =
          slashCommandManifestStore as SlashCommandManifestProfileCleaner;
      await deleteBestEffort(() => cleaner.deleteProfileManifests(profileId));
    }
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

  Future<void> _persistProfile(SshProfile profile) async {
    final store = _profileStore;
    if (store == null) {
      return;
    }
    if (store is SshProfileListStore) {
      await store.saveProfile(profile);
      final profiles = await store.loadProfiles();
      if (mounted) {
        setState(() => _profiles = profiles);
      }
    } else {
      await store.saveLastProfile(profile);
    }
  }

  String _sshKeyComment() {
    final username = _usernameController.text.trim();
    final host = _hostController.text.trim();
    if (username.isNotEmpty && host.isNotEmpty) {
      return '$username@$host';
    }
    if (host.isNotEmpty) {
      return host;
    }
    if (username.isNotEmpty) {
      return username;
    }
    return 'sadcoder-mobile';
  }

  String _publicKeyFileName(GeneratedSshKeyPair generated) {
    final algorithm = switch (generated.algorithm) {
      SshKeyGenerationAlgorithm.ed25519 => 'ed25519',
      SshKeyGenerationAlgorithm.rsa => 'rsa',
    };
    final parts = [
      _safeFileNamePart(_usernameController.text),
      _safeFileNamePart(_hostController.text),
    ].where((part) => part.isNotEmpty).join('_');
    final suffix = parts.isEmpty ? algorithm : '${parts}_$algorithm';
    return 'sadcoder_$suffix.pub';
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<T> _runWithKnownHostConfirmation<T>({
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } on UnknownHostKeyException catch (error) {
      final trusted = await _confirmUnknownHostKey(error);
      if (!mounted || !trusted) {
        rethrow;
      }
      await _knownHostVerifier.trustHostKey(error.challenge);
      return action();
    }
  }

  Future<bool> _confirmUnknownHostKey(UnknownHostKeyException error) async {
    final l10n = context.l10n;
    final challenge = error.challenge;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.security_outlined),
        title: Text(l10n.hostKeyConfirmTitle),
        content: SelectableText(
          l10n.hostKeyConfirmBody(
            challenge.endpoint,
            challenge.keyType,
            challenge.fingerprintSha256,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.approvalCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.hostKeyTrust),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

Map<String, List<SshProfile>> _groupProfilesByHost(List<SshProfile> profiles) {
  final grouped = <String, List<SshProfile>>{};
  for (final profile in profiles) {
    final hostKey = '${profile.host}:${profile.port}';
    grouped.putIfAbsent(hostKey, () => []).add(profile);
  }
  final sortedEntries = grouped.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return {
    for (final entry in sortedEntries)
      entry.key: List.unmodifiable(
        entry.value.toList()..sort(
          (left, right) => _profileTitle(left).compareTo(_profileTitle(right)),
        ),
      ),
  };
}

String _profileTitle(SshProfile profile) {
  final alias = profile.name.trim();
  if (alias.isNotEmpty && alias != profile.host.trim()) {
    return alias;
  }
  final host = profile.host.trim();
  return host.isEmpty ? profile.displayName : host;
}

String _hostGroupTitle(List<SshProfile> profiles, String fallback) {
  final aliases = <String>{};
  for (final profile in profiles) {
    final alias = profile.name.trim();
    if (alias.isNotEmpty && alias != profile.host.trim()) {
      aliases.add(alias);
    }
  }
  if (aliases.isEmpty) {
    final host = profiles.isEmpty ? '' : profiles.first.host.trim();
    return host.isEmpty ? fallback : host;
  }
  final visibleAliases = aliases.take(2).join(', ');
  final remaining = aliases.length - 2;
  return remaining > 0 ? '$visibleAliases, +$remaining' : visibleAliases;
}

String _profileSubtitle(AppLocalizations l10n, SshProfile profile) {
  final username = profile.username.trim();
  final auth = _authLabel(l10n, profile.authType);
  return username.isEmpty ? auth : '$username | $auth';
}

String _safeFileNamePart(String value) {
  return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
}

String _authLabel(AppLocalizations l10n, SshAuthType authType) {
  return switch (authType) {
    SshAuthType.password => l10n.authPassword,
    SshAuthType.privateKey => l10n.authPrivateKey,
  };
}

IconData _authIcon(SshAuthType authType) {
  return switch (authType) {
    SshAuthType.password => Icons.password,
    SshAuthType.privateKey => Icons.vpn_key_outlined,
  };
}

class _SavedHostProfilesPanel extends StatelessWidget {
  const _SavedHostProfilesPanel({
    required this.profiles,
    required this.collapsedHosts,
    required this.hostSessions,
    required this.onHostExpandedChanged,
    required this.onProfileSelected,
    required this.onProfileDeleted,
  });

  final List<SshProfile> profiles;
  final Set<String> collapsedHosts;
  final List<HostSessionSummary> hostSessions;
  final void Function(String hostKey, bool expanded) onHostExpandedChanged;
  final ValueChanged<SshProfile> onProfileSelected;
  final ValueChanged<SshProfile> onProfileDeleted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupedProfiles = _groupProfilesByHost(profiles);
    final statusByProfileId = {
      for (final session in hostSessions)
        hostSessionProfileId(session.profile): session.status,
    };
    return Card(
      key: const ValueKey('saved-hosts-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text(l10n.savedHosts),
            subtitle: profiles.isEmpty ? Text(l10n.noSavedHosts) : null,
          ),
          if (groupedProfiles.isNotEmpty) const Divider(height: 1),
          for (final entry in groupedProfiles.entries)
            ExpansionTile(
              key: ValueKey('saved-host-group-${entry.key}'),
              initiallyExpanded: !collapsedHosts.contains(entry.key),
              leading: const Icon(Icons.dns_outlined),
              title: Text(_hostGroupTitle(entry.value, entry.key)),
              subtitle: Text(l10n.savedHostProfileCount(entry.value.length)),
              onExpansionChanged: (expanded) =>
                  onHostExpandedChanged(entry.key, expanded),
              children: [
                for (final profile in entry.value)
                  _SavedHostProfileTile(
                    profile: profile,
                    status: statusByProfileId[hostSessionProfileId(profile)],
                    onProfileSelected: onProfileSelected,
                    onProfileDeleted: onProfileDeleted,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SavedHostProfileTile extends StatelessWidget {
  const _SavedHostProfileTile({
    required this.profile,
    required this.status,
    required this.onProfileSelected,
    required this.onProfileDeleted,
  });

  final SshProfile profile;
  final CodexSessionStatus? status;
  final ValueChanged<SshProfile> onProfileSelected;
  final ValueChanged<SshProfile> onProfileDeleted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusLabel = _hostSessionStatusLabel(l10n, status);
    return ListTile(
      key: ValueKey('saved-host-profile-${profile.id}'),
      leading: Icon(_authIcon(profile.authType)),
      title: Text(_profileTitle(profile)),
      subtitle: Text(_profileSubtitle(l10n, profile)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusLabel != null) ...[
            _HostSessionStatusChip(
              key: ValueKey('saved-host-status-${profile.id}'),
              label: statusLabel,
              status: status!,
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            tooltip: l10n.useSshProfile,
            onPressed: () => onProfileSelected(profile),
            icon: const Icon(Icons.drive_file_move_outline),
          ),
          IconButton(
            key: ValueKey('saved-host-delete-${profile.id}'),
            tooltip: l10n.deleteSshProfile,
            onPressed: () => onProfileDeleted(profile),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      onTap: () => onProfileSelected(profile),
    );
  }
}

class _HostSessionStatusChip extends StatelessWidget {
  const _HostSessionStatusChip({
    super.key,
    required this.label,
    required this.status,
  });

  final String label;
  final CodexSessionStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active =
        status == CodexSessionStatus.connected ||
        status == CodexSessionStatus.reconnecting;
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: active ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      ),
      backgroundColor: active
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
    );
  }
}

String? _hostSessionStatusLabel(
  AppLocalizations l10n,
  CodexSessionStatus? status,
) {
  return switch (status) {
    CodexSessionStatus.connecting => l10n.connecting,
    CodexSessionStatus.connected => l10n.connected,
    CodexSessionStatus.reconnecting => l10n.reconnecting,
    CodexSessionStatus.disconnecting => l10n.disconnecting,
    CodexSessionStatus.failed => l10n.connectionFailed,
    CodexSessionStatus.idle || null => null,
  };
}

class _HostImportActionsPanel extends StatelessWidget {
  const _HostImportActionsPanel({
    required this.importingSshConfig,
    required this.importingPrivateKey,
    required this.generatingKey,
    required this.exportingPublicKey,
    required this.generatedKeyPair,
    required this.onImportSshConfig,
    required this.onImportPrivateKey,
    required this.onGenerateKey,
    required this.onCopyPublicKey,
    required this.onExportPublicKey,
  });

  final bool importingSshConfig;
  final bool importingPrivateKey;
  final bool generatingKey;
  final bool exportingPublicKey;
  final GeneratedSshKeyPair? generatedKeyPair;
  final VoidCallback onImportSshConfig;
  final VoidCallback onImportPrivateKey;
  final ValueChanged<SshKeyGenerationAlgorithm> onGenerateKey;
  final VoidCallback? onCopyPublicKey;
  final VoidCallback? onExportPublicKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('host-import-ssh-config-button'),
                  onPressed: importingSshConfig ? null : onImportSshConfig,
                  icon: importingSshConfig
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.rule_folder_outlined),
                  label: Text(
                    importingSshConfig
                        ? l10n.importingSshConfig
                        : l10n.importSshConfig,
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('host-import-private-key-button'),
                  onPressed: importingPrivateKey ? null : onImportPrivateKey,
                  icon: importingPrivateKey
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(
                    importingPrivateKey
                        ? l10n.importingPrivateKey
                        : l10n.importPrivateKeyFile,
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('host-generate-ed25519-key-button'),
                  onPressed: generatingKey
                      ? null
                      : () => onGenerateKey(SshKeyGenerationAlgorithm.ed25519),
                  icon: _keyButtonIcon(generatingKey),
                  label: Text(
                    generatingKey
                        ? l10n.generatingSshKey
                        : l10n.generateEd25519Key,
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('host-generate-rsa-key-button'),
                  onPressed: generatingKey
                      ? null
                      : () => onGenerateKey(SshKeyGenerationAlgorithm.rsa),
                  icon: _keyButtonIcon(generatingKey),
                  label: Text(
                    generatingKey ? l10n.generatingSshKey : l10n.generateRsaKey,
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('host-copy-public-key-button'),
                  onPressed: onCopyPublicKey,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(l10n.copyPublicKey),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('host-export-public-key-button'),
                  onPressed: exportingPublicKey ? null : onExportPublicKey,
                  icon: exportingPublicKey
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt_outlined),
                  label: Text(
                    exportingPublicKey
                        ? l10n.exportingPublicKey
                        : l10n.exportPublicKey,
                  ),
                ),
              ],
            ),
            if (generatedKeyPair != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                l10n.generatedPublicKey,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SelectableText(
                      key: const ValueKey('host-generated-public-key-text'),
                      generatedKeyPair!.publicKeyOpenSsh,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _keyButtonIcon(bool generating) {
    if (!generating) {
      return const Icon(Icons.key_outlined);
    }
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
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
    required this.authType,
    required this.onAuthTypeChanged,
    required this.passwordController,
    required this.privateKeyController,
    required this.passphraseController,
    required this.agentCommandController,
    required this.testing,
    required this.savingProfile,
    required this.restartingBackend,
    required this.onTest,
    required this.onSaveProfile,
    required this.sessionStatus,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRestartBackend,
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
  final bool restartingBackend;
  final VoidCallback onTest;
  final VoidCallback? onSaveProfile;
  final CodexSessionStatus? sessionStatus;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onRestartBackend;

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
                      if (onRestartBackend != null &&
                          (sessionStatus == CodexSessionStatus.connected ||
                              restartingBackend))
                        OutlinedButton.icon(
                          key: const ValueKey('session-restart-backend-button'),
                          onPressed: restartingBackend
                              ? null
                              : onRestartBackend,
                          icon: restartingBackend
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.restart_alt),
                          label: Text(
                            restartingBackend
                                ? l10n.restartingBackend
                                : l10n.restartBackend,
                          ),
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
    final profileName = controller.profile?.displayName;
    return switch (controller.status) {
      CodexSessionStatus.idle => l10n.noActiveConnection,
      CodexSessionStatus.connecting =>
        profileName == null
            ? l10n.connecting
            : '${l10n.connecting}: $profileName',
      CodexSessionStatus.connected =>
        profileName == null
            ? l10n.connected
            : '${l10n.activeConnection}: $profileName',
      CodexSessionStatus.reconnecting => _reconnectingText(l10n, profileName),
      CodexSessionStatus.disconnecting => l10n.disconnecting,
      CodexSessionStatus.failed =>
        profileName == null
            ? l10n.connectionFailed
            : '${l10n.connectionFailed}: $profileName',
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
              Text(_agentStatusSummary(report!.agentStatus!)),
              const SizedBox(height: 4),
              Text('${l10n.agentVersion}: ${report.agentStatus!.agentVersion}'),
              if (report.agentStatus!.codexFailure != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${l10n.codexStatusFailure}: '
                  '${report.agentStatus!.codexFailure!.message}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
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
      BackendKind.sadcoderAgentService => l10n.backendAgentService,
      BackendKind.codexAppServerDaemon => l10n.backendDaemon,
      BackendKind.codexAppServerStdio => l10n.backendStdioFallback,
      BackendKind.unknown => l10n.backendUnknown,
    };
    final state = switch (status.backendState) {
      BackendState.ready => l10n.backendReady,
      BackendState.notStarted => l10n.backendNotStarted,
      BackendState.unavailable => l10n.backendUnavailable,
    };
    return '${l10n.backend}: $kind / $state';
  }

  String _agentStatusSummary(AgentStatus status) {
    return '${status.platformOs}/${status.platformArch} - ${_codexSummary(status)}';
  }

  String _codexSummary(AgentStatus status) {
    if (status.codexAvailable) {
      final version = status.codexVersion?.trim();
      return version == null || version.isEmpty ? status.codexPath : version;
    }
    final failure = status.codexFailure?.message.trim();
    if (failure != null && failure.isNotEmpty) {
      return failure;
    }
    return status.codexPath;
  }

  String _reconnectCacheSummary(AppLocalizations l10n, AgentStatus status) {
    final cache = status.reconnectCache;
    final summary = l10n.reconnectCacheSummary(
      cache.pendingApprovals,
      cache.recentEvents,
      cache.threads,
    );
    final deliveredCursor = cache.deliveredCursor;
    if (deliveredCursor == null) {
      return summary;
    }
    return '$summary - ${l10n.reconnectCacheDeliveredCursor(deliveredCursor)}';
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
      subtitle: _subtitleFor(step, l10n),
    );
  }

  Widget? _subtitleFor(M0ProbeStepResult step, AppLocalizations l10n) {
    final suggestion = step.suggestion == null
        ? null
        : _suggestionFor(step.suggestion!, l10n);
    final detail = step.detail;
    if (detail == null && suggestion == null) {
      return null;
    }
    if (detail == null) {
      return Text(suggestion!);
    }
    if (suggestion == null) {
      return Text(detail);
    }
    return Text('$detail\n$suggestion');
  }

  static String _labelFor(M0ProbeStep step, AppLocalizations l10n) =>
      switch (step) {
        M0ProbeStep.tcpConnect => l10n.tcpConnect,
        M0ProbeStep.sshHandshake => l10n.sshHandshake,
        M0ProbeStep.hostKey => l10n.hostKey,
        M0ProbeStep.auth => l10n.sshAuth,
        M0ProbeStep.remoteShell => l10n.remoteShell,
        M0ProbeStep.codexVersion => l10n.codexVersion,
        M0ProbeStep.agentStatus => l10n.agentStatus,
        M0ProbeStep.agentStart => l10n.agentStart,
        M0ProbeStep.proxyConnect => l10n.proxyConnect,
        M0ProbeStep.agentHello => l10n.agentHello,
        M0ProbeStep.initialize => l10n.initialize,
        M0ProbeStep.accountRead => l10n.accountRead,
        M0ProbeStep.modelList => l10n.modelList,
        M0ProbeStep.configRead => l10n.configRead,
        M0ProbeStep.permissionProfileList => l10n.permissionProfileList,
        M0ProbeStep.threadList => l10n.threadList,
      };

  static String _suggestionFor(
    M0ProbeSuggestion suggestion,
    AppLocalizations l10n,
  ) => switch (suggestion) {
    M0ProbeSuggestion.checkNetwork => l10n.probeSuggestionCheckNetwork,
    M0ProbeSuggestion.checkSshServer => l10n.probeSuggestionCheckSshServer,
    M0ProbeSuggestion.verifyHostKey => l10n.probeSuggestionVerifyHostKey,
    M0ProbeSuggestion.checkAuth => l10n.probeSuggestionCheckAuth,
    M0ProbeSuggestion.checkRemoteShell => l10n.probeSuggestionCheckRemoteShell,
    M0ProbeSuggestion.installCodex => l10n.probeSuggestionInstallCodex,
    M0ProbeSuggestion.updateCodex => l10n.probeSuggestionUpdateCodex,
    M0ProbeSuggestion.installAgent => l10n.probeSuggestionInstallAgent,
    M0ProbeSuggestion.startAgent => l10n.probeSuggestionStartAgent,
    M0ProbeSuggestion.checkBackend => l10n.probeSuggestionCheckBackend,
    M0ProbeSuggestion.loginCodex => l10n.probeSuggestionLoginCodex,
    M0ProbeSuggestion.checkCwdOrPermissions =>
      l10n.probeSuggestionCheckCwdOrPermissions,
    M0ProbeSuggestion.retryProxy => l10n.probeSuggestionRetryProxy,
  };
}
