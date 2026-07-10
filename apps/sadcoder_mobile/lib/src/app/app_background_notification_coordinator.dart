import '../approvals/approval_state_controller.dart';
import '../background/background_notification_router.dart';
import '../session/codex_session_state_controller.dart';
import '../session/host_session_manager.dart';
import '../ssh/ssh_profile.dart';
import '../ssh/ssh_profile_store.dart';
import '../threads/thread_detail_controller.dart';

enum AppBackgroundNotificationDestination { chat, approvals }

typedef HostSessionManagerProvider = HostSessionManager? Function();
typedef ActiveSessionControllerProvider =
    CodexSessionStateController Function();
typedef ActiveApprovalControllerProvider = ApprovalStateController Function();
typedef ActiveThreadDetailControllerProvider =
    ThreadDetailController Function();
typedef SshProfileStoreProvider = SshProfileStore? Function();
typedef NotificationProfileConnector =
    Future<void> Function(SshProfile profile);
typedef BackgroundNotificationNavigator =
    void Function(AppBackgroundNotificationDestination destination);

class AppBackgroundNotificationCoordinator {
  AppBackgroundNotificationCoordinator({
    required BackgroundNotificationRouter router,
    required HostSessionManagerProvider hostSessionManagerProvider,
    required ActiveSessionControllerProvider sessionControllerProvider,
    required ActiveApprovalControllerProvider approvalControllerProvider,
    required ActiveThreadDetailControllerProvider
    threadDetailControllerProvider,
    required SshProfileStoreProvider profileStoreProvider,
    required NotificationProfileConnector connectProfile,
    required BackgroundNotificationNavigator navigate,
  }) : _router = router,
       _hostSessionManagerProvider = hostSessionManagerProvider,
       _sessionControllerProvider = sessionControllerProvider,
       _approvalControllerProvider = approvalControllerProvider,
       _threadDetailControllerProvider = threadDetailControllerProvider,
       _profileStoreProvider = profileStoreProvider,
       _connectProfile = connectProfile,
       _navigate = navigate;

  final BackgroundNotificationRouter _router;
  final HostSessionManagerProvider _hostSessionManagerProvider;
  final ActiveSessionControllerProvider _sessionControllerProvider;
  final ActiveApprovalControllerProvider _approvalControllerProvider;
  final ActiveThreadDetailControllerProvider _threadDetailControllerProvider;
  final SshProfileStoreProvider _profileStoreProvider;
  final NotificationProfileConnector _connectProfile;
  final BackgroundNotificationNavigator _navigate;

  bool _disposed = false;

  Future<void> start() {
    return _router.attach(_handleRoute);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _router.detach();
  }

  Future<void> _handleRoute(BackgroundNotificationRoute route) async {
    if (_disposed) {
      return;
    }
    await _selectHost(route);
    if (_disposed) {
      return;
    }

    final threadId = _normalized(route.threadId);
    final turnId = _normalized(route.turnId);
    final approvals = _approvalControllerProvider().approvals;
    final hasMatchingApproval = approvals.any((approval) {
      if (turnId != null) {
        return approval.turnId == turnId;
      }
      return threadId != null && approval.threadId == threadId;
    });
    _navigate(
      hasMatchingApproval
          ? AppBackgroundNotificationDestination.approvals
          : AppBackgroundNotificationDestination.chat,
    );

    final sessionController = _sessionControllerProvider();
    if (threadId != null && sessionController.isConnected) {
      await _threadDetailControllerProvider().readThread(threadId);
    }
  }

  Future<void> _selectHost(BackgroundNotificationRoute route) async {
    final manager = _hostSessionManagerProvider();
    if (manager != null) {
      final existing = _sessionForRoute(manager, route);
      if (existing != null) {
        manager.select(existing.profileId);
        return;
      }
      final profile = await _loadProfileForRoute(route);
      if (!_disposed && profile != null) {
        await _connectProfile(profile);
      }
      return;
    }

    final currentProfile = _sessionControllerProvider().profile;
    if (currentProfile != null && _profileMatchesRoute(currentProfile, route)) {
      return;
    }
    final profile = await _loadProfileForRoute(route);
    if (!_disposed && profile != null) {
      await _connectProfile(profile);
    }
  }

  HostSessionEntry? _sessionForRoute(
    HostSessionManager manager,
    BackgroundNotificationRoute route,
  ) {
    final profileId = _normalized(route.profileId);
    if (profileId != null) {
      final entry = manager.sessionFor(profileId);
      if (entry != null) {
        return entry;
      }
    }
    final endpoint = _normalized(route.endpoint)?.toLowerCase();
    if (endpoint == null) {
      return null;
    }
    return manager.sessions
        .where((entry) => entry.profile.endpoint.toLowerCase() == endpoint)
        .firstOrNull;
  }

  Future<SshProfile?> _loadProfileForRoute(
    BackgroundNotificationRoute route,
  ) async {
    final store = _profileStoreProvider();
    if (store == null) {
      return null;
    }
    try {
      final List<SshProfile> profiles;
      if (store is SshProfileListStore) {
        profiles = await store.loadProfiles();
      } else {
        final profile = await store.loadLastProfile();
        profiles = profile == null ? const [] : [profile];
      }
      return profiles
          .where((profile) => _profileMatchesRoute(profile, route))
          .firstOrNull;
    } on Object {
      return null;
    }
  }

  bool _profileMatchesRoute(
    SshProfile profile,
    BackgroundNotificationRoute route,
  ) {
    final profileId = _normalized(route.profileId);
    if (profileId != null && hostSessionProfileId(profile) == profileId) {
      return true;
    }
    final endpoint = _normalized(route.endpoint);
    return endpoint != null &&
        profile.endpoint.toLowerCase() == endpoint.toLowerCase();
  }
}

String? _normalized(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
