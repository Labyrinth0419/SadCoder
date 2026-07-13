import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../session/codex_session_state_controller.dart';
import '../../session/host_session_summary.dart';
import '../../ssh/ssh_profile.dart';

class ChatConnectionControls extends StatelessWidget {
  const ChatConnectionControls({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.connectedProfile,
    required this.hostSessions,
    required this.status,
    required this.connectionLabel,
    required this.profileLoadError,
    required this.onProfileSelected,
  });

  final List<SshProfile> profiles;
  final SshProfile? selectedProfile;
  final SshProfile? connectedProfile;
  final List<HostSessionSummary> hostSessions;
  final CodexSessionStatus status;
  final String connectionLabel;
  final Object? profileLoadError;
  final ValueChanged<SshProfile>? onProfileSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeProfile = connectedProfile ?? selectedProfile;
    final hostStatusByProfileId = {
      for (final session in hostSessions) session.profile.id: session.status,
      if (connectedProfile != null) connectedProfile!.id: status,
    };
    final canOpen =
        onProfileSelected != null &&
        status != CodexSessionStatus.connecting &&
        status != CodexSessionStatus.disconnecting;
    return PopupMenuButton<SshProfile>(
      key: const ValueKey('chat-host-selector'),
      enabled: canOpen,
      tooltip: l10n.host,
      onSelected: onProfileSelected,
      itemBuilder: (context) => [
        if (profileLoadError != null)
          PopupMenuItem<SshProfile>(
            enabled: false,
            child: Text(
              '${l10n.savedHosts}: $profileLoadError',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (profiles.isEmpty)
          PopupMenuItem<SshProfile>(
            enabled: false,
            child: Text(l10n.noSavedHosts),
          ),
        for (final profile in profiles)
          PopupMenuItem<SshProfile>(
            key: ValueKey('chat-host-option-${profile.id}'),
            value: profile,
            child: _HostMenuItem(
              profile: profile,
              selected: activeProfile?.id == profile.id,
              status: hostStatusByProfileId[profile.id],
            ),
          ),
      ],
      child: _HostSelectorPill(
        label: activeProfile == null
            ? connectionLabel
            : _chatProfileTitle(activeProfile),
        connected: status == CodexSessionStatus.connected,
        busy:
            status == CodexSessionStatus.connecting ||
            status == CodexSessionStatus.reconnecting ||
            status == CodexSessionStatus.disconnecting,
        enabled: canOpen,
      ),
    );
  }
}

class _HostSelectorPill extends StatelessWidget {
  const _HostSelectorPill({
    required this.label,
    required this.connected,
    required this.busy,
    required this.enabled,
  });

  final String label;
  final bool connected;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.45);
    final borderColor = connected ? colorScheme.primary : colorScheme.outline;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: connected
              ? colorScheme.primaryContainer.withValues(alpha: 0.45)
              : colorScheme.surface,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            else
              Icon(
                connected ? Icons.dns : Icons.dns_outlined,
                size: 18,
                color: foreground,
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: foreground),
          ],
        ),
      ),
    );
  }
}

class _HostMenuItem extends StatelessWidget {
  const _HostMenuItem({
    required this.profile,
    required this.selected,
    this.status,
  });

  final SshProfile profile;
  final bool selected;
  final CodexSessionStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final statusLabel = _chatHostStatusLabel(l10n, status);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Row(
        children: [
          Icon(selected ? Icons.check : _chatAuthIcon(profile.authType)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _chatProfileTitle(profile),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  profile.endpoint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (statusLabel != null) ...[
            const SizedBox(width: 8),
            _HostStatusChip(
              key: ValueKey('chat-host-status-${profile.id}'),
              label: statusLabel,
              status: status!,
            ),
          ],
        ],
      ),
    );
  }
}

class _HostStatusChip extends StatelessWidget {
  const _HostStatusChip({super.key, required this.label, required this.status});

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

String? _chatHostStatusLabel(
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

String _chatProfileTitle(SshProfile profile) {
  return profile.displayName;
}

IconData _chatAuthIcon(SshAuthType authType) {
  return switch (authType) {
    SshAuthType.password => Icons.password,
    SshAuthType.privateKey => Icons.vpn_key_outlined,
  };
}
