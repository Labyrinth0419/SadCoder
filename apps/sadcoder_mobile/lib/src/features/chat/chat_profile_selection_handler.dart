import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';
import '../../session/codex_session_state_controller.dart';
import '../../session/host_session_summary.dart';
import '../../ssh/ssh_profile.dart';
import '../../ssh/ssh_profile_store.dart';

typedef ChatProfileSelectionConnector =
    Future<void> Function(SshProfile profile);
typedef ChatProfileStoreProvider = SshProfileStore? Function();
typedef ChatProfileStateSetter =
    void Function({
      required List<SshProfile> savedProfiles,
      required String? selectedProfileId,
      required Object? profileLoadError,
    });
typedef ChatSelectedProfileSetter = void Function(String profileId);
typedef ChatProfileSnackBar = void Function(String message);

class ChatProfileSelectionHandler {
  const ChatProfileSelectionHandler({
    required this.context,
    required this.mounted,
    required this.profileStoreProvider,
    required this.sessionController,
    required this.profileConnector,
    required this.currentSelectedProfileId,
    required this.applyProfileState,
    required this.selectProfileLocally,
    required this.showSnackBar,
  });

  final BuildContext context;
  final bool Function() mounted;
  final ChatProfileStoreProvider profileStoreProvider;
  final CodexSessionStateController? sessionController;
  final ChatProfileSelectionConnector? profileConnector;
  final String? Function() currentSelectedProfileId;
  final ChatProfileStateSetter applyProfileState;
  final ChatSelectedProfileSetter selectProfileLocally;
  final ChatProfileSnackBar showSnackBar;

  Future<void> loadSavedProfiles() async {
    final store = profileStoreProvider();
    if (store == null) {
      if (mounted()) {
        applyProfileState(
          savedProfiles: const [],
          selectedProfileId: sessionController?.profile?.id,
          profileLoadError: null,
        );
      }
      return;
    }

    try {
      late final List<SshProfile> profiles;
      if (store is SshProfileListStore) {
        profiles = await store.loadProfiles();
      } else {
        final profile = await store.loadLastProfile();
        profiles = [?profile];
      }
      if (!mounted() || store != profileStoreProvider()) {
        return;
      }
      applyProfileState(
        savedProfiles: List.unmodifiable(profiles),
        selectedProfileId: preferredChatHeaderProfileId(
          profiles: profiles,
          connectedProfile: sessionController?.profile,
          selectedProfileId: currentSelectedProfileId(),
        ),
        profileLoadError: null,
      );
    } on Object catch (error) {
      if (!mounted() || store != profileStoreProvider()) {
        return;
      }
      applyProfileState(
        savedProfiles: const [],
        selectedProfileId: sessionController?.profile?.id,
        profileLoadError: error,
      );
    }
  }

  Future<void> selectProfile(SshProfile profile) async {
    final l10n = context.l10n;
    selectProfileLocally(profile.id);

    final connector = profileConnector;
    final controller = sessionController;
    if (connector == null && controller == null) {
      return;
    }
    if (controller?.status == CodexSessionStatus.connected &&
        controller?.profile?.id == profile.id) {
      return;
    }

    try {
      if (connector != null) {
        await connector(profile);
      } else {
        await controller!.connect(profile);
      }
    } on Object catch (error) {
      if (!mounted()) {
        return;
      }
      showSnackBar(l10n.messageWithDetail(l10n.connectionFailed, error));
    }
  }
}

String? preferredChatHeaderProfileId({
  required List<SshProfile> profiles,
  required SshProfile? connectedProfile,
  required String? selectedProfileId,
}) {
  if (connectedProfile != null) {
    return connectedProfile.id;
  }
  if (selectedProfileId != null &&
      profiles.any((profile) => profile.id == selectedProfileId)) {
    return selectedProfileId;
  }
  return profiles.isEmpty ? null : profiles.first.id;
}

List<SshProfile> chatHeaderProfiles({
  required List<SshProfile> savedProfiles,
  required List<HostSessionSummary> hostSessions,
  required SshProfile? connectedProfile,
}) {
  final profiles = <SshProfile>[
    ...savedProfiles,
    for (final session in hostSessions) session.profile,
    ?connectedProfile,
  ];
  final seen = <String>{};
  return List.unmodifiable(
    profiles.where((profile) => seen.add(profile.id)).toList(),
  );
}

SshProfile? selectedChatHeaderProfile({
  required List<SshProfile> profiles,
  required SshProfile? connectedProfile,
  required String? selectedProfileId,
}) {
  final selectedId = connectedProfile?.id ?? selectedProfileId;
  if (selectedId == null) {
    return null;
  }
  for (final profile in profiles) {
    if (profile.id == selectedId) {
      return profile;
    }
  }
  return null;
}
