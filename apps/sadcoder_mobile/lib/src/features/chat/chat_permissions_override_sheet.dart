import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/codex_config_override_controller.dart';
import '../../i18n/app_localizations.dart';
import '../../permissions/permission_profile_list_controller.dart';
import '../../permissions/permission_profile_list_reader.dart';
import '../../security/permission_risk.dart';
import 'chat_override_scope.dart';
import 'chat_summary_formatting.dart';
import 'config_override_labels.dart';

class ChatPermissionsOverrideResult {
  const ChatPermissionsOverrideResult({
    required this.scope,
    required this.approvalPolicy,
    required this.sandboxPolicy,
    required this.permissionProfile,
  });

  final ChatOverrideScope scope;
  final Object? approvalPolicy;
  final Map<String, Object?> sandboxPolicy;
  final String? permissionProfile;

  bool get isHighRisk {
    return isHighRiskPermissionState(
      approvalPolicy: approvalPolicy,
      sandboxPolicy: sandboxPolicy,
      permissionProfile: permissionProfile,
    );
  }
}

class ChatPermissionsOverrideSheet extends StatefulWidget {
  const ChatPermissionsOverrideSheet({
    super.key,
    required this.controller,
    this.permissionProfileListController,
  });

  final CodexConfigOverrideController controller;
  final PermissionProfileListController? permissionProfileListController;

  @override
  State<ChatPermissionsOverrideSheet> createState() =>
      _ChatPermissionsOverrideSheetState();
}

