import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const delegate = _AppLocalizationsDelegate();

  static const supportedLocales = [Locale('en'), Locale('zh')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String get appTitle => _text('appTitle');
  String get hosts => _text('hosts');
  String get chat => _text('chat');
  String get sessions => _text('sessions');
  String get approvals => _text('approvals');
  String get settings => _text('settings');
  String get sshProfile => _text('sshProfile');
  String get name => _text('name');
  String get host => _text('host');
  String get port => _text('port');
  String get username => _text('username');
  String get password => _text('password');
  String get authPassword => _text('authPassword');
  String get authPrivateKey => _text('authPrivateKey');
  String get privateKey => _text('privateKey');
  String get passphrase => _text('passphrase');
  String get agentCommand => _text('agentCommand');
  String get saveProfile => _text('saveProfile');
  String get savingProfile => _text('savingProfile');
  String get profileSaved => _text('profileSaved');
  String get test => _text('test');
  String get testing => _text('testing');
  String get hostRequired => _text('hostRequired');
  String get usernameRequired => _text('usernameRequired');
  String get passwordRequired => _text('passwordRequired');
  String get privateKeyRequired => _text('privateKeyRequired');
  String get agentCommandRequired => _text('agentCommandRequired');
  String get invalidPort => _text('invalidPort');
  String get notTested => _text('notTested');
  String get testingConnection => _text('testingConnection');
  String get probePassed => _text('probePassed');
  String get probeFailed => _text('probeFailed');
  String get agentStatus => _text('agentStatus');
  String get agentStart => _text('agentStart');
  String get proxyConnect => _text('proxyConnect');
  String get initialize => _text('initialize');
  String get accountRead => _text('accountRead');
  String get modelList => _text('modelList');
  String get configRead => _text('configRead');
  String get permissionProfileList => _text('permissionProfileList');
  String get threadList => _text('threadList');
  String get backend => _text('backend');
  String get backendDaemon => _text('backendDaemon');
  String get backendStdioFallback => _text('backendStdioFallback');
  String get backendUnknown => _text('backendUnknown');
  String reconnectCacheSummary(int pendingApprovals, int recentEvents) =>
      _text('reconnectCacheSummary')
          .replaceAll('{pendingApprovals}', pendingApprovals.toString())
          .replaceAll('{recentEvents}', recentEvents.toString());
  String statePath(String path) =>
      _text('statePath').replaceAll('{path}', path);
  String reconnectCacheLoadError(String error) =>
      _text('reconnectCacheLoadError').replaceAll('{error}', error);
  String get connect => _text('connect');
  String get connecting => _text('connecting');
  String get connected => _text('connected');
  String get reconnecting => _text('reconnecting');
  String get statusIdle => _text('statusIdle');
  String get disconnect => _text('disconnect');
  String get disconnecting => _text('disconnecting');
  String get connectionStatus => _text('connectionStatus');
  String get connectionFailed => _text('connectionFailed');
  String get activeConnection => _text('activeConnection');
  String get noActiveConnection => _text('noActiveConnection');
  String get disconnected => _text('disconnected');
  String get m0ProtocolClient => _text('m0ProtocolClient');
  String get m0ProtocolClientBody => _text('m0ProtocolClientBody');
  String get slashCommandSurface => _text('slashCommandSurface');
  String get slashCommandSurfaceBody => _text('slashCommandSurfaceBody');
  String get connectBeforeTurn => _text('connectBeforeTurn');
  String get connectBeforeLoadingThreads =>
      _text('connectBeforeLoadingThreads');
  String get refreshThreads => _text('refreshThreads');
  String get noThreads => _text('noThreads');
  String get threadListFailed => _text('threadListFailed');
  String get threadDetail => _text('threadDetail');
  String get threadDetailFailed => _text('threadDetailFailed');
  String turnCount(int count) =>
      _text('turnCount').replaceAll('{count}', count.toString());
  String get noTurns => _text('noTurns');
  String get startingThread => _text('startingThread');
  String get resumingThread => _text('resumingThread');
  String get sendingTurn => _text('sendingTurn');
  String turnSubmitted(String turnId) =>
      _text('turnSubmitted').replaceAll('{turnId}', turnId);
  String get turnCompleted => _text('turnCompleted');
  String get interruptTurn => _text('interruptTurn');
  String get interruptingTurn => _text('interruptingTurn');
  String get turnInterrupted => _text('turnInterrupted');
  String get turnFailed => _text('turnFailed');
  String get timeline => _text('timeline');
  String get noTimelineEvents => _text('noTimelineEvents');
  String get timelineItem => _text('timelineItem');
  String get timelineStatus => _text('timelineStatus');
  String get timelineExitCode => _text('timelineExitCode');
  String get timelineDuration => _text('timelineDuration');
  String get timelineFileChanges => _text('timelineFileChanges');
  String get timelineTool => _text('timelineTool');
  String get forkedThread => _text('forkedThread');
  String get subagentThread => _text('subagentThread');
  String get send => _text('send');
  String get slashCommands => _text('slashCommands');
  String get typeCommandName => _text('typeCommandName');
  String slashCommandUnknown(String slash) =>
      _text('slashCommandUnknown').replaceAll('{slash}', slash);
  String get slashCommandNotSentAsPrompt =>
      _text('slashCommandNotSentAsPrompt');
  String get slashCommandUnavailableDuringTask =>
      _text('slashCommandUnavailableDuringTask');
  String get slashCommandRisk => _text('slashCommandRisk');
  String get slashCommandDisconnected => _text('slashCommandDisconnected');
  String get slashCommandCleared => _text('slashCommandCleared');
  String get slashCommandCopied => _text('slashCommandCopied');
  String get slashCommandRawEnabled => _text('slashCommandRawEnabled');
  String get slashCommandRawDisabled => _text('slashCommandRawDisabled');
  String get slashCommandNewThread => _text('slashCommandNewThread');
  String get slashCommandResumedThread => _text('slashCommandResumedThread');
  String get slashCommandRenamedThread => _text('slashCommandRenamedThread');
  String get slashCommandForkedThread => _text('slashCommandForkedThread');
  String get slashCommandCompactionStarted =>
      _text('slashCommandCompactionStarted');
  String get slashCommandArchivedThread => _text('slashCommandArchivedThread');
  String get slashCommandDeletedThread => _text('slashCommandDeletedThread');
  String get slashCommandModelUpdated => _text('slashCommandModelUpdated');
  String get slashCommandPersonalityUpdated =>
      _text('slashCommandPersonalityUpdated');
  String get slashCommandPermissionsUpdated =>
      _text('slashCommandPermissionsUpdated');
  String slashCommandCancelled(String slash) =>
      _text('slashCommandCancelled').replaceAll('{slash}', slash);
  String slashCommandExecuted(String slash) =>
      _text('slashCommandExecuted').replaceAll('{slash}', slash);
  String slashCommandUnsupported(String slash) =>
      _text('slashCommandUnsupported').replaceAll('{slash}', slash);
  String slashCommandUnavailable(String slash) =>
      _text('slashCommandUnavailable').replaceAll('{slash}', slash);
  String slashCommandFailed(String slash, String error) => _text(
    'slashCommandFailed',
  ).replaceAll('{slash}', slash).replaceAll('{error}', error);
  String get noPendingApprovals => _text('noPendingApprovals');
  String get approvalsBody => _text('approvalsBody');
  String get approvalKindCommand => _text('approvalKindCommand');
  String get approvalKindFileChange => _text('approvalKindFileChange');
  String get approvalKindPermissions => _text('approvalKindPermissions');
  String get approvalKindMcp => _text('approvalKindMcp');
  String get approvalKindUnknown => _text('approvalKindUnknown');
  String get approvalRequestId => _text('approvalRequestId');
  String get approvalThread => _text('approvalThread');
  String get approvalTurn => _text('approvalTurn');
  String get approvalCommand => _text('approvalCommand');
  String get approvalWorkingDirectory => _text('approvalWorkingDirectory');
  String get approvalReason => _text('approvalReason');
  String get approvalGrantRoot => _text('approvalGrantRoot');
  String get approvalServer => _text('approvalServer');
  String get approvalMessage => _text('approvalMessage');
  String get approvalUrl => _text('approvalUrl');
  String get approvalApproveOnce => _text('approvalApproveOnce');
  String get approvalApproveSession => _text('approvalApproveSession');
  String get approvalAllowTurn => _text('approvalAllowTurn');
  String get approvalAllowSession => _text('approvalAllowSession');
  String get approvalDeny => _text('approvalDeny');
  String get approvalCancel => _text('approvalCancel');
  String get approvalNoDirectActions => _text('approvalNoDirectActions');
  String get serverDefaults => _text('serverDefaults');
  String get serverDefaultsBody => _text('serverDefaultsBody');
  String get appDefaultOverrides => _text('appDefaultOverrides');
  String get modelOverride => _text('modelOverride');
  String get modelProvider => _text('modelProvider');
  String get effortOverride => _text('effortOverride');
  String get personalityOverride => _text('personalityOverride');
  String get approvalPolicy => _text('approvalPolicy');
  String get permissionProfile => _text('permissionProfile');
  String get sandboxMode => _text('sandboxMode');
  String get cwdOverride => _text('cwdOverride');
  String get applyOverrides => _text('applyOverrides');
  String get clearOverrides => _text('clearOverrides');
  String get overrideSource => _text('overrideSource');
  String get sourceServerDefault => _text('sourceServerDefault');
  String get sourceAppDefault => _text('sourceAppDefault');
  String get sourceSessionOverride => _text('sourceSessionOverride');
  String get sourceTurnOverride => _text('sourceTurnOverride');
  String get sessionOverrides => _text('sessionOverrides');
  String get editSessionOverrides => _text('editSessionOverrides');
  String get applySessionOverrides => _text('applySessionOverrides');
  String get clearSessionOverrides => _text('clearSessionOverrides');
  String get nextTurnOverrides => _text('nextTurnOverrides');
  String get editTurnOverrides => _text('editTurnOverrides');
  String get applyTurnOverrides => _text('applyTurnOverrides');
  String get clearTurnOverrides => _text('clearTurnOverrides');
  String get overrideTurnScope => _text('overrideTurnScope');
  String get overrideSessionScope => _text('overrideSessionScope');
  String get serverDefaultOption => _text('serverDefaultOption');
  String get archiveThreadTitle => _text('archiveThreadTitle');
  String get archiveThreadBody => _text('archiveThreadBody');
  String get archiveThreadConfirm => _text('archiveThreadConfirm');
  String get deleteThreadTitle => _text('deleteThreadTitle');
  String get deleteThreadBody => _text('deleteThreadBody');
  String get deleteThreadConfirm => _text('deleteThreadConfirm');
  String get modelCommandTitle => _text('modelCommandTitle');
  String get modelCommandTurnScope => _text('modelCommandTurnScope');
  String get modelCommandSessionScope => _text('modelCommandSessionScope');
  String get applyModelOverride => _text('applyModelOverride');
  String get personalityCommandTitle => _text('personalityCommandTitle');
  String get applyPersonalityOverride => _text('applyPersonalityOverride');
  String get permissionsCommandTitle => _text('permissionsCommandTitle');
  String get applyPermissionsOverride => _text('applyPermissionsOverride');
  String get networkAccess => _text('networkAccess');
  String get permissionProfileLoadFailed =>
      _text('permissionProfileLoadFailed');
  String get permissionProfilesEmpty => _text('permissionProfilesEmpty');
  String get permissionProfileUnavailable =>
      _text('permissionProfileUnavailable');
  String get permissionsHighRiskWarning => _text('permissionsHighRiskWarning');
  String get serverConfigSnapshot => _text('serverConfigSnapshot');
  String get refreshServerConfig => _text('refreshServerConfig');
  String get serverConfigUnavailable => _text('serverConfigUnavailable');
  String get serverConfigLoadFailed => _text('serverConfigLoadFailed');
  String get serverValueUnset => _text('serverValueUnset');
  String get accountStatus => _text('accountStatus');
  String get accountLoadFailed => _text('accountLoadFailed');
  String get accountNotSignedIn => _text('accountNotSignedIn');
  String get openaiAuthRequired => _text('openaiAuthRequired');
  String get openaiAuthNotRequired => _text('openaiAuthNotRequired');
  String get accountUsageStatus => _text('accountUsageStatus');
  String get accountUsageUnavailable => _text('accountUsageUnavailable');
  String get accountUsageLoadFailed => _text('accountUsageLoadFailed');
  String get accountUsageTokenSummary => _text('accountUsageTokenSummary');
  String get accountUsageRecentDaily => _text('accountUsageRecentDaily');
  String get accountUsageRateLimits => _text('accountUsageRateLimits');
  String get accountUsageResetCredits => _text('accountUsageResetCredits');
  String get threadGoalStatus => _text('threadGoalStatus');
  String get threadGoalEmpty => _text('threadGoalEmpty');
  String get threadGoalObjective => _text('threadGoalObjective');
  String get threadGoalTokensUsed => _text('threadGoalTokensUsed');
  String get threadGoalTokenBudget => _text('threadGoalTokenBudget');
  String get threadGoalTimeUsed => _text('threadGoalTimeUsed');
  String get threadGoalCleared => _text('threadGoalCleared');
  String get threadReviewStarted => _text('threadReviewStarted');
  String get threadReviewTarget => _text('threadReviewTarget');
  String get threadReviewTargetUncommitted =>
      _text('threadReviewTargetUncommitted');
  String get threadReviewTargetBaseBranch =>
      _text('threadReviewTargetBaseBranch');
  String get threadReviewTargetCommit => _text('threadReviewTargetCommit');
  String get threadReviewTargetCustom => _text('threadReviewTargetCustom');
  String get threadReviewDelivery => _text('threadReviewDelivery');
  String get threadReviewDeliveryInline => _text('threadReviewDeliveryInline');
  String get threadReviewDeliveryDetached =>
      _text('threadReviewDeliveryDetached');
  String get threadReviewThread => _text('threadReviewThread');
  String get threadReviewTurn => _text('threadReviewTurn');
  String get backgroundTerminalsTitle => _text('backgroundTerminalsTitle');
  String get backgroundTerminalsEmpty => _text('backgroundTerminalsEmpty');
  String get backgroundTerminalsMore => _text('backgroundTerminalsMore');
  String get backgroundTerminalsCleanRequested =>
      _text('backgroundTerminalsCleanRequested');
  String get backgroundTerminalProcess => _text('backgroundTerminalProcess');
  String get backgroundTerminalItem => _text('backgroundTerminalItem');
  String get backgroundTerminalCwd => _text('backgroundTerminalCwd');
  String get backgroundTerminalOsPid => _text('backgroundTerminalOsPid');
  String get backgroundTerminalCpu => _text('backgroundTerminalCpu');
  String get backgroundTerminalRss => _text('backgroundTerminalRss');
  String get mcpServersStatus => _text('mcpServersStatus');
  String get mcpServersUnavailable => _text('mcpServersUnavailable');
  String get mcpServersLoadFailed => _text('mcpServersLoadFailed');
  String get mcpServersEmpty => _text('mcpServersEmpty');
  String get mcpServerAuthStatus => _text('mcpServerAuthStatus');
  String get mcpServerTools => _text('mcpServerTools');
  String get mcpServerResources => _text('mcpServerResources');
  String get mcpServerResourceTemplates => _text('mcpServerResourceTemplates');
  String get mcpServerInfo => _text('mcpServerInfo');
  String get mcpServersMore => _text('mcpServersMore');
  String get skillsTitle => _text('skillsTitle');
  String get skillsUnavailable => _text('skillsUnavailable');
  String get skillsLoadFailed => _text('skillsLoadFailed');
  String get skillsEmpty => _text('skillsEmpty');
  String get skillsCwd => _text('skillsCwd');
  String get skillDescription => _text('skillDescription');
  String get skillPath => _text('skillPath');
  String get skillErrors => _text('skillErrors');
  String get skillEnabled => _text('skillEnabled');
  String get skillDisabled => _text('skillDisabled');
  String get skillScope => _text('skillScope');
  String get pluginsTitle => _text('pluginsTitle');
  String get pluginsUnavailable => _text('pluginsUnavailable');
  String get pluginsLoadFailed => _text('pluginsLoadFailed');
  String get pluginsEmpty => _text('pluginsEmpty');
  String get pluginMarketplace => _text('pluginMarketplace');
  String get pluginMarketplacePath => _text('pluginMarketplacePath');
  String get pluginMarketplaceErrors => _text('pluginMarketplaceErrors');
  String get pluginDescription => _text('pluginDescription');
  String get pluginVersion => _text('pluginVersion');
  String get pluginSource => _text('pluginSource');
  String get pluginCapabilities => _text('pluginCapabilities');
  String get pluginInstalled => _text('pluginInstalled');
  String get pluginNotInstalled => _text('pluginNotInstalled');
  String get pluginEnabled => _text('pluginEnabled');
  String get pluginDisabled => _text('pluginDisabled');
  String get pluginAvailability => _text('pluginAvailability');
  String get hooksTitle => _text('hooksTitle');
  String get hooksUnavailable => _text('hooksUnavailable');
  String get hooksLoadFailed => _text('hooksLoadFailed');
  String get hooksEmpty => _text('hooksEmpty');
  String get hooksCwd => _text('hooksCwd');
  String get hookWarnings => _text('hookWarnings');
  String get hookErrors => _text('hookErrors');
  String get hookEnabled => _text('hookEnabled');
  String get hookDisabled => _text('hookDisabled');
  String get hookManaged => _text('hookManaged');
  String get hookUserManaged => _text('hookUserManaged');
  String get hookTrust => _text('hookTrust');
  String get hookSource => _text('hookSource');
  String get hookMatcher => _text('hookMatcher');
  String get hookCommand => _text('hookCommand');
  String get hookStatusMessage => _text('hookStatusMessage');
  String get hookSourcePath => _text('hookSourcePath');
  String get hookPlugin => _text('hookPlugin');
  String get hookTimeout => _text('hookTimeout');
  String get appsTitle => _text('appsTitle');
  String get appsUnavailable => _text('appsUnavailable');
  String get appsLoadFailed => _text('appsLoadFailed');
  String get appsEmpty => _text('appsEmpty');
  String get appDescription => _text('appDescription');
  String get appCategory => _text('appCategory');
  String get appDeveloper => _text('appDeveloper');
  String get appVersion => _text('appVersion');
  String get appDistribution => _text('appDistribution');
  String get appReview => _text('appReview');
  String get appPlugins => _text('appPlugins');
  String get appWebsite => _text('appWebsite');
  String get appInstallUrl => _text('appInstallUrl');
  String get appsNextCursor => _text('appsNextCursor');
  String get appAccessible => _text('appAccessible');
  String get appNotAccessible => _text('appNotAccessible');
  String get appEnabled => _text('appEnabled');
  String get appDisabled => _text('appDisabled');
  String get debugConfigTitle => _text('debugConfigTitle');
  String get debugConfigUnavailable => _text('debugConfigUnavailable');
  String get debugConfigLoadFailed => _text('debugConfigLoadFailed');
  String get debugConfigNoSnapshot => _text('debugConfigNoSnapshot');
  String get debugConfigEffectiveValues => _text('debugConfigEffectiveValues');
  String get debugConfigOrigins => _text('debugConfigOrigins');
  String get debugConfigLayerConfig => _text('debugConfigLayerConfig');
  String get debugConfigLayerMetadata => _text('debugConfigLayerMetadata');
  String get lifetimeTokens => _text('lifetimeTokens');
  String get peakDailyTokens => _text('peakDailyTokens');
  String get currentStreakDays => _text('currentStreakDays');
  String get longestStreakDays => _text('longestStreakDays');
  String get longestRunningTurnSec => _text('longestRunningTurnSec');
  String get primaryRateLimit => _text('primaryRateLimit');
  String get secondaryRateLimit => _text('secondaryRateLimit');
  String get rateLimitUnavailable => _text('rateLimitUnavailable');
  String get planType => _text('planType');
  String get creditsStatus => _text('creditsStatus');
  String get creditsUnlimited => _text('creditsUnlimited');
  String get creditsAvailable => _text('creditsAvailable');
  String get creditsUnavailable => _text('creditsUnavailable');
  String get individualLimit => _text('individualLimit');
  String tokenCount(int count) =>
      _text('tokenCount').replaceAll('{count}', count.toString());
  String dayCount(int count) =>
      _text('dayCount').replaceAll('{count}', count.toString());
  String secondCount(int count) =>
      _text('secondCount').replaceAll('{count}', count.toString());
  String rateLimitUsedPercent(int percent) =>
      _text('rateLimitUsedPercent').replaceAll('{percent}', percent.toString());
  String rateLimitWindowMinutes(int minutes) => _text(
    'rateLimitWindowMinutes',
  ).replaceAll('{minutes}', minutes.toString());
  String rateLimitResetsAt(int timestamp) => _text(
    'rateLimitResetsAt',
  ).replaceAll('{timestamp}', timestamp.toString());
  String rateLimitReached(String type) =>
      _text('rateLimitReached').replaceAll('{type}', type);
  String creditsBalance(String balance) =>
      _text('creditsBalance').replaceAll('{balance}', balance);
  String individualLimitUsed(String used) =>
      _text('individualLimitUsed').replaceAll('{used}', used);
  String individualLimitRemaining(int percent) => _text(
    'individualLimitRemaining',
  ).replaceAll('{percent}', percent.toString());
  String resetCreditsAvailable(int count) =>
      _text('resetCreditsAvailable').replaceAll('{count}', count.toString());
  String configLayersLoaded(int count) =>
      _text('configLayersLoaded').replaceAll('{count}', count.toString());
  String debugConfigLayers(int count) =>
      _text('debugConfigLayers').replaceAll('{count}', count.toString());
  String debugConfigLayer(int index) =>
      _text('debugConfigLayer').replaceAll('{index}', index.toString());
  String get theme => _text('theme');
  String get themeBody => _text('themeBody');

  String _text(String key) {
    return _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _values.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    final languageCode = _values.containsKey(locale.languageCode)
        ? locale.languageCode
        : 'en';
    return SynchronousFuture(AppLocalizations(Locale(languageCode)));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _values = <String, Map<String, String>>{
  'en': {
    'appTitle': 'SadCoder',
    'hosts': 'Hosts',
    'chat': 'Chat',
    'sessions': 'Sessions',
    'approvals': 'Approvals',
    'settings': 'Settings',
    'sshProfile': 'SSH profile',
    'name': 'Name',
    'host': 'Host',
    'port': 'Port',
    'username': 'Username',
    'password': 'Password',
    'authPassword': 'Password',
    'authPrivateKey': 'Private key',
    'privateKey': 'Private key',
    'passphrase': 'Passphrase',
    'agentCommand': 'Agent command',
    'saveProfile': 'Save profile',
    'savingProfile': 'Saving',
    'profileSaved': 'Profile saved.',
    'test': 'Test',
    'testing': 'Testing',
    'hostRequired': 'Host is required',
    'usernameRequired': 'Username is required',
    'passwordRequired': 'Password is required',
    'privateKeyRequired': 'Private key is required',
    'agentCommandRequired': 'Agent command is required',
    'invalidPort': 'Invalid port',
    'notTested': 'Not tested',
    'testingConnection': 'Testing connection',
    'probePassed': 'Probe passed',
    'probeFailed': 'Probe failed',
    'agentStatus': 'Agent status',
    'agentStart': 'Agent start',
    'proxyConnect': 'Proxy connect',
    'initialize': 'Initialize',
    'accountRead': 'Account read',
    'modelList': 'Model list',
    'configRead': 'Config read',
    'permissionProfileList': 'Permission profile list',
    'threadList': 'Thread list',
    'backend': 'Backend',
    'backendDaemon': 'daemon',
    'backendStdioFallback': 'stdio fallback',
    'backendUnknown': 'unknown',
    'reconnectCacheSummary':
        'Reconnect cache: {pendingApprovals} pending approvals, {recentEvents} recent events',
    'statePath': 'State path: {path}',
    'reconnectCacheLoadError': 'Reconnect cache load error: {error}',
    'connect': 'Connect',
    'connecting': 'Connecting',
    'connected': 'Connected',
    'reconnecting': 'Reconnecting',
    'statusIdle': 'Idle',
    'disconnect': 'Disconnect',
    'disconnecting': 'Disconnecting',
    'connectionStatus': 'Connection status',
    'connectionFailed': 'Connection failed',
    'activeConnection': 'Active connection',
    'noActiveConnection': 'No active connection',
    'disconnected': 'Disconnected',
    'm0ProtocolClient': 'M0 protocol client',
    'm0ProtocolClientBody':
        'The app has a JSON-RPC client for initialize, model/list, and thread/list. SSH transport uses the same interface.',
    'slashCommandSurface': 'Slash command surface',
    'slashCommandSurfaceBody':
        'Typing / will later open the SadCoder command palette instead of sending slash text as a normal prompt.',
    'connectBeforeTurn': 'Connect to a host before sending a turn',
    'connectBeforeLoadingThreads': 'Connect to a host to load sessions.',
    'refreshThreads': 'Refresh sessions',
    'noThreads': 'No sessions found',
    'threadListFailed': 'Failed to load sessions',
    'threadDetail': 'Thread detail',
    'threadDetailFailed': 'Failed to load thread detail',
    'turnCount': 'Turns: {count}',
    'noTurns': 'No turns loaded',
    'startingThread': 'Starting thread',
    'resumingThread': 'Resuming thread',
    'sendingTurn': 'Sending turn',
    'turnSubmitted': 'Turn submitted: {turnId}',
    'turnCompleted': 'Turn completed',
    'interruptTurn': 'Interrupt turn',
    'interruptingTurn': 'Interrupting turn',
    'turnInterrupted': 'Turn interrupted',
    'turnFailed': 'Turn failed',
    'timeline': 'Timeline',
    'noTimelineEvents': 'No events yet',
    'timelineItem': 'Item',
    'timelineStatus': 'Status',
    'timelineExitCode': 'Exit code',
    'timelineDuration': 'Duration',
    'timelineFileChanges': 'File changes',
    'timelineTool': 'Tool',
    'forkedThread': 'fork',
    'subagentThread': 'subagent',
    'send': 'Send',
    'slashCommands': 'Slash commands',
    'typeCommandName': 'Type a command name',
    'slashCommandUnknown': 'Unknown command: {slash}',
    'slashCommandNotSentAsPrompt': 'Not sent as a prompt',
    'slashCommandUnavailableDuringTask': 'Unavailable while a turn is active',
    'slashCommandRisk': 'Risk',
    'slashCommandDisconnected':
        'Disconnected from the mobile proxy. Server tasks were not interrupted.',
    'slashCommandCleared': 'Local transcript cleared.',
    'slashCommandCopied': 'Copied last response.',
    'slashCommandRawEnabled': 'Raw transcript view enabled.',
    'slashCommandRawDisabled': 'Raw transcript view disabled.',
    'slashCommandNewThread': 'Started a new thread.',
    'slashCommandResumedThread': 'Resumed thread.',
    'slashCommandRenamedThread': 'Renamed thread.',
    'slashCommandForkedThread': 'Forked thread.',
    'slashCommandCompactionStarted': 'Started thread compaction.',
    'slashCommandArchivedThread': 'Archived thread.',
    'slashCommandDeletedThread': 'Deleted thread.',
    'slashCommandModelUpdated': 'Model override updated.',
    'slashCommandPersonalityUpdated': 'Personality override updated.',
    'slashCommandPermissionsUpdated': 'Permission override updated.',
    'slashCommandCancelled': 'Canceled {slash}.',
    'slashCommandExecuted': 'Executed {slash}.',
    'slashCommandUnsupported': '{slash} is not implemented yet.',
    'slashCommandUnavailable': '{slash} is unavailable right now.',
    'slashCommandFailed': '{slash} failed: {error}',
    'noPendingApprovals': 'No pending approvals',
    'approvalsBody':
        'Command, file, and MCP requests will appear here with their thread and turn IDs.',
    'approvalKindCommand': 'Command approval',
    'approvalKindFileChange': 'File change approval',
    'approvalKindPermissions': 'Permission approval',
    'approvalKindMcp': 'MCP elicitation',
    'approvalKindUnknown': 'Unknown request',
    'approvalRequestId': 'Request',
    'approvalThread': 'Thread',
    'approvalTurn': 'Turn',
    'approvalCommand': 'Command',
    'approvalWorkingDirectory': 'Working directory',
    'approvalReason': 'Reason',
    'approvalGrantRoot': 'Grant root',
    'approvalServer': 'Server',
    'approvalMessage': 'Message',
    'approvalUrl': 'URL',
    'approvalApproveOnce': 'Approve once',
    'approvalApproveSession': 'Approve session',
    'approvalAllowTurn': 'Allow turn',
    'approvalAllowSession': 'Allow session',
    'approvalDeny': 'Deny',
    'approvalCancel': 'Cancel',
    'approvalNoDirectActions': 'No direct actions available',
    'serverDefaults': 'Server defaults',
    'serverDefaultsBody':
        'Codex configuration is inherited from the server unless an override is explicitly set.',
    'appDefaultOverrides': 'App default overrides',
    'modelOverride': 'Model',
    'modelProvider': 'Model provider',
    'effortOverride': 'Reasoning effort',
    'personalityOverride': 'Personality',
    'approvalPolicy': 'Approval policy',
    'permissionProfile': 'Permission profile',
    'sandboxMode': 'Sandbox mode',
    'cwdOverride': 'Working directory',
    'applyOverrides': 'Apply overrides',
    'clearOverrides': 'Clear overrides',
    'overrideSource': 'Source',
    'sourceServerDefault': 'server default',
    'sourceAppDefault': 'app default',
    'sourceSessionOverride': 'session override',
    'sourceTurnOverride': 'turn override',
    'sessionOverrides': 'Session overrides',
    'editSessionOverrides': 'Edit session overrides',
    'applySessionOverrides': 'Apply to session',
    'clearSessionOverrides': 'Clear session overrides',
    'nextTurnOverrides': 'Next turn overrides',
    'editTurnOverrides': 'Edit next turn overrides',
    'applyTurnOverrides': 'Apply to next turn',
    'clearTurnOverrides': 'Clear next turn overrides',
    'overrideTurnScope': 'Next turn',
    'overrideSessionScope': 'Session',
    'serverDefaultOption': 'Server default',
    'archiveThreadTitle': 'Archive thread?',
    'archiveThreadBody':
        'This moves the current thread out of the active session list.',
    'archiveThreadConfirm': 'Archive',
    'deleteThreadTitle': 'Delete thread?',
    'deleteThreadBody':
        'This permanently deletes the current thread and spawned descendant threads. This cannot be undone.',
    'deleteThreadConfirm': 'Delete',
    'modelCommandTitle': 'Model override',
    'modelCommandTurnScope': 'Next turn',
    'modelCommandSessionScope': 'Session',
    'applyModelOverride': 'Apply model override',
    'personalityCommandTitle': 'Personality override',
    'applyPersonalityOverride': 'Apply personality override',
    'permissionsCommandTitle': 'Permission override',
    'applyPermissionsOverride': 'Apply permission override',
    'networkAccess': 'Network access',
    'permissionProfileLoadFailed': 'Failed to load permission profiles',
    'permissionProfilesEmpty': 'No server permission profiles.',
    'permissionProfileUnavailable': 'unavailable',
    'permissionsHighRiskWarning':
        'High risk: these permissions can let Codex run with less review or broader filesystem access.',
    'serverConfigSnapshot': 'Server config snapshot',
    'refreshServerConfig': 'Refresh server config',
    'serverConfigUnavailable': 'Connect to a host, then refresh server config.',
    'serverConfigLoadFailed': 'Failed to load server config',
    'serverValueUnset': 'not set',
    'accountStatus': 'Account',
    'accountLoadFailed': 'Failed to load account',
    'accountNotSignedIn': 'not signed in',
    'openaiAuthRequired': 'OpenAI auth required',
    'openaiAuthNotRequired': 'OpenAI auth not required',
    'accountUsageStatus': 'Usage',
    'accountUsageUnavailable': 'Connect to a host, then run /usage.',
    'accountUsageLoadFailed': 'Failed to load usage',
    'accountUsageTokenSummary': 'Token usage',
    'accountUsageRecentDaily': 'Recent daily usage',
    'accountUsageRateLimits': 'Rate limits',
    'accountUsageResetCredits': 'Reset credits',
    'threadGoalStatus': 'Goal',
    'threadGoalEmpty': 'No goal set.',
    'threadGoalObjective': 'Objective',
    'threadGoalTokensUsed': 'Tokens used',
    'threadGoalTokenBudget': 'Token budget',
    'threadGoalTimeUsed': 'Time used',
    'threadGoalCleared': 'Goal cleared.',
    'threadReviewStarted': 'Review started.',
    'threadReviewTarget': 'Target',
    'threadReviewTargetUncommitted': 'current changes',
    'threadReviewTargetBaseBranch': 'base branch',
    'threadReviewTargetCommit': 'commit',
    'threadReviewTargetCustom': 'custom instructions',
    'threadReviewDelivery': 'Delivery',
    'threadReviewDeliveryInline': 'inline',
    'threadReviewDeliveryDetached': 'detached',
    'threadReviewThread': 'Thread',
    'threadReviewTurn': 'Turn',
    'backgroundTerminalsTitle': 'Background terminals',
    'backgroundTerminalsEmpty': 'No background terminals running.',
    'backgroundTerminalsMore': 'More background terminals are available.',
    'backgroundTerminalsCleanRequested': 'Stopping all background terminals.',
    'backgroundTerminalProcess': 'process',
    'backgroundTerminalItem': 'item',
    'backgroundTerminalCwd': 'cwd',
    'backgroundTerminalOsPid': 'OS pid',
    'backgroundTerminalCpu': 'CPU',
    'backgroundTerminalRss': 'memory',
    'mcpServersStatus': 'MCP servers',
    'mcpServersUnavailable': 'Connect to a host, then run /mcp.',
    'mcpServersLoadFailed': 'Failed to load MCP servers',
    'mcpServersEmpty': 'No MCP servers configured.',
    'mcpServerAuthStatus': 'auth',
    'mcpServerTools': 'tools',
    'mcpServerResources': 'resources',
    'mcpServerResourceTemplates': 'templates',
    'mcpServerInfo': 'server',
    'mcpServersMore': 'More MCP servers are available.',
    'skillsTitle': 'Skills',
    'skillsUnavailable': 'Connect to a host, then run /skills.',
    'skillsLoadFailed': 'Failed to load skills',
    'skillsEmpty': 'No skills available.',
    'skillsCwd': 'cwd',
    'skillDescription': 'Description',
    'skillPath': 'Path',
    'skillErrors': 'Errors',
    'skillEnabled': 'enabled',
    'skillDisabled': 'disabled',
    'skillScope': 'scope',
    'pluginsTitle': 'Plugins',
    'pluginsUnavailable': 'Connect to a host, then run /plugins.',
    'pluginsLoadFailed': 'Failed to load plugins',
    'pluginsEmpty': 'No plugins available.',
    'pluginMarketplace': 'Marketplace',
    'pluginMarketplacePath': 'Marketplace path',
    'pluginMarketplaceErrors': 'Marketplace errors',
    'pluginDescription': 'Description',
    'pluginVersion': 'Version',
    'pluginSource': 'Source',
    'pluginCapabilities': 'Capabilities',
    'pluginInstalled': 'installed',
    'pluginNotInstalled': 'not installed',
    'pluginEnabled': 'enabled',
    'pluginDisabled': 'disabled',
    'pluginAvailability': 'availability',
    'hooksTitle': 'Hooks',
    'hooksUnavailable': 'Connect to a host, then run /hooks.',
    'hooksLoadFailed': 'Failed to load hooks',
    'hooksEmpty': 'No hooks configured.',
    'hooksCwd': 'cwd',
    'hookWarnings': 'hook warnings',
    'hookErrors': 'hook errors',
    'hookEnabled': 'enabled',
    'hookDisabled': 'disabled',
    'hookManaged': 'managed',
    'hookUserManaged': 'user-managed',
    'hookTrust': 'trust',
    'hookSource': 'source',
    'hookMatcher': 'matcher',
    'hookCommand': 'command',
    'hookStatusMessage': 'status message',
    'hookSourcePath': 'source path',
    'hookPlugin': 'plugin',
    'hookTimeout': 'timeout',
    'appsTitle': 'Apps',
    'appsUnavailable': 'Connect to a host, then run /apps.',
    'appsLoadFailed': 'Failed to load apps',
    'appsEmpty': 'No apps available.',
    'appDescription': 'Description',
    'appCategory': 'Category',
    'appDeveloper': 'Developer',
    'appVersion': 'Version',
    'appDistribution': 'Distribution',
    'appReview': 'Review',
    'appPlugins': 'Plugins',
    'appWebsite': 'Website',
    'appInstallUrl': 'Install URL',
    'appsNextCursor': 'Next cursor',
    'appAccessible': 'accessible',
    'appNotAccessible': 'not accessible',
    'appEnabled': 'enabled',
    'appDisabled': 'disabled',
    'debugConfigTitle': 'Debug config',
    'debugConfigUnavailable': 'Connect to a host, then run /debug-config.',
    'debugConfigLoadFailed': 'Failed to load debug config',
    'debugConfigNoSnapshot': 'No config snapshot loaded.',
    'debugConfigEffectiveValues': 'Effective values',
    'debugConfigOrigins': 'Origins',
    'debugConfigLayerConfig': 'config',
    'debugConfigLayerMetadata': 'metadata',
    'lifetimeTokens': 'Lifetime tokens',
    'peakDailyTokens': 'Peak daily tokens',
    'currentStreakDays': 'Current streak',
    'longestStreakDays': 'Longest streak',
    'longestRunningTurnSec': 'Longest turn',
    'primaryRateLimit': 'Primary',
    'secondaryRateLimit': 'Secondary',
    'rateLimitUnavailable': 'not available',
    'planType': 'Plan',
    'creditsStatus': 'Credits',
    'creditsUnlimited': 'unlimited',
    'creditsAvailable': 'available',
    'creditsUnavailable': 'unavailable',
    'individualLimit': 'Monthly limit',
    'tokenCount': '{count} tokens',
    'dayCount': '{count} days',
    'secondCount': '{count} sec',
    'rateLimitUsedPercent': '{percent}% used',
    'rateLimitWindowMinutes': '{minutes} min window',
    'rateLimitResetsAt': 'resets at {timestamp}',
    'rateLimitReached': 'Reached: {type}',
    'creditsBalance': 'balance {balance}',
    'individualLimitUsed': 'used {used}',
    'individualLimitRemaining': '{percent}% remaining',
    'resetCreditsAvailable': '{count} available',
    'configLayersLoaded': 'Config layers loaded: {count}',
    'debugConfigLayers': 'Config layers: {count}',
    'debugConfigLayer': 'Layer {index}',
    'theme': 'Theme',
    'themeBody': 'System, light, and dark modes are supported.',
  },
  'zh': {
    'appTitle': 'SadCoder',
    'hosts': '主机',
    'chat': '对话',
    'sessions': '会话',
    'approvals': '审批',
    'settings': '设置',
    'sshProfile': 'SSH 配置',
    'name': '名称',
    'host': '主机',
    'port': '端口',
    'username': '用户名',
    'password': '密码',
    'authPassword': '密码',
    'authPrivateKey': '私钥',
    'privateKey': '私钥',
    'passphrase': '私钥口令',
    'agentCommand': 'Agent 命令',
    'saveProfile': '保存配置',
    'savingProfile': '保存中',
    'profileSaved': '配置已保存。',
    'test': '测试',
    'testing': '测试中',
    'hostRequired': '请填写主机',
    'usernameRequired': '请填写用户名',
    'passwordRequired': '请填写密码',
    'privateKeyRequired': '请填写私钥',
    'agentCommandRequired': '请填写 Agent 命令',
    'invalidPort': '端口无效',
    'notTested': '未测试',
    'testingConnection': '正在测试连接',
    'probePassed': '测试通过',
    'probeFailed': '测试失败',
    'agentStatus': 'Agent 状态',
    'agentStart': '启动 Agent',
    'proxyConnect': '代理连接',
    'initialize': '初始化',
    'accountRead': '账户读取',
    'modelList': '模型列表',
    'configRead': '配置读取',
    'permissionProfileList': '权限配置列表',
    'threadList': '会话列表',
    'backend': '后端',
    'backendDaemon': 'daemon',
    'backendStdioFallback': 'stdio fallback',
    'backendUnknown': '未知',
    'reconnectCacheSummary':
        '重连缓存：{pendingApprovals} 个待审批，{recentEvents} 个最近事件',
    'statePath': '状态路径：{path}',
    'reconnectCacheLoadError': '重连缓存读取失败：{error}',
    'connect': '连接',
    'connecting': '连接中',
    'connected': '已连接',
    'reconnecting': '重连中',
    'statusIdle': '空闲',
    'disconnect': '断开',
    'disconnecting': '断开中',
    'connectionStatus': '连接状态',
    'connectionFailed': '连接失败',
    'activeConnection': '当前连接',
    'noActiveConnection': '暂无活动连接',
    'disconnected': '未连接',
    'm0ProtocolClient': 'M0 协议客户端',
    'm0ProtocolClientBody':
        '应用已经具备 initialize、model/list 和 thread/list 的 JSON-RPC 客户端，SSH 传输复用同一接口。',
    'slashCommandSurface': '斜杠命令入口',
    'slashCommandSurfaceBody': '输入 / 后会打开 SadCoder 命令面板，而不是把斜杠文本当作普通提示词发送。',
    'connectBeforeTurn': '连接主机后才能发送任务',
    'connectBeforeLoadingThreads': '连接主机后加载会话。',
    'refreshThreads': '刷新会话',
    'noThreads': '暂无会话',
    'threadListFailed': '会话加载失败',
    'threadDetail': '会话详情',
    'threadDetailFailed': '会话详情加载失败',
    'turnCount': '回合数：{count}',
    'noTurns': '暂无已加载回合',
    'startingThread': '正在创建会话',
    'resumingThread': '正在恢复会话',
    'sendingTurn': '正在发送回合',
    'turnSubmitted': '回合已发送：{turnId}',
    'turnCompleted': '回合已完成',
    'interruptTurn': '中断回合',
    'interruptingTurn': '正在中断回合',
    'turnInterrupted': '回合已中断',
    'turnFailed': '回合失败',
    'timeline': '事件流',
    'noTimelineEvents': '暂无事件',
    'timelineItem': '条目',
    'timelineStatus': '状态',
    'timelineExitCode': '退出码',
    'timelineDuration': '耗时',
    'timelineFileChanges': '文件变更',
    'timelineTool': '工具',
    'forkedThread': '分叉',
    'subagentThread': '子 agent',
    'send': '发送',
    'slashCommands': '斜杠命令',
    'typeCommandName': '输入命令名称',
    'slashCommandUnknown': '未知命令：{slash}',
    'slashCommandNotSentAsPrompt': '不会作为普通提示词发送',
    'slashCommandUnavailableDuringTask': '当前回合运行中不可用',
    'slashCommandRisk': '风险',
    'slashCommandDisconnected': '已断开移动端代理连接，服务器任务未被中断。',
    'slashCommandCleared': '已清除本地事件流。',
    'slashCommandCopied': '已复制最后一条回复。',
    'slashCommandRawEnabled': '已开启原始事件视图。',
    'slashCommandRawDisabled': '已关闭原始事件视图。',
    'slashCommandNewThread': '已创建新会话。',
    'slashCommandResumedThread': '已恢复会话。',
    'slashCommandRenamedThread': '已重命名会话。',
    'slashCommandForkedThread': '已派生会话。',
    'slashCommandCompactionStarted': '已开始压缩会话。',
    'slashCommandArchivedThread': '已归档会话。',
    'slashCommandDeletedThread': '已删除会话。',
    'slashCommandModelUpdated': '已更新模型覆盖。',
    'slashCommandPersonalityUpdated': '已更新协作风格覆盖。',
    'slashCommandPermissionsUpdated': '已更新权限覆盖。',
    'slashCommandCancelled': '已取消 {slash}。',
    'slashCommandExecuted': '已执行 {slash}。',
    'slashCommandUnsupported': '{slash} 暂未实现。',
    'slashCommandUnavailable': '{slash} 当前不可用。',
    'slashCommandFailed': '{slash} 执行失败：{error}',
    'noPendingApprovals': '暂无待审批请求',
    'approvalsBody': '命令、文件和 MCP 请求会在这里显示对应的会话与回合 ID。',
    'approvalKindCommand': '命令审批',
    'approvalKindFileChange': '文件变更审批',
    'approvalKindPermissions': '权限审批',
    'approvalKindMcp': 'MCP 表单请求',
    'approvalKindUnknown': '未知请求',
    'approvalRequestId': '请求',
    'approvalThread': '会话',
    'approvalTurn': '回合',
    'approvalCommand': '命令',
    'approvalWorkingDirectory': '工作目录',
    'approvalReason': '原因',
    'approvalGrantRoot': '授权根目录',
    'approvalServer': '服务器',
    'approvalMessage': '消息',
    'approvalUrl': 'URL',
    'approvalApproveOnce': '批准一次',
    'approvalApproveSession': '本会话批准',
    'approvalAllowTurn': '本轮允许',
    'approvalAllowSession': '本会话允许',
    'approvalDeny': '拒绝',
    'approvalCancel': '取消',
    'approvalNoDirectActions': '暂无可直接执行的操作',
    'serverDefaults': '服务器默认配置',
    'serverDefaultsBody': '默认沿用服务器上的 Codex 配置，只有显式设置时才覆盖。',
    'appDefaultOverrides': 'App 默认覆盖',
    'modelOverride': '模型',
    'modelProvider': '模型提供方',
    'effortOverride': '推理强度',
    'personalityOverride': '协作风格',
    'approvalPolicy': '审批策略',
    'permissionProfile': '权限配置',
    'sandboxMode': '沙盒模式',
    'cwdOverride': '工作目录',
    'applyOverrides': '应用覆盖',
    'clearOverrides': '清除覆盖',
    'overrideSource': '来源',
    'sourceServerDefault': '服务器默认',
    'sourceAppDefault': 'App 默认',
    'sourceSessionOverride': '会话覆盖',
    'sourceTurnOverride': '本次覆盖',
    'sessionOverrides': '会话覆盖',
    'editSessionOverrides': '编辑会话覆盖',
    'applySessionOverrides': '应用到会话',
    'clearSessionOverrides': '清除会话覆盖',
    'nextTurnOverrides': '本次回合覆盖',
    'editTurnOverrides': '编辑本次回合覆盖',
    'applyTurnOverrides': '应用到本次回合',
    'clearTurnOverrides': '清除本次回合覆盖',
    'overrideTurnScope': '本次回合',
    'overrideSessionScope': '本会话',
    'serverDefaultOption': '服务器默认',
    'archiveThreadTitle': '归档会话？',
    'archiveThreadBody': '这会把当前会话移出活动会话列表。',
    'archiveThreadConfirm': '归档',
    'deleteThreadTitle': '删除会话？',
    'deleteThreadBody': '这会永久删除当前会话和派生的子会话，无法撤销。',
    'deleteThreadConfirm': '删除',
    'modelCommandTitle': '模型覆盖',
    'modelCommandTurnScope': '本次回合',
    'modelCommandSessionScope': '本会话',
    'applyModelOverride': '应用模型覆盖',
    'personalityCommandTitle': '协作风格覆盖',
    'applyPersonalityOverride': '应用协作风格覆盖',
    'permissionsCommandTitle': '权限覆盖',
    'applyPermissionsOverride': '应用权限覆盖',
    'networkAccess': '网络访问',
    'permissionProfileLoadFailed': '权限配置加载失败',
    'permissionProfilesEmpty': '服务器暂无权限配置。',
    'permissionProfileUnavailable': '不可用',
    'permissionsHighRiskWarning': '高风险：这些权限会减少 Codex 执行前的审批或扩大文件系统访问范围。',
    'serverConfigSnapshot': '服务器配置快照',
    'refreshServerConfig': '刷新服务器配置',
    'serverConfigUnavailable': '连接主机后刷新服务器配置。',
    'serverConfigLoadFailed': '服务器配置加载失败',
    'serverValueUnset': '未设置',
    'accountStatus': '账户',
    'accountLoadFailed': '账户加载失败',
    'accountNotSignedIn': '未登录',
    'openaiAuthRequired': '需要 OpenAI 认证',
    'openaiAuthNotRequired': '不需要 OpenAI 认证',
    'accountUsageStatus': '使用量',
    'accountUsageUnavailable': '连接主机后运行 /usage。',
    'accountUsageLoadFailed': '使用量加载失败',
    'accountUsageTokenSummary': 'Token 使用量',
    'accountUsageRecentDaily': '最近每日使用量',
    'accountUsageRateLimits': '速率限制',
    'accountUsageResetCredits': '重置额度',
    'threadGoalStatus': '目标',
    'threadGoalEmpty': '未设置目标。',
    'threadGoalObjective': '目标内容',
    'threadGoalTokensUsed': '已用 token',
    'threadGoalTokenBudget': 'Token 预算',
    'threadGoalTimeUsed': '已用时间',
    'threadGoalCleared': '已清除目标。',
    'threadReviewStarted': '已开始代码审查。',
    'threadReviewTarget': '审查目标',
    'threadReviewTargetUncommitted': '当前改动',
    'threadReviewTargetBaseBranch': '基准分支',
    'threadReviewTargetCommit': '提交',
    'threadReviewTargetCustom': '自定义说明',
    'threadReviewDelivery': '运行方式',
    'threadReviewDeliveryInline': '当前会话内',
    'threadReviewDeliveryDetached': '独立审查会话',
    'threadReviewThread': '会话',
    'threadReviewTurn': '回合',
    'backgroundTerminalsTitle': '后台终端',
    'backgroundTerminalsEmpty': '没有正在运行的后台终端。',
    'backgroundTerminalsMore': '还有更多后台终端。',
    'backgroundTerminalsCleanRequested': '正在停止所有后台终端。',
    'backgroundTerminalProcess': '进程',
    'backgroundTerminalItem': '条目',
    'backgroundTerminalCwd': '工作目录',
    'backgroundTerminalOsPid': '系统进程 ID',
    'backgroundTerminalCpu': 'CPU',
    'backgroundTerminalRss': '内存',
    'mcpServersStatus': 'MCP 服务器',
    'mcpServersUnavailable': '连接主机后运行 /mcp。',
    'mcpServersLoadFailed': 'MCP 服务器加载失败',
    'mcpServersEmpty': '未配置 MCP 服务器。',
    'mcpServerAuthStatus': '认证',
    'mcpServerTools': '工具',
    'mcpServerResources': '资源',
    'mcpServerResourceTemplates': '模板',
    'mcpServerInfo': '服务器',
    'mcpServersMore': '还有更多 MCP 服务器可用。',
    'skillsTitle': '技能',
    'skillsUnavailable': '连接主机后运行 /skills。',
    'skillsLoadFailed': '技能加载失败',
    'skillsEmpty': '暂无可用技能。',
    'skillsCwd': '工作目录',
    'skillDescription': '说明',
    'skillPath': '路径',
    'skillErrors': '错误',
    'skillEnabled': '已启用',
    'skillDisabled': '已禁用',
    'skillScope': '范围',
    'pluginsTitle': '插件',
    'pluginsUnavailable': '连接主机后运行 /plugins。',
    'pluginsLoadFailed': '插件加载失败',
    'pluginsEmpty': '暂无可用插件。',
    'pluginMarketplace': '市场',
    'pluginMarketplacePath': '市场路径',
    'pluginMarketplaceErrors': '市场错误',
    'pluginDescription': '说明',
    'pluginVersion': '版本',
    'pluginSource': '来源',
    'pluginCapabilities': '能力',
    'pluginInstalled': '已安装',
    'pluginNotInstalled': '未安装',
    'pluginEnabled': '已启用',
    'pluginDisabled': '已禁用',
    'pluginAvailability': '可用性',
    'hooksTitle': 'Hooks',
    'hooksUnavailable': '连接主机后运行 /hooks。',
    'hooksLoadFailed': 'Hooks 加载失败',
    'hooksEmpty': '暂无配置的 hooks。',
    'hooksCwd': '工作目录',
    'hookWarnings': 'hook 警告',
    'hookErrors': 'hook 错误',
    'hookEnabled': '已启用',
    'hookDisabled': '已禁用',
    'hookManaged': '受管',
    'hookUserManaged': '用户管理',
    'hookTrust': '信任状态',
    'hookSource': '来源',
    'hookMatcher': '匹配器',
    'hookCommand': '命令',
    'hookStatusMessage': '状态消息',
    'hookSourcePath': '来源路径',
    'hookPlugin': '插件',
    'hookTimeout': '超时',
    'appsTitle': '应用',
    'appsUnavailable': '连接主机后运行 /apps。',
    'appsLoadFailed': '应用加载失败',
    'appsEmpty': '暂无可用应用。',
    'appDescription': '说明',
    'appCategory': '分类',
    'appDeveloper': '开发者',
    'appVersion': '版本',
    'appDistribution': '分发渠道',
    'appReview': '审核',
    'appPlugins': '插件',
    'appWebsite': '网站',
    'appInstallUrl': '安装 URL',
    'appsNextCursor': '下一页游标',
    'appAccessible': '可访问',
    'appNotAccessible': '不可访问',
    'appEnabled': '已启用',
    'appDisabled': '已禁用',
    'debugConfigTitle': '调试配置',
    'debugConfigUnavailable': '连接主机后运行 /debug-config。',
    'debugConfigLoadFailed': '调试配置加载失败',
    'debugConfigNoSnapshot': '尚未加载配置快照。',
    'debugConfigEffectiveValues': '生效值',
    'debugConfigOrigins': '来源',
    'debugConfigLayerConfig': '配置',
    'debugConfigLayerMetadata': '元数据',
    'lifetimeTokens': '累计 token',
    'peakDailyTokens': '单日峰值 token',
    'currentStreakDays': '当前连续天数',
    'longestStreakDays': '最长连续天数',
    'longestRunningTurnSec': '最长回合',
    'primaryRateLimit': '主限制',
    'secondaryRateLimit': '次限制',
    'rateLimitUnavailable': '不可用',
    'planType': '套餐',
    'creditsStatus': '额度',
    'creditsUnlimited': '无限制',
    'creditsAvailable': '可用',
    'creditsUnavailable': '不可用',
    'individualLimit': '月度限制',
    'tokenCount': '{count} token',
    'dayCount': '{count} 天',
    'secondCount': '{count} 秒',
    'rateLimitUsedPercent': '已用 {percent}%',
    'rateLimitWindowMinutes': '{minutes} 分钟窗口',
    'rateLimitResetsAt': '重置时间 {timestamp}',
    'rateLimitReached': '已触达：{type}',
    'creditsBalance': '余额 {balance}',
    'individualLimitUsed': '已用 {used}',
    'individualLimitRemaining': '剩余 {percent}%',
    'resetCreditsAvailable': '{count} 个可用',
    'configLayersLoaded': '已加载配置层：{count}',
    'debugConfigLayers': '配置层：{count}',
    'debugConfigLayer': '第 {index} 层',
    'theme': '主题',
    'themeBody': '支持跟随系统、浅色和深色模式。',
  },
};

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