class _ChatPermissionsOverrideSheetState
    extends State<ChatPermissionsOverrideSheet> {
  late ChatOverrideScope _scope;
  late String _approvalPolicy;
  late String _permissionProfile;
  late String _sandboxMode;
  late bool _networkAccess;

  @override
  void initState() {
    super.initState();
    _scope = ChatOverrideScope.turn;
    _loadScopeValues();
    unawaited(_refreshPermissionProfiles());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.permissionsCommandTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ChatOverrideScopeSelector(
              scope: _scope,
              onChanged: (scope) {
                setState(() {
                  _scope = scope;
                  _loadScopeValues();
                });
              },
            ),
            const SizedBox(height: 12),
            _OverrideDropdown(
              key: const ValueKey('chat-permissions-command-approval-policy'),
              label: l10n.approvalPolicy,
              value: _approvalPolicy,
              values: _approvalPolicyOptions,
              defaultLabel: l10n.serverDefaultOption,
              onChanged: (value) {
                setState(() => _approvalPolicy = value);
              },
            ),
            const SizedBox(height: 12),
            if (widget.permissionProfileListController != null) ...[
              _PermissionProfileSelector(
                controller: widget.permissionProfileListController!,
                value: _permissionProfile,
                onChanged: _handlePermissionProfileChanged,
              ),
              const SizedBox(height: 12),
            ],
            _OverrideDropdown(
              key: const ValueKey('chat-permissions-command-sandbox-mode'),
              label: l10n.sandboxMode,
              value: _sandboxMode,
              values: _sandboxModeOptions,
              defaultLabel: l10n.serverDefaultOption,
              enabled: _permissionProfile.isEmpty,
              onChanged: (value) {
                setState(() => _sandboxMode = value);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('chat-permissions-command-network-access'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.networkAccess),
              value: _networkAccess,
              onChanged: _sandboxMode.isEmpty || _permissionProfile.isNotEmpty
                  ? null
                  : (value) => setState(() => _networkAccess = value),
            ),
            if (_isHighRisk) ...[
              const SizedBox(height: 8),
              _PermissionsRiskWarning(message: l10n.permissionsHighRiskWarning),
            ],
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: Text(l10n.approvalCancel),
                ),
                FilledButton.icon(
                  key: const ValueKey('chat-permissions-command-apply'),
                  onPressed: _apply,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.applyPermissionsOverride),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isHighRisk {
    return isHighRiskPermissionValue(
      approvalPolicy: _approvalPolicy,
      sandboxMode: _sandboxMode,
      permissionProfile: _permissionProfile,
    );
  }

  void _apply() {
    Navigator.of(context).pop(
      ChatPermissionsOverrideResult(
        scope: _scope,
        approvalPolicy: _approvalPolicy,
        sandboxPolicy: _sandboxPolicy(),
        permissionProfile: _permissionProfile.isEmpty
            ? null
            : _permissionProfile,
      ),
    );
  }

  void _loadScopeValues() {
    final overrides = chatOverridesForScope(widget.controller, _scope);
    _approvalPolicy = _supportedOption(
      configOverrideValueLabel(overrides.approvalPolicy) ?? '',
      _approvalPolicyOptions,
    );
    _permissionProfile = overrides.permissionProfile ?? '';
    final sandboxPolicy = overrides.sandboxPolicy;
    if (_permissionProfile.isNotEmpty) {
      _sandboxMode = '';
      _networkAccess = false;
    } else {
      _sandboxMode = _supportedOption(
        sandboxPolicy?['type'] as String? ?? '',
        _sandboxModeOptions,
      );
      _networkAccess = sandboxPolicy?['networkAccess'] as bool? ?? false;
    }
  }

  Map<String, Object?> _sandboxPolicy() {
    if (_permissionProfile.isNotEmpty || _sandboxMode.isEmpty) {
      return {};
    }
    return {'type': _sandboxMode, 'networkAccess': _networkAccess};
  }

  Future<void> _refreshPermissionProfiles() async {
    await widget.permissionProfileListController?.refresh(
      cwd: widget.controller.resolved.cwd,
    );
  }

  void _handlePermissionProfileChanged(String value) {
    setState(() {
      _permissionProfile = value;
      if (_permissionProfile.isNotEmpty) {
        _sandboxMode = '';
        _networkAccess = false;
      }
    });
  }
}

const _approvalPolicyOptions = ['', 'on-request', 'on-failure', 'never'];
const _sandboxModeOptions = [
  '',
  'readOnly',
  'workspaceWrite',
  'dangerFullAccess',
];

String _supportedOption(String value, List<String> options) {
  return options.contains(value) ? value : '';
}

class _PermissionProfileSelector extends StatelessWidget {
  const _PermissionProfileSelector({
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  final PermissionProfileListController controller;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _PermissionProfileSelectorContent(
        controller: controller,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _PermissionProfileSelectorContent extends StatelessWidget {
  const _PermissionProfileSelectorContent({
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  final PermissionProfileListController controller;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profiles = controller.profiles;
    final ids = profiles.map((profile) => profile.id).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.permissionProfile,
            border: const OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const ValueKey(
                'chat-permissions-command-permission-profile',
              ),
              value: value,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(l10n.serverDefaultOption),
                ),
                if (value.isNotEmpty && !ids.contains(value))
                  DropdownMenuItem(value: value, child: Text(value)),
                for (final profile in profiles)
                  DropdownMenuItem(
                    value: profile.id,
                    enabled: profile.allowed,
                    child: Text(_profileLabel(l10n, profile)),
                  ),
              ],
              onChanged: (selected) => onChanged(selected ?? ''),
            ),
          ),
        ),
        if (controller.status == PermissionProfileListStatus.loading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ] else if (controller.status == PermissionProfileListStatus.failed) ...[
          const SizedBox(height: 8),
          Text(
            chatSummaryMessageWithOptionalDetail(
              l10n,
              l10n.permissionProfileLoadFailed,
              controller.error,
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ] else if (controller.status == PermissionProfileListStatus.loaded &&
            profiles.isEmpty) ...[
          const SizedBox(height: 8),
          Text(l10n.permissionProfilesEmpty),
        ],
      ],
    );
  }

  String _profileLabel(
    AppLocalizations l10n,
    PermissionProfileSummary profile,
  ) {
    if (profile.allowed) {
      return profile.label;
    }
    return '${profile.label} / ${l10n.permissionProfileUnavailable}';
  }
}

class _OverrideDropdown extends StatelessWidget {
  const _OverrideDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.defaultLabel,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String value;
  final List<String> values;
  final String defaultLabel;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: [
            for (final option in values)
              DropdownMenuItem(
                value: option,
                child: Text(option.isEmpty ? defaultLabel : option),
              ),
          ],
          onChanged: enabled
              ? (value) {
                  if (value != null) {
                    onChanged(value);
                  }
                }
              : null,
        ),
      ),
    );
  }
}

class _PermissionsRiskWarning extends StatelessWidget {
  const _PermissionsRiskWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_outlined,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
