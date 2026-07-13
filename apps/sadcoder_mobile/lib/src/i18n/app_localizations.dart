import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const delegate = _AppLocalizationsDelegate();

  static const supportedLocales = [Locale('en', 'US'), Locale('zh', 'CN')];

  @visibleForTesting
  static Map<String, Map<String, String>> get debugValues => _values;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String get appTitle => _text('appTitle');
  String messageWithDetail(String message, Object detail) => _text(
    'messageWithDetail',
  ).replaceAll('{message}', message).replaceAll('{detail}', '$detail');
  String get hosts => _text('hosts');
  String get chat => _text('chat');
  String get files => _text('files');
  String get sessions => _text('sessions');
  String get approvals => _text('approvals');
  String get settings => _text('settings');
  String get settingsSectionPermissions => _text('settingsSectionPermissions');
  String get settingsSectionAccount => _text('settingsSectionAccount');
  String get settingsSectionModels => _text('settingsSectionModels');
  String get settingsSectionAppearance => _text('settingsSectionAppearance');
  String get settingsSectionSsh => _text('settingsSectionSsh');
  String get settingsSectionDiagnostics => _text('settingsSectionDiagnostics');
  String get settingsSectionUnavailable => _text('settingsSectionUnavailable');
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
  String get profileLoaded => _text('profileLoaded');
  String get savedHosts => _text('savedHosts');
  String get noSavedHosts => _text('noSavedHosts');
  String get useSshProfile => _text('useSshProfile');
  String get deleteSshProfile => _text('deleteSshProfile');
  String get deleteSshProfileTitle => _text('deleteSshProfileTitle');
  String deleteSshProfileBody(String name) =>
      _text('deleteSshProfileBody').replaceAll('{name}', name);
  String get sshProfileDeleted => _text('sshProfileDeleted');
  String get sshProfileDeleteFailed => _text('sshProfileDeleteFailed');
  String savedHostProfileCount(int count) =>
      _text('savedHostProfileCount').replaceAll('{count}', '$count');
  String get importSshConfig => _text('importSshConfig');
  String get importingSshConfig => _text('importingSshConfig');
  String sshConfigImported(int count) =>
      _text('sshConfigImported').replaceAll('{count}', formatNumber(count));
  String get sshConfigImportFailed => _text('sshConfigImportFailed');
  String get sshConfigImportNoHosts => _text('sshConfigImportNoHosts');
  String get importPrivateKeyFile => _text('importPrivateKeyFile');
  String get importingPrivateKey => _text('importingPrivateKey');
  String get privateKeyImportedAndSaved => _text('privateKeyImportedAndSaved');
  String get privateKeyImportNeedsProfile =>
      _text('privateKeyImportNeedsProfile');
  String get privateKeyImportFailed => _text('privateKeyImportFailed');
  String get privateKeyImportNoPemBlock => _text('privateKeyImportNoPemBlock');
  String get generateEd25519Key => _text('generateEd25519Key');
  String get generateRsaKey => _text('generateRsaKey');
  String get generatingSshKey => _text('generatingSshKey');
  String get generatedPublicKey => _text('generatedPublicKey');
  String get copyPublicKey => _text('copyPublicKey');
  String get publicKeyCopied => _text('publicKeyCopied');
  String get exportPublicKey => _text('exportPublicKey');
  String get exportingPublicKey => _text('exportingPublicKey');
  String get publicKeyExported => _text('publicKeyExported');
  String get publicKeyExportFailed => _text('publicKeyExportFailed');
  String get sshKeyGeneratedAndSaved => _text('sshKeyGeneratedAndSaved');
  String get sshKeyGenerationNeedsProfile =>
      _text('sshKeyGenerationNeedsProfile');
  String get sshKeyGenerationFailed => _text('sshKeyGenerationFailed');
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
  String get tcpConnect => _text('tcpConnect');
  String get sshHandshake => _text('sshHandshake');
  String get hostKey => _text('hostKey');
  String get sshAuth => _text('sshAuth');
  String get remoteShell => _text('remoteShell');
  String get codexVersion => _text('codexVersion');
  String get agentVersion => _text('agentVersion');
  String get agentStatus => _text('agentStatus');
  String get agentStart => _text('agentStart');
  String get proxyConnect => _text('proxyConnect');
  String get agentHello => _text('agentHello');
  String get initialize => _text('initialize');
  String get accountRead => _text('accountRead');
  String get modelList => _text('modelList');
  String get modelDefaultBadge => _text('modelDefaultBadge');
  String modelDefaultValueSummary(String value) =>
      _text('modelDefaultValueSummary').replaceAll('{value}', value);
  String modelReasoningSummary(String summary) =>
      _text('modelReasoningSummary').replaceAll('{summary}', summary);
  String modelServiceTierSummary(String summary) =>
      _text('modelServiceTierSummary').replaceAll('{summary}', summary);
  String modelAnnouncementSummary(String message) =>
      _text('modelAnnouncementSummary').replaceAll('{message}', message);
  String get configRead => _text('configRead');
  String get permissionProfileList => _text('permissionProfileList');
  String get threadList => _text('threadList');
  String get probeSuggestionCheckNetwork =>
      _text('probeSuggestionCheckNetwork');
  String get probeSuggestionCheckSshServer =>
      _text('probeSuggestionCheckSshServer');
  String get probeSuggestionVerifyHostKey =>
      _text('probeSuggestionVerifyHostKey');
  String get probeSuggestionCheckAuth => _text('probeSuggestionCheckAuth');
  String get probeSuggestionCheckRemoteShell =>
      _text('probeSuggestionCheckRemoteShell');
  String get probeSuggestionInstallCodex =>
      _text('probeSuggestionInstallCodex');
  String get probeSuggestionUpdateCodex => _text('probeSuggestionUpdateCodex');
  String get probeSuggestionInstallAgent =>
      _text('probeSuggestionInstallAgent');
  String get probeSuggestionStartAgent => _text('probeSuggestionStartAgent');
  String get probeSuggestionCheckBackend =>
      _text('probeSuggestionCheckBackend');
  String get probeSuggestionLoginCodex => _text('probeSuggestionLoginCodex');
  String get probeSuggestionCheckCwdOrPermissions =>
      _text('probeSuggestionCheckCwdOrPermissions');
  String get probeSuggestionRetryProxy => _text('probeSuggestionRetryProxy');
  String get backend => _text('backend');
  String get backendAgentService => _text('backendAgentService');
  String get backendDaemon => _text('backendDaemon');
  String get backendStdioFallback => _text('backendStdioFallback');
  String get backendUnknown => _text('backendUnknown');
  String get backendReady => _text('backendReady');
  String get backendNotStarted => _text('backendNotStarted');
  String get backendUnavailable => _text('backendUnavailable');
  String reconnectCacheSummary(
    int pendingApprovals,
    int recentEvents,
    int threads,
  ) => _text('reconnectCacheSummary')
      .replaceAll('{pendingApprovals}', formatNumber(pendingApprovals))
      .replaceAll('{recentEvents}', formatNumber(recentEvents))
      .replaceAll('{threads}', formatNumber(threads));
  String reconnectCacheDeliveredCursor(String cursor) =>
      _text('reconnectCacheDeliveredCursor').replaceAll('{cursor}', cursor);
  String statePath(String path) =>
      _text('statePath').replaceAll('{path}', path);
  String reconnectCacheLoadError(String error) =>
      _text('reconnectCacheLoadError').replaceAll('{error}', error);
  String get connect => _text('connect');
  String get connecting => _text('connecting');
  String get connected => _text('connected');
  String get reconnecting => _text('reconnecting');
  String get restartBackend => _text('restartBackend');
  String get restartingBackend => _text('restartingBackend');
  String get statusIdle => _text('statusIdle');
  String get statusRunning => _text('statusRunning');
  String get statusWorking => _text('statusWorking');
  String get statusFailed => _text('statusFailed');
  String get disconnect => _text('disconnect');
  String get disconnecting => _text('disconnecting');
  String get connectionStatus => _text('connectionStatus');
  String get connectionFailed => _text('connectionFailed');
  String get activeConnection => _text('activeConnection');
  String get noActiveConnection => _text('noActiveConnection');
  String get disconnected => _text('disconnected');
  String get hostKeyConfirmTitle => _text('hostKeyConfirmTitle');
  String hostKeyConfirmBody(
    String endpoint,
    String keyType,
    String fingerprint,
  ) => _text('hostKeyConfirmBody')
      .replaceAll('{endpoint}', endpoint)
      .replaceAll('{keyType}', keyType)
      .replaceAll('{fingerprint}', fingerprint);
  String get hostKeyTrust => _text('hostKeyTrust');
  String get m0ProtocolClient => _text('m0ProtocolClient');
  String get m0ProtocolClientBody => _text('m0ProtocolClientBody');
  String get slashCommandSurface => _text('slashCommandSurface');
  String get slashCommandSurfaceBody => _text('slashCommandSurfaceBody');
  String get showChatAdvancedControls => _text('showChatAdvancedControls');
  String get hideChatAdvancedControls => _text('hideChatAdvancedControls');
  String get rawRpcTitle => _text('rawRpcTitle');
  String get rawRpcDescription => _text('rawRpcDescription');
  String get rawRpcDisconnected => _text('rawRpcDisconnected');
  String get rawRpcMethod => _text('rawRpcMethod');
  String get rawRpcParams => _text('rawRpcParams');
  String get rawRpcConfirm => _text('rawRpcConfirm');
  String get rawRpcSend => _text('rawRpcSend');
  String get rawRpcResult => _text('rawRpcResult');
  String get rawRpcError => _text('rawRpcError');
  String get rawRpcInvalidJsonObject => _text('rawRpcInvalidJsonObject');
  String get rawRpcMethodRequired => _text('rawRpcMethodRequired');
  String get connectBeforeTurn => _text('connectBeforeTurn');
  String get connectBeforeLoadingThreads =>
      _text('connectBeforeLoadingThreads');
  String get refreshThreads => _text('refreshThreads');
  String get activeThreads => _text('activeThreads');
  String get archivedThreads => _text('archivedThreads');
  String get noThreads => _text('noThreads');
  String get noArchivedThreads => _text('noArchivedThreads');
  String get threadListFailed => _text('threadListFailed');
  String get threadDetail => _text('threadDetail');
  String get threadDetailFailed => _text('threadDetailFailed');
  String turnCount(int count) =>
      _text('turnCount').replaceAll('{count}', formatNumber(count));
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
  String get shellCommandFailed => _text('shellCommandFailed');
  String get timeline => _text('timeline');
  String get noTimelineEvents => _text('noTimelineEvents');
  String get timelineUser => _text('timelineUser');
  String get timelineCodex => _text('timelineCodex');
  String get timelineReasoning => _text('timelineReasoning');
  String get timelinePlan => _text('timelinePlan');
  String get timelineCommand => _text('timelineCommand');
  String get timelineToolCall => _text('timelineToolCall');
  String get timelineItem => _text('timelineItem');
  String get timelineStatus => _text('timelineStatus');
  String get timelineExitCode => _text('timelineExitCode');
  String get timelineDuration => _text('timelineDuration');
  String timelineDurationMilliseconds(int milliseconds) => _text(
    'timelineDurationMilliseconds',
  ).replaceAll('{milliseconds}', formatNumber(milliseconds));
  String get timelineFileChanges => _text('timelineFileChanges');
  String get timelineTool => _text('timelineTool');
  String get forkedThread => _text('forkedThread');
  String get subagentThread => _text('subagentThread');
  String get send => _text('send');
  String get slashCommands => _text('slashCommands');
  String get typeCommandName => _text('typeCommandName');
  String slashCommandUnknown(String slash) =>
      _text('slashCommandUnknown').replaceAll('{slash}', slash);
  String slashCommandDescription(String command, String fallback) {
    final languageCode = _supportedLanguageCode(locale);
    return _slashCommandDescriptions[languageCode]?[command] ?? fallback;
  }

  String slashCommandAliases(String aliases) =>
      _text('slashCommandAliases').replaceAll('{aliases}', aliases);
  String slashCommandMappingLabel(String mappingType) =>
      _text('slashCommandMapping.$mappingType');
  String slashCommandPhaseLabel(String phase) =>
      _text('slashCommandPhase.$phase');
  String slashCommandRiskLevelLabel(String riskLevel) =>
      _text('slashCommandRiskLevel.$riskLevel');
  String slashCommandGroupLabel(String group) =>
      _text('slashCommandGroup.$group');
  String slashCommandArgumentHint(String command) {
    final languageCode = _supportedLanguageCode(locale);
    return _slashCommandArgumentHints[languageCode]?[command] ??
        _slashCommandArgumentHints['en']?[command] ??
        '';
  }

  String slashCommandArgs(String hint) =>
      _text('slashCommandArgs').replaceAll('{hint}', hint);
  String get slashCommandNotSentAsPrompt =>
      _text('slashCommandNotSentAsPrompt');
  String get slashCommandSendAsText => _text('slashCommandSendAsText');
  String get slashCommandWillSendAsPrompt =>
      _text('slashCommandWillSendAsPrompt');
  String get slashCommandUnavailableDuringTask =>
      _text('slashCommandUnavailableDuringTask');
  String get slashCommandUnavailableInSideConversation =>
      _text('slashCommandUnavailableInSideConversation');
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
  String get slashCommandDuplicatedThread =>
      _text('slashCommandDuplicatedThread');
  String get slashCommandRewoundThread => _text('slashCommandRewoundThread');
  String get slashCommandCompactionStarted =>
      _text('slashCommandCompactionStarted');
  String get slashCommandArchivedThread => _text('slashCommandArchivedThread');
  String get slashCommandDeletedThread => _text('slashCommandDeletedThread');
  String get slashCommandLoggedOut => _text('slashCommandLoggedOut');
  String get slashCommandFeedbackSubmitted =>
      _text('slashCommandFeedbackSubmitted');
  String get slashCommandAutoReviewApproved =>
      _text('slashCommandAutoReviewApproved');
  String get slashCommandThemeUpdated => _text('slashCommandThemeUpdated');
  String get slashCommandTitleDisplayUpdated =>
      _text('slashCommandTitleDisplayUpdated');
  String get slashCommandStatusLineDisplayUpdated =>
      _text('slashCommandStatusLineDisplayUpdated');
  String get slashCommandIdeContextInserted =>
      _text('slashCommandIdeContextInserted');
  String get slashCommandKeymapUpdated => _text('slashCommandKeymapUpdated');
  String get slashCommandVimModeEnabled => _text('slashCommandVimModeEnabled');
  String get slashCommandVimModeDisabled =>
      _text('slashCommandVimModeDisabled');
  String get slashCommandPetsTuiOnly => _text('slashCommandPetsTuiOnly');
  String get slashCommandPetsHidden => _text('slashCommandPetsHidden');
  String get slashCommandMentionInserted =>
      _text('slashCommandMentionInserted');
  String get slashCommandSideConversationStarted =>
      _text('slashCommandSideConversationStarted');
  String get slashCommandReturnedToMainThread =>
      _text('slashCommandReturnedToMainThread');
  String get slashCommandAgentThreadSelected =>
      _text('slashCommandAgentThreadSelected');
  String get slashCommandAppHandoffUnavailable =>
      _text('slashCommandAppHandoffUnavailable');
  String get slashCommandImportUnavailable =>
      _text('slashCommandImportUnavailable');
  String get slashCommandInitUnavailable =>
      _text('slashCommandInitUnavailable');
  String get slashCommandSandboxSetupUnavailable =>
      _text('slashCommandSandboxSetupUnavailable');
  String get slashCommandSandboxReadDirUnavailable =>
      _text('slashCommandSandboxReadDirUnavailable');
  String slashCommandRolloutCurrentPath(String path) =>
      _text('slashCommandRolloutCurrentPath').replaceAll('{path}', path);
  String get slashCommandRolloutPathUnavailable =>
      _text('slashCommandRolloutPathUnavailable');
  String get slashCommandTestApprovalReason =>
      _text('slashCommandTestApprovalReason');
  String get slashCommandTestApprovalQueued =>
      _text('slashCommandTestApprovalQueued');
  String get slashCommandModelUpdated => _text('slashCommandModelUpdated');
  String get slashCommandPersonalityUpdated =>
      _text('slashCommandPersonalityUpdated');
  String get slashCommandPermissionsUpdated =>
      _text('slashCommandPermissionsUpdated');
  String get slashCommandPlanModeUpdated =>
      _text('slashCommandPlanModeUpdated');
  String slashCommandCancelled(String slash) =>
      _text('slashCommandCancelled').replaceAll('{slash}', slash);
  String slashCommandExecuted(String slash) =>
      _text('slashCommandExecuted').replaceAll('{slash}', slash);
  String slashCommandUnsupported(String slash) =>
      _text('slashCommandUnsupported').replaceAll('{slash}', slash);
  String slashCommandUnsupportedWithStatus(String slash, String status) =>
      _text(
        'slashCommandUnsupportedWithStatus',
      ).replaceAll('{slash}', slash).replaceAll('{status}', status);
  String slashCommandUnsupportedTarget(String target) =>
      _text('slashCommandUnsupportedTarget').replaceAll('{target}', target);
  String slashCommandUnsupportedRisk(String risk) =>
      _text('slashCommandUnsupportedRisk').replaceAll('{risk}', risk);
  String get slashCommandUnsupportedAppServer =>
      _text('slashCommandUnsupportedAppServer');
  String get slashCommandUnsupportedUiOnly =>
      _text('slashCommandUnsupportedUiOnly');
  String get slashCommandUnsupportedAgentFallback =>
      _text('slashCommandUnsupportedAgentFallback');
  String get slashCommandUnsupportedTopology =>
      _text('slashCommandUnsupportedTopology');
  String get slashCommandUnsupportedNotApplicable =>
      _text('slashCommandUnsupportedNotApplicable');
  String get slashCommandUnsupportedDebug =>
      _text('slashCommandUnsupportedDebug');
  String get slashCommandUnsupportedDesktopOnly =>
      _text('slashCommandUnsupportedDesktopOnly');
  String get slashCommandUnsupportedWindowsOnly =>
      _text('slashCommandUnsupportedWindowsOnly');
  String get slashCommandUnsupportedTuiOnly =>
      _text('slashCommandUnsupportedTuiOnly');
  String get slashCommandUnsupportedDebugOnly =>
      _text('slashCommandUnsupportedDebugOnly');
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
  String get approvalKindUserInput => _text('approvalKindUserInput');
  String get approvalKindMcp => _text('approvalKindMcp');
  String get approvalKindUnknown => _text('approvalKindUnknown');
  String get approvalRequestId => _text('approvalRequestId');
  String get approvalThread => _text('approvalThread');
  String get approvalTurn => _text('approvalTurn');
  String get approvalMethod => _text('approvalMethod');
  String get approvalParameterKeys => _text('approvalParameterKeys');
  String get approvalCommand => _text('approvalCommand');
  String get approvalWorkingDirectory => _text('approvalWorkingDirectory');
  String get approvalPermissionScope => _text('approvalPermissionScope');
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
  String get approvalSecondConfirmTitle => _text('approvalSecondConfirmTitle');
  String get approvalSecondConfirmBody => _text('approvalSecondConfirmBody');
  String get approvalSecondConfirmProceed =>
      _text('approvalSecondConfirmProceed');
  String get toolUserInputOther => _text('toolUserInputOther');
  String get toolUserInputOtherDescription =>
      _text('toolUserInputOtherDescription');
  String get toolUserInputAnswer => _text('toolUserInputAnswer');
  String get toolUserInputSelectionRequired =>
      _text('toolUserInputSelectionRequired');
  String get toolUserInputAnswerRequired =>
      _text('toolUserInputAnswerRequired');
  String get toolUserInputSubmit => _text('toolUserInputSubmit');
  String get toolUserInputSubmitting => _text('toolUserInputSubmitting');
  String get toolUserInputShowSecret => _text('toolUserInputShowSecret');
  String get toolUserInputHideSecret => _text('toolUserInputHideSecret');
  String toolUserInputAutoResolution(int seconds) => _text(
    'toolUserInputAutoResolution',
  ).replaceAll('{seconds}', formatNumber(seconds));
  String get serverDefaults => _text('serverDefaults');
  String get serverDefaultsBody => _text('serverDefaultsBody');
  String get appDefaultOverrides => _text('appDefaultOverrides');
  String get modelOverride => _text('modelOverride');
  String get modelProvider => _text('modelProvider');
  String get effortOverride => _text('effortOverride');
  String get personalityOverride => _text('personalityOverride');
  String get serviceTierOverride => _text('serviceTierOverride');
  String get collaborationModeOverride => _text('collaborationModeOverride');
  String get approvalPolicy => _text('approvalPolicy');
  String get permissionProfile => _text('permissionProfile');
  String get sandboxMode => _text('sandboxMode');
  String get cwdOverride => _text('cwdOverride');
  String get applyOverrides => _text('applyOverrides');
  String get clearOverrides => _text('clearOverrides');
  String get restoreServerDefaults => _text('restoreServerDefaults');
  String get overrideSource => _text('overrideSource');
  String get sourceServerDefault => _text('sourceServerDefault');
  String get sourceAppDefault => _text('sourceAppDefault');
  String get sourceSessionOverride => _text('sourceSessionOverride');
  String get sourceTurnOverride => _text('sourceTurnOverride');
  String get sessionOverrides => _text('sessionOverrides');
  String get editSessionOverrides => _text('editSessionOverrides');
  String get applySessionOverrides => _text('applySessionOverrides');
  String get clearSessionOverrides => _text('clearSessionOverrides');
  String get threadSettingsUpdateFailed => _text('threadSettingsUpdateFailed');
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
  String get unarchiveThread => _text('unarchiveThread');
  String get threadUnarchived => _text('threadUnarchived');
  String get deleteThreadTitle => _text('deleteThreadTitle');
  String get deleteThreadBody => _text('deleteThreadBody');
  String get deleteThreadConfirm => _text('deleteThreadConfirm');
  String get logoutAccountTitle => _text('logoutAccountTitle');
  String get logoutAccountBody => _text('logoutAccountBody');
  String get logoutAccountConfirm => _text('logoutAccountConfirm');
  String get feedbackCommandTitle => _text('feedbackCommandTitle');
  String get feedbackCategoryLabel => _text('feedbackCategoryLabel');
  String get feedbackCategoryBug => _text('feedbackCategoryBug');
  String get feedbackCategoryBadResult => _text('feedbackCategoryBadResult');
  String get feedbackCategoryGoodResult => _text('feedbackCategoryGoodResult');
  String get feedbackCategorySafetyCheck =>
      _text('feedbackCategorySafetyCheck');
  String get feedbackCategoryOther => _text('feedbackCategoryOther');
  String get feedbackNoteLabel => _text('feedbackNoteLabel');
  String get feedbackNoteHint => _text('feedbackNoteHint');
  String get feedbackIncludeLogs => _text('feedbackIncludeLogs');
  String get feedbackLogsDisclosure => _text('feedbackLogsDisclosure');
  String get feedbackLogsConfirmTitle => _text('feedbackLogsConfirmTitle');
  String get feedbackLogsConfirmBody => _text('feedbackLogsConfirmBody');
  String get feedbackLogsConfirmSubmit => _text('feedbackLogsConfirmSubmit');
  String get feedbackSubmit => _text('feedbackSubmit');
  String get themeCommandTitle => _text('themeCommandTitle');
  String get themeSystem => _text('themeSystem');
  String get themeLight => _text('themeLight');
  String get themeDark => _text('themeDark');
  String get colorPalette => _text('colorPalette');
  String get colorPaletteBody => _text('colorPaletteBody');
  String colorPaletteLabel(String palette) => _text('colorPalette.$palette');
  String get backgroundConnectionKeepActiveTurn =>
      _text('backgroundConnectionKeepActiveTurn');
  String get backgroundConnectionKeepActiveTurnBody =>
      _text('backgroundConnectionKeepActiveTurnBody');
  String get diagnosticLogs => _text('diagnosticLogs');
  String get diagnosticLogsBody => _text('diagnosticLogsBody');
  String get agentDoctor => _text('agentDoctor');
  String get agentDoctorBody => _text('agentDoctorBody');
  String get refreshAgentDoctor => _text('refreshAgentDoctor');
  String get agentDoctorUnavailable => _text('agentDoctorUnavailable');
  String get agentDoctorLoadFailed => _text('agentDoctorLoadFailed');
  String get agentServiceLogs => _text('agentServiceLogs');
  String get agentServiceLogsBody => _text('agentServiceLogsBody');
  String get refreshAgentServiceLogs => _text('refreshAgentServiceLogs');
  String get agentServiceLogsUnavailable =>
      _text('agentServiceLogsUnavailable');
  String get agentServiceLogsLoadFailed => _text('agentServiceLogsLoadFailed');
  String get agentServiceLogsEmpty => _text('agentServiceLogsEmpty');
  String agentServiceLogsMaxTail(String size) =>
      _text('agentServiceLogsMaxTail').replaceAll('{size}', size);
  String get agentSchema => _text('agentSchema');
  String get agentSchemaBody => _text('agentSchemaBody');
  String get refreshAgentSchema => _text('refreshAgentSchema');
  String get regenerateAgentSchema => _text('regenerateAgentSchema');
  String get agentSchemaStable => _text('agentSchemaStable');
  String get agentSchemaExperimental => _text('agentSchemaExperimental');
  String get agentSchemaUnavailable => _text('agentSchemaUnavailable');
  String get agentSchemaLoadFailed => _text('agentSchemaLoadFailed');
  String get agentSchemaGenerated => _text('agentSchemaGenerated');
  String get agentSchemaCached => _text('agentSchemaCached');
  String get agentSchemaMode => _text('agentSchemaMode');
  String get agentSchemaSource => _text('agentSchemaSource');
  String get agentSchemaFiles => _text('agentSchemaFiles');
  String agentSchemaFilesSummary(int count, String size) => _text(
    'agentSchemaFilesSummary',
  ).replaceAll('{count}', formatNumber(count)).replaceAll('{size}', size);
  String get agentSchemaGeneratedAt => _text('agentSchemaGeneratedAt');
  String get agentSchemaDigest => _text('agentSchemaDigest');
  String get agentSchemaBundle => _text('agentSchemaBundle');
  String get agentSchemaCache => _text('agentSchemaCache');
  String get agentSchemaMetadata => _text('agentSchemaMetadata');
  String get agentSchemaEmpty => _text('agentSchemaEmpty');
  String agentSchemaMoreFiles(int count) =>
      _text('agentSchemaMoreFiles').replaceAll('{count}', formatNumber(count));
  String get agentLogPath => _text('agentLogPath');
  String agentLogSize(String size, String tail) => _text(
    'agentLogSize',
  ).replaceAll('{size}', size).replaceAll('{tail}', tail);
  String get agentLogTruncated => _text('agentLogTruncated');
  String get agentLogMissing => _text('agentLogMissing');
  String get agentLogEmpty => _text('agentLogEmpty');
  String agentLogError(String error) =>
      _text('agentLogError').replaceAll('{error}', error);
  String get agentCodexConfigure => _text('agentCodexConfigure');
  String get agentCodexConfigureBody => _text('agentCodexConfigureBody');
  String get codexArguments => _text('codexArguments');
  String get codexPathPrepend => _text('codexPathPrepend');
  String get fillFromAgentDoctor => _text('fillFromAgentDoctor');
  String get saveAgentCodexConfig => _text('saveAgentCodexConfig');
  String get savingAgentCodexConfig => _text('savingAgentCodexConfig');
  String get agentCodexConfigureFailed => _text('agentCodexConfigureFailed');
  String get codexProgramRequired => _text('codexProgramRequired');
  String get agentConfigPath => _text('agentConfigPath');
  String get codexProgram => _text('codexProgram');
  String get codexSource => _text('codexSource');
  String get codexCommandFailure => _text('codexCommandFailure');
  String get codexStatusFailure => _text('codexStatusFailure');
  String get backendDetail => _text('backendDetail');
  String get copyDiagnosticLogs => _text('copyDiagnosticLogs');
  String get copyingDiagnosticLogs => _text('copyingDiagnosticLogs');
  String get exportDiagnosticLogs => _text('exportDiagnosticLogs');
  String get exportingDiagnosticLogs => _text('exportingDiagnosticLogs');
  String get diagnosticLogsEmpty => _text('diagnosticLogsEmpty');
  String get diagnosticLogsConfirmTitle => _text('diagnosticLogsConfirmTitle');
  String get diagnosticLogsExportConfirmTitle =>
      _text('diagnosticLogsExportConfirmTitle');
  String get diagnosticLogsConfirmBody => _text('diagnosticLogsConfirmBody');
  String diagnosticLogsCopied(int count) =>
      _text('diagnosticLogsCopied').replaceAll('{count}', formatNumber(count));
  String diagnosticLogsExported(int count) => _text(
    'diagnosticLogsExported',
  ).replaceAll('{count}', formatNumber(count));
  String get diagnosticLogsExportFailed => _text('diagnosticLogsExportFailed');
  String get applyTheme => _text('applyTheme');
  String get titleCommandTitle => _text('titleCommandTitle');
  String get titleDisplayThread => _text('titleDisplayThread');
  String get titleDisplayWorkingDirectory =>
      _text('titleDisplayWorkingDirectory');
  String get applyTitleDisplay => _text('applyTitleDisplay');
  String get statusLineCommandTitle => _text('statusLineCommandTitle');
  String get applyStatusLineDisplay => _text('applyStatusLineDisplay');
  String get composerInputModeStandard => _text('composerInputModeStandard');
  String get composerInputModeVim => _text('composerInputModeVim');
  String get composerSendShortcutEnter => _text('composerSendShortcutEnter');
  String get composerSendShortcutCtrlEnter =>
      _text('composerSendShortcutCtrlEnter');
  String get keymapCommandTitle => _text('keymapCommandTitle');
  String get keymapSendShortcutEnter => _text('keymapSendShortcutEnter');
  String get keymapSendShortcutCtrlEnter =>
      _text('keymapSendShortcutCtrlEnter');
  String get applyKeymap => _text('applyKeymap');
  String get composerTerminalPetTuiOnly => _text('composerTerminalPetTuiOnly');
  String get composerTerminalPetHidden => _text('composerTerminalPetHidden');
  String get terminalPetCommandTitle => _text('terminalPetCommandTitle');
  String get terminalPetTuiOnly => _text('terminalPetTuiOnly');
  String get terminalPetHidden => _text('terminalPetHidden');
  String get applyTerminalPetDisplay => _text('applyTerminalPetDisplay');
  String get showUnavailableSlashCommands =>
      _text('showUnavailableSlashCommands');
  String get showUnavailableSlashCommandsBody =>
      _text('showUnavailableSlashCommandsBody');
  String get diffTitle => _text('diffTitle');
  String get diffUnavailable => _text('diffUnavailable');
  String get diffNotGitRepository => _text('diffNotGitRepository');
  String get diffNoChanges => _text('diffNoChanges');
  String get diffLoadFailed => _text('diffLoadFailed');
  String diffTruncated(int shown, int total) => _text('diffTruncated')
      .replaceAll('{shown}', formatNumber(shown))
      .replaceAll('{total}', formatNumber(total));
  String get diffShowFull => _text('diffShowFull');
  String get mentionCommandTitle => _text('mentionCommandTitle');
  String get ideContextCommandTitle => _text('ideContextCommandTitle');
  String get mentionSearchHint => _text('mentionSearchHint');
  String get ideContextSearchHint => _text('ideContextSearchHint');
  String get mentionNoResults => _text('mentionNoResults');
  String get mentionLoadFailed => _text('mentionLoadFailed');
  String get sideConversationTitle => _text('sideConversationTitle');
  String get sideConversationCommand => _text('sideConversationCommand');
  String get sideConversationThread => _text('sideConversationThread');
  String get sideConversationParent => _text('sideConversationParent');
  String get sideConversationDropped => _text('sideConversationDropped');
  String get returnToMainThread => _text('returnToMainThread');
  String get agentTopologyTitle => _text('agentTopologyTitle');
  String get subagentTopologyTitle => _text('subagentTopologyTitle');
  String get agentRole => _text('agentRole');
  String get agentPath => _text('agentPath');
  String get agentParentThread => _text('agentParentThread');
  String get agentAncestorThread => _text('agentAncestorThread');
  String get activeThread => _text('activeThread');
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
  String get refreshAccountStatus => _text('refreshAccountStatus');
  String get accountStatusUnavailable => _text('accountStatusUnavailable');
  String get accountLoadFailed => _text('accountLoadFailed');
  String get accountNotSignedIn => _text('accountNotSignedIn');
  String get accountSignedIn => _text('accountSignedIn');
  String get accountCredentialSource => _text('accountCredentialSource');
  String get openaiAuthRequired => _text('openaiAuthRequired');
  String get openaiAuthNotRequired => _text('openaiAuthNotRequired');
  String get refreshModelList => _text('refreshModelList');
  String get modelListUnavailable => _text('modelListUnavailable');
  String get modelListLoadFailed => _text('modelListLoadFailed');
  String get modelListEmpty => _text('modelListEmpty');
  String availableModels(int count) =>
      _text('availableModels').replaceAll('{count}', formatNumber(count));
  String modelListMore(int count) =>
      _text('modelListMore').replaceAll('{count}', formatNumber(count));
  String get accountUsageStatus => _text('accountUsageStatus');
  String get accountUsageUnavailable => _text('accountUsageUnavailable');
  String get accountUsageLoadFailed => _text('accountUsageLoadFailed');
  String get accountUsageTokenSummary => _text('accountUsageTokenSummary');
  String get accountUsageRecentDaily => _text('accountUsageRecentDaily');
  String get accountUsageRateLimits => _text('accountUsageRateLimits');
  String get accountUsageResetCredits => _text('accountUsageResetCredits');
  String get threadTokenUsageStatus => _text('threadTokenUsageStatus');
  String get threadTokenUsageLast => _text('threadTokenUsageLast');
  String get threadTokenUsageTotal => _text('threadTokenUsageTotal');
  String get threadTokenUsageContextWindow =>
      _text('threadTokenUsageContextWindow');
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
  String get mcpServersReloaded => _text('mcpServersReloaded');
  String mcpServersOAuthLoginStarted(String server) =>
      _text('mcpServersOAuthLoginStarted').replaceAll('{server}', server);
  String mcpServersOAuthUrl(String url) =>
      _text('mcpServersOAuthUrl').replaceAll('{url}', url);
  String mcpServersOAuthUserCode(String code) =>
      _text('mcpServersOAuthUserCode').replaceAll('{code}', code);
  String get mcpServersUnavailable => _text('mcpServersUnavailable');
  String get mcpServersLoadFailed => _text('mcpServersLoadFailed');
  String get mcpServersEmpty => _text('mcpServersEmpty');
  String get mcpServerAuthStatus => _text('mcpServerAuthStatus');
  String get mcpServerTools => _text('mcpServerTools');
  String get mcpServerResources => _text('mcpServerResources');
  String get mcpServerResourceTemplates => _text('mcpServerResourceTemplates');
  String get mcpServerInfo => _text('mcpServerInfo');
  String get mcpServerStartupStatus => _text('mcpServerStartupStatus');
  String get mcpServerStartupError => _text('mcpServerStartupError');
  String get mcpServerStartupFailureReason =>
      _text('mcpServerStartupFailureReason');
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
  String get pluginMutationFailed => _text('pluginMutationFailed');
  String get pluginsEmpty => _text('pluginsEmpty');
  String get pluginMarketplace => _text('pluginMarketplace');
  String get pluginMarketplacePath => _text('pluginMarketplacePath');
  String get pluginMarketplaceErrors => _text('pluginMarketplaceErrors');
  String get pluginDescription => _text('pluginDescription');
  String get pluginVersion => _text('pluginVersion');
  String pluginLocalVersion(String version) =>
      _text('pluginLocalVersion').replaceAll('{version}', version);
  String get pluginSource => _text('pluginSource');
  String get pluginCapabilities => _text('pluginCapabilities');
  String get pluginReadme => _text('pluginReadme');
  String get pluginInstalled => _text('pluginInstalled');
  String get pluginNotInstalled => _text('pluginNotInstalled');
  String get pluginEnabled => _text('pluginEnabled');
  String get pluginDisabled => _text('pluginDisabled');
  String get pluginAvailability => _text('pluginAvailability');
  String pluginInstallRequested(String plugin) =>
      _text('pluginInstallRequested').replaceAll('{plugin}', plugin);
  String pluginUninstallRequested(String plugin) =>
      _text('pluginUninstallRequested').replaceAll('{plugin}', plugin);
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
  String get debugConfigOriginUnknown => _text('debugConfigOriginUnknown');
  String get debugConfigLayerConfig => _text('debugConfigLayerConfig');
  String get debugConfigLayerMetadata => _text('debugConfigLayerMetadata');
  String get debugConfigLayerUnknown => _text('debugConfigLayerUnknown');
  String get experimentalTitle => _text('experimentalTitle');
  String get experimentalUnavailable => _text('experimentalUnavailable');
  String get experimentalLoadFailed => _text('experimentalLoadFailed');
  String get experimentalNoSnapshot => _text('experimentalNoSnapshot');
  String get experimentalApiCapability => _text('experimentalApiCapability');
  String get experimentalConfigValues => _text('experimentalConfigValues');
  String get experimentalNoConfigValues => _text('experimentalNoConfigValues');
  String get memoriesTitle => _text('memoriesTitle');
  String get memoriesUnavailable => _text('memoriesUnavailable');
  String get memoriesLoadFailed => _text('memoriesLoadFailed');
  String get memoriesNoSnapshot => _text('memoriesNoSnapshot');
  String get memoriesConfigValues => _text('memoriesConfigValues');
  String get memoriesNoConfigValues => _text('memoriesNoConfigValues');
  String get memoriesThreadMode => _text('memoriesThreadMode');
  String get memoriesUnknownThreadMode => _text('memoriesUnknownThreadMode');
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
  String get totalTokens => _text('totalTokens');
  String get inputTokens => _text('inputTokens');
  String get cachedInputTokens => _text('cachedInputTokens');
  String get outputTokens => _text('outputTokens');
  String get reasoningOutputTokens => _text('reasoningOutputTokens');
  String tokenCount(int count) =>
      _text('tokenCount').replaceAll('{count}', formatNumber(count));
  String dayCount(int count) =>
      _text('dayCount').replaceAll('{count}', formatNumber(count));
  String secondCount(int count) =>
      _text('secondCount').replaceAll('{count}', formatNumber(count));
  String rateLimitUsedPercent(int percent) => _text(
    'rateLimitUsedPercent',
  ).replaceAll('{percent}', formatNumber(percent));
  String rateLimitWindowMinutes(int minutes) => _text(
    'rateLimitWindowMinutes',
  ).replaceAll('{minutes}', formatNumber(minutes));
  String rateLimitResetsAt(int timestamp) => _text(
    'rateLimitResetsAt',
  ).replaceAll('{timestamp}', formatUnixTimestampSeconds(timestamp));
  String rateLimitReached(String type) =>
      _text('rateLimitReached').replaceAll('{type}', type);
  String creditsBalance(String balance) =>
      _text('creditsBalance').replaceAll('{balance}', balance);
  String individualLimitUsed(String used) =>
      _text('individualLimitUsed').replaceAll('{used}', used);
  String individualLimitRemaining(int percent) => _text(
    'individualLimitRemaining',
  ).replaceAll('{percent}', formatNumber(percent));
  String resetCreditsAvailable(int count) =>
      _text('resetCreditsAvailable').replaceAll('{count}', formatNumber(count));
  String configLayersLoaded(int count) =>
      _text('configLayersLoaded').replaceAll('{count}', formatNumber(count));
  String debugConfigLayers(int count) =>
      _text('debugConfigLayers').replaceAll('{count}', formatNumber(count));
  String debugConfigLayer(int index) =>
      _text('debugConfigLayer').replaceAll('{index}', formatNumber(index));
  String get theme => _text('theme');
  String get themeBody => _text('themeBody');
  String get fontSize => _text('fontSize');
  String get fontSizeBody => _text('fontSizeBody');
  String fontSizeLabel(String value) => _text('fontSize.$value');
  String get advancedAppearance => _text('advancedAppearance');
  String get workspaceFilesTitle => _text('workspaceFilesTitle');
  String workspaceFilesRoot(String root) =>
      _text('workspaceFilesRoot').replaceAll('{root}', root);
  String get workspaceFilesRootLabel => _text('workspaceFilesRootLabel');
  String get workspaceFilesUseRoot => _text('workspaceFilesUseRoot');
  String get workspaceFilesUseDefaultRoot =>
      _text('workspaceFilesUseDefaultRoot');
  String get workspaceFilesSaveDefaultRoot =>
      _text('workspaceFilesSaveDefaultRoot');
  String get workspaceFilesSidebar => _text('workspaceFilesSidebar');
  String get workspaceFilesNotConnected => _text('workspaceFilesNotConnected');
  String get workspaceFilesNoCwd => _text('workspaceFilesNoCwd');
  String get workspaceFilesRefresh => _text('workspaceFilesRefresh');
  String get workspaceFilesSearchHint => _text('workspaceFilesSearchHint');
  String get workspaceFilesShowHidden => _text('workspaceFilesShowHidden');
  String get workspaceFilesEmptyDirectory =>
      _text('workspaceFilesEmptyDirectory');
  String get workspaceFilesLoadMore => _text('workspaceFilesLoadMore');
  String get workspaceFilesLoading => _text('workspaceFilesLoading');
  String get workspaceFilesOpenFailed => _text('workspaceFilesOpenFailed');
  String get workspaceFilesCopyPath => _text('workspaceFilesCopyPath');
  String get workspaceFilesPathCopied => _text('workspaceFilesPathCopied');
  String get workspaceFilesPreviewEmpty => _text('workspaceFilesPreviewEmpty');
  String get workspaceFilesRaw => _text('workspaceFilesRaw');
  String get workspaceFilesRendered => _text('workspaceFilesRendered');
  String get workspaceFilesMarkdownRenderLimited =>
      _text('workspaceFilesMarkdownRenderLimited');
  String get workspaceFilesLargeFile => _text('workspaceFilesLargeFile');
  String get workspaceFilesBinary => _text('workspaceFilesBinary');
  String get workspaceFilesNotFound => _text('workspaceFilesNotFound');
  String get workspaceFilesPermissionDenied =>
      _text('workspaceFilesPermissionDenied');
  String get workspaceFilesPathOutsideRoot =>
      _text('workspaceFilesPathOutsideRoot');
  String get workspaceFilesReadFailed => _text('workspaceFilesReadFailed');
  String get workspaceFilesTooLarge => _text('workspaceFilesTooLarge');
  String workspaceFilesFileSize(int sizeBytes) => _text(
    'workspaceFilesFileSize',
  ).replaceAll('{size}', formatFileSize(sizeBytes));
  String workspaceFilesModifiedAt(DateTime modifiedAt) => _text(
    'workspaceFilesModifiedAt',
  ).replaceAll('{timestamp}', formatDateTime(modifiedAt));
  String workspaceFilesFileType(String type) =>
      _text('workspaceFilesFileType').replaceAll('{type}', type);
  String get workspaceFilesKindFile => _text('workspaceFilesKindFile');
  String get workspaceFilesKindDirectory =>
      _text('workspaceFilesKindDirectory');
  String get workspaceFilesKindUnknown => _text('workspaceFilesKindUnknown');
  String get workspaceFilesDirectoryLoadFailed =>
      _text('workspaceFilesDirectoryLoadFailed');
  String get workspaceFilesRetry => _text('workspaceFilesRetry');
  String workspaceFilesLoadedBytes(int loaded, int total) =>
      _text('workspaceFilesLoadedBytes')
          .replaceAll('{loaded}', formatFileSize(loaded))
          .replaceAll('{total}', formatFileSize(total));
  String get terminalTitle => _text('terminalTitle');
  String terminalCwd(String cwd) =>
      _text('terminalCwd').replaceAll('{cwd}', cwd);
  String get terminalCommand => _text('terminalCommand');
  String get terminalRun => _text('terminalRun');
  String get terminalNotConnected => _text('terminalNotConnected');
  String get terminalNoCwd => _text('terminalNoCwd');
  String get terminalNoOutput => _text('terminalNoOutput');
  String get terminalOutputCapped => _text('terminalOutputCapped');
  String get terminalInput => _text('terminalInput');
  String get terminalSendInput => _text('terminalSendInput');
  String get terminalCloseStdin => _text('terminalCloseStdin');
  String get terminalTerminate => _text('terminalTerminate');
  String get terminalIdle => _text('terminalIdle');
  String get terminalStarting => _text('terminalStarting');
  String get terminalRunning => _text('terminalRunning');
  String terminalExitCode(int code) =>
      _text('terminalExitCode').replaceAll('{code}', formatNumber(code));
  String terminalFailed(String error) =>
      _text('terminalFailed').replaceAll('{error}', error);

  String formatNumber(num value) =>
      NumberFormat.decimalPattern(_intlLocale).format(value);

  String formatUnixTimestampSeconds(int timestamp) {
    return formatDateTime(
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true),
    );
  }

  String formatDateTime(DateTime dateTime) {
    initializeDateFormatting(_intlLocale);
    return DateFormat.yMd(_intlLocale).add_Hm().format(dateTime);
  }

  String formatFileSize(int bytes) {
    final safeBytes = bytes < 0 ? 0 : bytes;
    if (safeBytes < 1024) {
      return '${formatNumber(safeBytes)} B';
    }

    var value = safeBytes / 1024;
    var unit = 'KB';
    if (value >= 1024) {
      value /= 1024;
      unit = 'MB';
    }
    if (value >= 1024) {
      value /= 1024;
      unit = 'GB';
    }

    final pattern = value < 10 && value.truncateToDouble() != value
        ? '#,##0.#'
        : '#,##0';
    return '${NumberFormat(pattern, _intlLocale).format(value)} $unit';
  }

  String _text(String key) {
    final languageCode = _supportedLanguageCode(locale);
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }

  String get _intlLocale {
    final languageCode = _supportedLanguageCode(locale);
    return _intlLocaleForLanguage(languageCode);
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _values.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    final languageCode = _supportedLanguageCode(locale);
    final resolvedLocale = switch (languageCode) {
      'zh' => const Locale('zh', 'CN'),
      _ => const Locale('en', 'US'),
    };
    initializeDateFormatting(_intlLocaleForLanguage(languageCode));
    return SynchronousFuture(AppLocalizations(resolvedLocale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

String _supportedLanguageCode(Locale locale) {
  return _values.containsKey(locale.languageCode) ? locale.languageCode : 'en';
}

String _intlLocaleForLanguage(String languageCode) {
  return switch (languageCode) {
    'zh' => 'zh_CN',
    _ => 'en_US',
  };
}

const _values = <String, Map<String, String>>{
  'en': {
    'appTitle': 'SadCoder',
    'messageWithDetail': '{message}: {detail}',
    'hosts': 'Hosts',
    'chat': 'Chat',
    'files': 'Files',
    'sessions': 'Sessions',
    'approvals': 'Approvals',
    'settings': 'Settings',
    'settingsSectionPermissions': 'Permissions',
    'settingsSectionAccount': 'Account',
    'settingsSectionModels': 'Models',
    'settingsSectionAppearance': 'Appearance',
    'settingsSectionSsh': 'SSH',
    'settingsSectionDiagnostics': 'Diagnostics',
    'settingsSectionUnavailable': 'This settings group is not available yet.',
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
    'profileLoaded': 'Profile loaded.',
    'savedHosts': 'Saved hosts',
    'noSavedHosts': 'No saved SSH profiles.',
    'useSshProfile': 'Use profile',
    'deleteSshProfile': 'Delete profile',
    'deleteSshProfileTitle': 'Delete SSH profile?',
    'deleteSshProfileBody':
        'Delete {name} from saved hosts. Stored credentials for this profile will also be removed.',
    'sshProfileDeleted': 'SSH profile deleted.',
    'sshProfileDeleteFailed': 'SSH profile delete failed',
    'savedHostProfileCount': '{count} profiles',
    'importSshConfig': 'Import SSH config',
    'importingSshConfig': 'Importing config',
    'sshConfigImported': '{count} SSH profiles imported.',
    'sshConfigImportFailed': 'SSH config import failed',
    'sshConfigImportNoHosts': 'No importable SSH Host entries were found.',
    'importPrivateKeyFile': 'Import private key',
    'importingPrivateKey': 'Importing private key',
    'privateKeyImportedAndSaved':
        'Private key imported and profile saved securely.',
    'privateKeyImportNeedsProfile':
        'Private key imported. Complete host and username, then save the profile to store it securely.',
    'privateKeyImportFailed': 'Private key import failed',
    'privateKeyImportNoPemBlock':
        'No PEM private key block was found in the selected file.',
    'generateEd25519Key': 'Generate ED25519',
    'generateRsaKey': 'Generate RSA',
    'generatingSshKey': 'Generating key',
    'generatedPublicKey': 'Generated public key',
    'copyPublicKey': 'Copy public key',
    'publicKeyCopied': 'Public key copied.',
    'exportPublicKey': 'Export public key',
    'exportingPublicKey': 'Exporting public key',
    'publicKeyExported': 'Public key exported.',
    'publicKeyExportFailed': 'Public key export failed',
    'sshKeyGeneratedAndSaved': 'SSH key generated and profile saved securely.',
    'sshKeyGenerationNeedsProfile':
        'SSH key generated. Complete host and username, then save the profile to store it securely.',
    'sshKeyGenerationFailed': 'SSH key generation failed',
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
    'tcpConnect': 'TCP connect',
    'sshHandshake': 'SSH handshake',
    'hostKey': 'Host key',
    'sshAuth': 'SSH auth',
    'remoteShell': 'Remote shell',
    'codexVersion': 'Codex version',
    'agentVersion': 'Agent version',
    'agentStatus': 'Agent status',
    'agentStart': 'Agent start',
    'proxyConnect': 'Proxy connect',
    'agentHello': 'Agent hello',
    'initialize': 'Initialize',
    'accountRead': 'Account read',
    'modelList': 'Model list',
    'configRead': 'Config read',
    'permissionProfileList': 'Permission profile list',
    'threadList': 'Thread list (limit 1)',
    'probeSuggestionCheckNetwork':
        'Check the host, port, VPN, firewall, and network reachability.',
    'probeSuggestionCheckSshServer':
        'Check that the SSH server is running and accepts this protocol.',
    'probeSuggestionVerifyHostKey':
        'Verify the SSH host key fingerprint before trusting this host.',
    'probeSuggestionCheckAuth':
        'Check the username and password or private key credentials.',
    'probeSuggestionCheckRemoteShell':
        'Ensure the remote login shell can execute non-interactive commands.',
    'probeSuggestionInstallCodex':
        'Install Codex on the remote host or add it to PATH.',
    'probeSuggestionUpdateCodex': 'Update Codex to a supported version.',
    'probeSuggestionInstallAgent':
        'Install sadcoder-agent or fix the agent command path.',
    'probeSuggestionStartAgent':
        'Start the agent/backend and check its service logs.',
    'probeSuggestionCheckBackend':
        'Check the SadCoder agent service/backend status and logs.',
    'probeSuggestionLoginCodex':
        'Run codex login or configure an API key on the remote host.',
    'probeSuggestionCheckCwdOrPermissions':
        'Check the configured cwd and remote file permissions.',
    'probeSuggestionRetryProxy':
        'Check sadcoder-agent proxy and backend logs, then retry.',
    'backend': 'Backend',
    'backendAgentService': 'agent service',
    'backendDaemon': 'legacy daemon',
    'backendStdioFallback': 'stdio fallback',
    'backendUnknown': 'unknown',
    'backendReady': 'ready',
    'backendNotStarted': 'not started',
    'backendUnavailable': 'unavailable',
    'reconnectCacheSummary':
        'Reconnect cache: {pendingApprovals} pending approvals, {recentEvents} recent events, {threads} threads',
    'reconnectCacheDeliveredCursor': 'Delivered cursor: {cursor}',
    'statePath': 'State path: {path}',
    'reconnectCacheLoadError': 'Reconnect cache load error: {error}',
    'connect': 'Connect',
    'connecting': 'Connecting',
    'connected': 'Connected',
    'reconnecting': 'Reconnecting',
    'restartBackend': 'Restart backend',
    'restartingBackend': 'Restarting backend',
    'statusIdle': 'Idle',
    'statusRunning': 'Running',
    'statusWorking': 'Working',
    'statusFailed': 'Failed',
    'disconnect': 'Disconnect',
    'disconnecting': 'Disconnecting',
    'connectionStatus': 'Connection status',
    'connectionFailed': 'Connection failed',
    'activeConnection': 'Active connection',
    'noActiveConnection': 'No active connection',
    'disconnected': 'Disconnected',
    'hostKeyConfirmTitle': 'Trust this SSH host key?',
    'hostKeyConfirmBody':
        'This is the first time SadCoder has seen {endpoint}.\n\nKey type: {keyType}\nFingerprint: {fingerprint}\n\nOnly continue if this fingerprint matches the server you expect.',
    'hostKeyTrust': 'Trust and continue',
    'm0ProtocolClient': 'M0 protocol client',
    'm0ProtocolClientBody':
        'The app has a JSON-RPC client for initialize, model/list, and thread/list. SSH transport uses the same interface.',
    'slashCommandSurface': 'Slash command surface',
    'slashCommandSurfaceBody':
        'Typing / will later open the SadCoder command palette instead of sending slash text as a normal prompt.',
    'showChatAdvancedControls': 'Advanced controls',
    'hideChatAdvancedControls': 'Hide advanced controls',
    'rawRpcTitle': 'Raw RPC',
    'rawRpcDescription':
        'Developer-only app-server JSON-RPC request. Use only when a feature is not modeled yet.',
    'rawRpcDisconnected': 'Connect to a host before sending raw RPC.',
    'rawRpcMethod': 'Method',
    'rawRpcParams': 'Params JSON object',
    'rawRpcConfirm': 'I understand this raw request may change server state.',
    'rawRpcSend': 'Send raw RPC',
    'rawRpcResult': 'Result',
    'rawRpcError': 'Error',
    'rawRpcInvalidJsonObject': 'Params must be a JSON object',
    'rawRpcMethodRequired': 'Method is required.',
    'connectBeforeTurn': 'Connect to a host before sending a turn',
    'connectBeforeLoadingThreads': 'Connect to a host to load sessions.',
    'refreshThreads': 'Refresh sessions',
    'activeThreads': 'Active',
    'archivedThreads': 'Archived',
    'noThreads': 'No sessions found',
    'noArchivedThreads': 'No archived sessions found',
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
    'shellCommandFailed': 'Shell command failed',
    'timeline': 'Timeline',
    'noTimelineEvents': 'No events yet',
    'timelineUser': 'You',
    'timelineCodex': 'Codex',
    'timelineReasoning': 'Reasoning',
    'timelinePlan': 'Plan',
    'timelineCommand': 'Command',
    'timelineToolCall': 'Tool call',
    'timelineItem': 'Item',
    'timelineStatus': 'Status',
    'timelineExitCode': 'Exit code',
    'timelineDuration': 'Duration',
    'timelineDurationMilliseconds': '{milliseconds} ms',
    'timelineFileChanges': 'File changes',
    'timelineTool': 'Tool',
    'forkedThread': 'fork',
    'subagentThread': 'subagent',
    'send': 'Send',
    'slashCommands': 'Slash commands',
    'typeCommandName': 'Type a command name',
    'slashCommandUnknown': 'Unknown command: {slash}',
    'slashCommandAliases': 'aliases: {aliases}',
    'slashCommandMapping.appServer': 'app-server',
    'slashCommandMapping.uiOnly': 'UI',
    'slashCommandMapping.agentFallback': 'agent fallback',
    'slashCommandMapping.topology': 'topology',
    'slashCommandMapping.notApplicable': 'not applicable',
    'slashCommandMapping.debug': 'debug',
    'slashCommandPhase.mvp': 'MVP',
    'slashCommandPhase.secondStage': 'second stage',
    'slashCommandPhase.secondStageExperimental': 'experimental',
    'slashCommandPhase.thirdStage': 'third stage',
    'slashCommandPhase.advancedDebug': 'debug',
    'slashCommandRiskLevel.low': 'low',
    'slashCommandRiskLevel.medium': 'medium',
    'slashCommandRiskLevel.high': 'high',
    'slashCommandGroup.common': 'Common',
    'slashCommandGroup.session': 'Session',
    'slashCommandGroup.configuration': 'Configuration',
    'slashCommandGroup.filesAndCommands': 'Files and commands',
    'slashCommandGroup.mcpAndExtensions': 'MCP and extensions',
    'slashCommandGroup.debug': 'Debug',
    'slashCommandArgs': 'Args: {hint}',
    'slashCommandNotSentAsPrompt': 'Not sent as a prompt',
    'slashCommandSendAsText': 'Send as text',
    'slashCommandWillSendAsPrompt': 'Will be sent as a prompt',
    'slashCommandUnavailableDuringTask': 'Unavailable while a turn is active',
    'slashCommandUnavailableInSideConversation':
        'Unavailable in a side conversation',
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
    'slashCommandDuplicatedThread': 'Duplicated thread.',
    'slashCommandRewoundThread': 'Rewound thread.',
    'slashCommandCompactionStarted': 'Started thread compaction.',
    'slashCommandArchivedThread': 'Archived thread.',
    'slashCommandDeletedThread': 'Deleted thread.',
    'slashCommandLoggedOut': 'Signed out of Codex account.',
    'slashCommandFeedbackSubmitted': 'Feedback submitted.',
    'slashCommandAutoReviewApproved': 'Approved a recent auto-review denial.',
    'slashCommandThemeUpdated': 'Theme updated.',
    'slashCommandTitleDisplayUpdated': 'Title display updated.',
    'slashCommandStatusLineDisplayUpdated': 'Status line display updated.',
    'slashCommandIdeContextInserted': 'Mobile context attached.',
    'slashCommandKeymapUpdated': 'Keyboard shortcut settings updated.',
    'slashCommandVimModeEnabled': 'Composer Vim mode enabled.',
    'slashCommandVimModeDisabled': 'Composer Vim mode disabled.',
    'slashCommandPetsTuiOnly': 'Terminal pet remains TUI-only on mobile.',
    'slashCommandPetsHidden': 'Terminal pet hidden on mobile.',
    'slashCommandMentionInserted': 'File mention inserted.',
    'slashCommandSideConversationStarted': 'Started side conversation.',
    'slashCommandReturnedToMainThread': 'Returned to main thread.',
    'slashCommandAgentThreadSelected': 'Selected agent thread.',
    'slashCommandAppHandoffUnavailable':
        'Codex Desktop handoff is not available in the mobile app.',
    'slashCommandImportUnavailable':
        'Claude Code import is not wired in the mobile app yet. It requires a guarded agent fallback on the selected host.',
    'slashCommandInitUnavailable':
        'AGENTS.md initialization is not wired in the mobile app yet. It requires a generated diff preview and approval before writing files.',
    'slashCommandSandboxSetupUnavailable':
        'Default sandbox setup is not wired in the mobile app yet. It requires a guarded agent fallback and high-risk confirmation on the selected host.',
    'slashCommandSandboxReadDirUnavailable':
        'Sandbox read-directory configuration is not wired in the mobile app yet. It requires a guarded Windows agent fallback and high-risk confirmation.',
    'slashCommandRolloutCurrentPath': 'Current rollout path: {path}',
    'slashCommandRolloutPathUnavailable': 'Rollout path is not available yet.',
    'slashCommandTestApprovalReason': 'SadCoder test approval request',
    'slashCommandTestApprovalQueued': 'Test approval request queued.',
    'slashCommandModelUpdated': 'Model override updated.',
    'slashCommandPersonalityUpdated': 'Personality override updated.',
    'slashCommandPermissionsUpdated': 'Permission override updated.',
    'slashCommandPlanModeUpdated': 'Plan mode applied.',
    'slashCommandCancelled': 'Canceled {slash}.',
    'slashCommandExecuted': 'Executed {slash}.',
    'slashCommandUnsupported': '{slash} is not implemented yet.',
    'slashCommandUnsupportedWithStatus':
        '{slash} is registered but not available: {status}.',
    'slashCommandUnsupportedTarget': 'Planned path: {target}.',
    'slashCommandUnsupportedRisk': 'Risk: {risk}.',
    'slashCommandUnsupportedAppServer':
        'mobile app-server handler is not wired yet',
    'slashCommandUnsupportedUiOnly': 'mobile UI flow is not wired yet',
    'slashCommandUnsupportedAgentFallback':
        'guarded agent fallback is not wired yet',
    'slashCommandUnsupportedTopology':
        'thread topology action is not wired yet',
    'slashCommandUnsupportedNotApplicable': 'not applicable in the mobile app',
    'slashCommandUnsupportedDebug':
        'advanced debug command is not wired in mobile',
    'slashCommandUnsupportedDesktopOnly': 'desktop-only command',
    'slashCommandUnsupportedWindowsOnly': 'Windows-only command',
    'slashCommandUnsupportedTuiOnly': 'TUI-only command',
    'slashCommandUnsupportedDebugOnly': 'debug-only command',
    'slashCommandUnavailable': '{slash} is unavailable right now.',
    'slashCommandFailed': '{slash} failed: {error}',
    'noPendingApprovals': 'No pending approvals',
    'approvalsBody':
        'Command, file, Codex question, and MCP requests will appear here with their thread and turn IDs.',
    'approvalKindCommand': 'Command approval',
    'approvalKindFileChange': 'File change approval',
    'approvalKindPermissions': 'Permission approval',
    'approvalKindUserInput': 'Question from Codex',
    'approvalKindMcp': 'MCP elicitation',
    'approvalKindUnknown': 'Unknown request',
    'approvalRequestId': 'Request',
    'approvalThread': 'Thread',
    'approvalTurn': 'Turn',
    'approvalMethod': 'Method',
    'approvalParameterKeys': 'Parameter keys',
    'approvalCommand': 'Command',
    'approvalWorkingDirectory': 'Working directory',
    'approvalPermissionScope': 'Permission scope',
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
    'approvalSecondConfirmTitle': 'Confirm approval',
    'approvalSecondConfirmBody':
        'This request looks high-risk. Review the command or file change before approving it.',
    'approvalSecondConfirmProceed': 'Approve anyway',
    'toolUserInputOther': 'Other',
    'toolUserInputOtherDescription': 'Enter a different answer.',
    'toolUserInputAnswer': 'Answer',
    'toolUserInputSelectionRequired': 'Select an option.',
    'toolUserInputAnswerRequired': 'Enter an answer.',
    'toolUserInputSubmit': 'Submit answers',
    'toolUserInputSubmitting': 'Submitting...',
    'toolUserInputShowSecret': 'Show secret',
    'toolUserInputHideSecret': 'Hide secret',
    'toolUserInputAutoResolution':
        'Codex may continue automatically after {seconds} seconds.',
    'serverDefaults': 'Server defaults',
    'serverDefaultsBody':
        'Codex configuration is inherited from the server unless an override is explicitly set.',
    'appDefaultOverrides': 'App default overrides',
    'modelOverride': 'Model',
    'modelProvider': 'Model provider',
    'effortOverride': 'Reasoning effort',
    'personalityOverride': 'Personality',
    'serviceTierOverride': 'Service tier',
    'collaborationModeOverride': 'Collaboration mode',
    'approvalPolicy': 'Approval policy',
    'permissionProfile': 'Permission profile',
    'sandboxMode': 'Sandbox mode',
    'cwdOverride': 'Working directory',
    'applyOverrides': 'Apply overrides',
    'clearOverrides': 'Clear overrides',
    'restoreServerDefaults': 'Restore server defaults',
    'overrideSource': 'Source',
    'sourceServerDefault': 'server default',
    'sourceAppDefault': 'app default',
    'sourceSessionOverride': 'session override',
    'sourceTurnOverride': 'turn override',
    'sessionOverrides': 'Session overrides',
    'editSessionOverrides': 'Edit session overrides',
    'applySessionOverrides': 'Apply to session',
    'clearSessionOverrides': 'Clear session overrides',
    'threadSettingsUpdateFailed': 'Failed to update session settings',
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
    'unarchiveThread': 'Restore thread',
    'threadUnarchived': 'Restored thread.',
    'deleteThreadTitle': 'Delete thread?',
    'deleteThreadBody':
        'This permanently deletes the current thread and spawned descendant threads. This cannot be undone.',
    'deleteThreadConfirm': 'Delete',
    'logoutAccountTitle': 'Sign out of Codex?',
    'logoutAccountBody':
        'This signs the server Codex account out for every client using the same CODEX_HOME. Server tasks are not interrupted.',
    'logoutAccountConfirm': 'Sign out',
    'feedbackCommandTitle': 'Send feedback',
    'feedbackCategoryLabel': 'Category',
    'feedbackCategoryBug': 'Bug',
    'feedbackCategoryBadResult': 'Bad result',
    'feedbackCategoryGoodResult': 'Good result',
    'feedbackCategorySafetyCheck': 'Safety check',
    'feedbackCategoryOther': 'Other',
    'feedbackNoteLabel': 'Note',
    'feedbackNoteHint': 'Optional details',
    'feedbackIncludeLogs': 'Include server logs',
    'feedbackLogsDisclosure':
        'Logs may include prompts, paths, commands, and diagnostic details from this server.',
    'feedbackLogsConfirmTitle': 'Send logs with feedback?',
    'feedbackLogsConfirmBody':
        'SadCoder redacts diagnostic logs it captures, but server logs may still include paths, commands, project names, and prompts. Review your note before sending.',
    'feedbackLogsConfirmSubmit': 'Send with logs',
    'feedbackSubmit': 'Send feedback',
    'themeCommandTitle': 'Theme',
    'themeSystem': 'System',
    'themeLight': 'Light',
    'themeDark': 'Dark',
    'colorPalette': 'Color palette',
    'colorPaletteBody':
        'Choose an app accent palette while code, diff, and terminal colors stay semantic.',
    'colorPalette.sadcoder': 'SadCoder',
    'colorPalette.candy': 'Candy',
    'colorPalette.pastel-candy': 'Pastel Candy',
    'colorPalette.candy-tones': 'Candy Tones',
    'colorPalette.candy-pop': 'Candy Pop',
    'colorPalette.sugar-rush': 'Sugar Rush',
    'colorPalette.lagoon': 'Lagoon',
    'colorPalette.ember': 'Ember',
    'fontSize': 'Font size',
    'fontSizeBody': 'Scale app text for dense or comfortable reading.',
    'fontSize.extra-small': 'Extra small',
    'fontSize.small': 'Small',
    'fontSize.medium': 'Medium',
    'fontSize.large': 'Large',
    'fontSize.extra-large': 'Extra large',
    'advancedAppearance': 'Advanced appearance',
    'backgroundConnectionKeepActiveTurn':
        'Keep active turns connected in background',
    'backgroundConnectionKeepActiveTurnBody':
        'When enabled, SadCoder keeps observing an active turn while the app is backgrounded. When disabled, it disconnects and backfills on the next connection.',
    'diagnosticLogs': 'Diagnostic logs',
    'diagnosticLogsBody':
        'Redacted JSON-RPC messages from the current connection.',
    'agentDoctor': 'Agent doctor',
    'agentDoctorBody':
        'Non-mutating Codex, backend, and reconnect-cache diagnostics from sadcoder-agent.',
    'refreshAgentDoctor': 'Run agent doctor',
    'agentDoctorUnavailable': 'Connect to a host, then run agent doctor.',
    'agentDoctorLoadFailed': 'Failed to run agent doctor',
    'agentServiceLogs': 'Agent service logs',
    'agentServiceLogsBody':
        'Bounded stderr tail from the sadcoder-agent service and app-server.',
    'refreshAgentServiceLogs': 'Refresh agent logs',
    'agentServiceLogsUnavailable': 'Connect to a host, then refresh logs.',
    'agentServiceLogsLoadFailed': 'Failed to load agent service logs',
    'agentServiceLogsEmpty': 'No agent service logs returned.',
    'agentServiceLogsMaxTail': 'Maximum returned tail: {size}',
    'agentSchema': 'App-server schema',
    'agentSchemaBody':
        'Cached JSON Schema generated by sadcoder-agent for app-server compatibility diagnostics.',
    'refreshAgentSchema': 'Refresh schema cache',
    'regenerateAgentSchema': 'Regenerate schema cache',
    'agentSchemaStable': 'Stable',
    'agentSchemaExperimental': 'Experimental',
    'agentSchemaUnavailable':
        'Connect to a host, then refresh schema diagnostics.',
    'agentSchemaLoadFailed': 'Failed to load app-server schema diagnostics',
    'agentSchemaGenerated': 'Schema cache was generated during this request.',
    'agentSchemaCached': 'Read existing schema cache.',
    'agentSchemaMode': 'Schema mode',
    'agentSchemaSource': 'Schema source',
    'agentSchemaFiles': 'Schema files',
    'agentSchemaFilesSummary': '{count} files, {size}',
    'agentSchemaGeneratedAt': 'Generated at',
    'agentSchemaDigest': 'Schema digest',
    'agentSchemaBundle': 'Schema bundle',
    'agentSchemaCache': 'Schema cache',
    'agentSchemaMetadata': 'Schema metadata',
    'agentSchemaEmpty': 'No schema files returned.',
    'agentSchemaMoreFiles': '{count} more schema files.',
    'agentLogPath': 'Log path',
    'agentLogSize': 'Log size: {size}; returned tail: {tail}',
    'agentLogTruncated': 'Showing the newest portion of this log.',
    'agentLogMissing': 'Log file has not been created yet.',
    'agentLogEmpty': 'Log file is empty.',
    'agentLogError': 'Log read error: {error}',
    'agentCodexConfigure': 'Codex configuration',
    'agentCodexConfigureBody':
        'Persist the Codex program and PATH prepends used by sadcoder-agent.',
    'codexArguments': 'Codex arguments',
    'codexPathPrepend': 'PATH prepend',
    'fillFromAgentDoctor': 'Fill from doctor',
    'saveAgentCodexConfig': 'Save config',
    'savingAgentCodexConfig': 'Saving config',
    'agentCodexConfigureFailed': 'Failed to save Codex config',
    'codexProgramRequired': 'Codex program is required.',
    'agentConfigPath': 'Agent config',
    'codexProgram': 'Codex program',
    'codexSource': 'Codex source',
    'codexCommandFailure': 'Codex command failure',
    'codexStatusFailure': 'Codex status failure',
    'backendDetail': 'Backend detail',
    'copyDiagnosticLogs': 'Copy logs',
    'copyingDiagnosticLogs': 'Copying logs',
    'exportDiagnosticLogs': 'Export logs',
    'exportingDiagnosticLogs': 'Exporting logs',
    'diagnosticLogsEmpty': 'No diagnostic logs captured yet.',
    'diagnosticLogsConfirmTitle': 'Copy diagnostic logs?',
    'diagnosticLogsExportConfirmTitle': 'Export diagnostic logs?',
    'diagnosticLogsConfirmBody':
        'SadCoder redacts captured JSON-RPC logs, but exported logs may still include paths, commands, project names, and prompt text.',
    'diagnosticLogsCopied': 'Copied {count} diagnostic log entries.',
    'diagnosticLogsExported': 'Exported {count} diagnostic log entries.',
    'diagnosticLogsExportFailed': 'Diagnostic log export failed',
    'applyTheme': 'Apply theme',
    'titleCommandTitle': 'Title display',
    'titleDisplayThread': 'Current thread title',
    'titleDisplayWorkingDirectory': 'Working directory',
    'applyTitleDisplay': 'Apply title display',
    'statusLineCommandTitle': 'Status line display',
    'applyStatusLineDisplay': 'Apply status line',
    'composerInputModeStandard': 'Input mode: Standard',
    'composerInputModeVim': 'Input mode: Vim',
    'composerSendShortcutEnter': 'Send: Enter',
    'composerSendShortcutCtrlEnter': 'Send: Ctrl+Enter',
    'keymapCommandTitle': 'Keyboard shortcuts',
    'keymapSendShortcutEnter': 'Enter sends',
    'keymapSendShortcutCtrlEnter': 'Ctrl+Enter sends',
    'applyKeymap': 'Apply shortcuts',
    'composerTerminalPetTuiOnly': 'Pet: TUI-only',
    'composerTerminalPetHidden': 'Pet: hidden',
    'terminalPetCommandTitle': 'Terminal pet',
    'terminalPetTuiOnly': 'TUI-only',
    'terminalPetHidden': 'Hidden on mobile',
    'applyTerminalPetDisplay': 'Apply pet display',
    'showUnavailableSlashCommands': 'Show unavailable commands',
    'showUnavailableSlashCommandsBody':
        'Include desktop-only and diagnostic slash commands in the command palette.',
    'diffTitle': 'Git diff',
    'diffUnavailable': 'Connect to a host to compute git diff.',
    'diffNotGitRepository':
        'The current workspace is not inside a Git repository.',
    'diffNoChanges': 'No tracked or untracked changes.',
    'diffLoadFailed': 'Failed to compute diff',
    'diffTruncated': 'Showing {shown} of {total} diff lines.',
    'diffShowFull': 'Show full diff',
    'mentionCommandTitle': 'Mention file',
    'ideContextCommandTitle': 'Mobile context',
    'mentionSearchHint': 'Search files',
    'ideContextSearchHint': 'Search files to attach',
    'mentionNoResults': 'No matching files.',
    'mentionLoadFailed': 'Failed to search files',
    'sideConversationTitle': 'Side conversation',
    'sideConversationCommand': 'Command',
    'sideConversationThread': 'Side thread',
    'sideConversationParent': 'Main thread',
    'sideConversationDropped':
        'Side conversation ended because the connection dropped.',
    'returnToMainThread': 'Return',
    'agentTopologyTitle': 'Agent threads',
    'subagentTopologyTitle': 'Subagents',
    'agentRole': 'Agent',
    'agentPath': 'Agent path',
    'agentParentThread': 'Parent thread',
    'agentAncestorThread': 'Ancestor thread',
    'activeThread': 'active',
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
    'refreshAccountStatus': 'Refresh account',
    'accountStatusUnavailable': 'Connect to a host, then refresh account.',
    'accountLoadFailed': 'Failed to load account',
    'accountNotSignedIn': 'not signed in',
    'accountSignedIn': 'Signed in',
    'accountCredentialSource': 'Credential source',
    'openaiAuthRequired': 'OpenAI auth required',
    'openaiAuthNotRequired': 'OpenAI auth not required',
    'refreshModelList': 'Refresh model list',
    'modelListUnavailable': 'Connect to a host, then refresh model list.',
    'modelListLoadFailed': 'Failed to load model list',
    'modelListEmpty': 'No models reported by the server.',
    'availableModels': 'Available models: {count}',
    'modelListMore': '{count} more models available.',
    'modelDefaultBadge': 'default',
    'modelDefaultValueSummary': 'default: {value}',
    'modelReasoningSummary': 'Reasoning: {summary}',
    'modelServiceTierSummary': 'Service tiers: {summary}',
    'modelAnnouncementSummary': 'Announcement: {message}',
    'accountUsageStatus': 'Usage',
    'accountUsageUnavailable': 'Connect to a host, then run /usage.',
    'accountUsageLoadFailed': 'Failed to load usage',
    'accountUsageTokenSummary': 'Token usage',
    'accountUsageRecentDaily': 'Recent daily usage',
    'accountUsageRateLimits': 'Rate limits',
    'accountUsageResetCredits': 'Reset credits',
    'threadTokenUsageStatus': 'Thread tokens',
    'threadTokenUsageLast': 'Last turn',
    'threadTokenUsageTotal': 'Thread total',
    'threadTokenUsageContextWindow': 'Context window',
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
    'mcpServersReloaded': 'Reloaded MCP server configuration.',
    'mcpServersOAuthLoginStarted': 'Started MCP OAuth login for {server}.',
    'mcpServersOAuthUrl': 'Open URL: {url}',
    'mcpServersOAuthUserCode': 'Code: {code}',
    'mcpServersUnavailable': 'Connect to a host, then run /mcp.',
    'mcpServersLoadFailed': 'Failed to load MCP servers',
    'mcpServersEmpty': 'No MCP servers configured.',
    'mcpServerAuthStatus': 'auth',
    'mcpServerTools': 'tools',
    'mcpServerResources': 'resources',
    'mcpServerResourceTemplates': 'templates',
    'mcpServerInfo': 'server',
    'mcpServerStartupStatus': 'startup',
    'mcpServerStartupError': 'error',
    'mcpServerStartupFailureReason': 'reason',
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
    'pluginMutationFailed': 'Failed to update plugin',
    'pluginsEmpty': 'No plugins available.',
    'pluginMarketplace': 'Marketplace',
    'pluginMarketplacePath': 'Marketplace path',
    'pluginMarketplaceErrors': 'Marketplace errors',
    'pluginDescription': 'Description',
    'pluginVersion': 'Version',
    'pluginLocalVersion': 'local {version}',
    'pluginSource': 'Source',
    'pluginCapabilities': 'Capabilities',
    'pluginReadme': 'README',
    'pluginInstalled': 'installed',
    'pluginNotInstalled': 'not installed',
    'pluginEnabled': 'enabled',
    'pluginDisabled': 'disabled',
    'pluginAvailability': 'availability',
    'pluginInstallRequested': 'Install requested for plugin {plugin}.',
    'pluginUninstallRequested': 'Uninstall requested for plugin {plugin}.',
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
    'debugConfigOriginUnknown': 'unknown origin',
    'debugConfigLayerConfig': 'config',
    'debugConfigLayerMetadata': 'metadata',
    'debugConfigLayerUnknown': 'unknown layer',
    'experimentalTitle': 'Experimental features',
    'experimentalUnavailable': 'Connect to a host, then run /experimental.',
    'experimentalLoadFailed': 'Failed to load experimental config',
    'experimentalNoSnapshot': 'No config snapshot loaded.',
    'experimentalApiCapability': 'App-server experimental API',
    'experimentalConfigValues': 'Experimental config values',
    'experimentalNoConfigValues': 'No experimental config values found.',
    'memoriesTitle': 'Memories',
    'memoriesUnavailable': 'Connect to a host, then run /memories.',
    'memoriesLoadFailed': 'Failed to load memory config',
    'memoriesNoSnapshot': 'No config snapshot loaded.',
    'memoriesConfigValues': 'Memory config values',
    'memoriesNoConfigValues': 'No memory config values found.',
    'memoriesThreadMode': 'Thread memory mode',
    'memoriesUnknownThreadMode': 'unknown',
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
    'totalTokens': 'total',
    'inputTokens': 'input',
    'cachedInputTokens': 'cached input',
    'outputTokens': 'output',
    'reasoningOutputTokens': 'reasoning',
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
    'themeBody': 'System, light, dark, and accent palettes are supported.',
    'workspaceFilesTitle': 'Workspace files',
    'workspaceFilesRoot': 'Root: {root}',
    'workspaceFilesRootLabel': 'Workspace root',
    'workspaceFilesUseRoot': 'Open root',
    'workspaceFilesUseDefaultRoot': 'Use default',
    'workspaceFilesSaveDefaultRoot': 'Save as default',
    'workspaceFilesSidebar': 'File tree',
    'workspaceFilesNotConnected': 'Connect to a host to browse files.',
    'workspaceFilesNoCwd': 'Select a thread or set a working directory.',
    'workspaceFilesRefresh': 'Refresh',
    'workspaceFilesSearchHint': 'Filter files',
    'workspaceFilesShowHidden': 'Show hidden files',
    'workspaceFilesEmptyDirectory': 'No files found',
    'workspaceFilesLoadMore': 'Load more',
    'workspaceFilesLoading': 'Loading files',
    'workspaceFilesOpenFailed': 'File preview failed',
    'workspaceFilesCopyPath': 'Copy path',
    'workspaceFilesPathCopied': 'Path copied.',
    'workspaceFilesPreviewEmpty': 'Select a text file to preview it.',
    'workspaceFilesRaw': 'Raw',
    'workspaceFilesRendered': 'Rendered',
    'workspaceFilesMarkdownRenderLimited':
        'Markdown rendering is available after the full file is loaded and remains under the render limit.',
    'workspaceFilesLargeFile':
        'This file is loaded in chunks. Load more to preview additional content.',
    'workspaceFilesBinary': 'Binary files cannot be previewed.',
    'workspaceFilesNotFound': 'Path was not found.',
    'workspaceFilesPermissionDenied': 'Permission denied while reading path.',
    'workspaceFilesPathOutsideRoot': 'Path is outside the workspace root.',
    'workspaceFilesReadFailed': 'Failed to read workspace file.',
    'workspaceFilesTooLarge': 'File is too large to preview.',
    'workspaceFilesFileSize': 'Size: {size}',
    'workspaceFilesModifiedAt': 'Modified: {timestamp}',
    'workspaceFilesFileType': 'Type: {type}',
    'workspaceFilesKindFile': 'file',
    'workspaceFilesKindDirectory': 'directory',
    'workspaceFilesKindUnknown': 'unknown',
    'workspaceFilesDirectoryLoadFailed': 'Failed to load directory.',
    'workspaceFilesRetry': 'Retry',
    'workspaceFilesLoadedBytes': '{loaded} / {total} loaded',
    'terminalTitle': 'Terminal',
    'terminalCwd': 'Working directory: {cwd}',
    'terminalCommand': 'Command',
    'terminalRun': 'Run',
    'terminalNotConnected': 'Connect to a host to run terminal commands.',
    'terminalNoCwd': 'Select a workspace before running terminal commands.',
    'terminalNoOutput': 'No output yet.',
    'terminalOutputCapped': 'Output was truncated by the server cap.',
    'terminalInput': 'Input',
    'terminalSendInput': 'Send input',
    'terminalCloseStdin': 'Close stdin',
    'terminalTerminate': 'Terminate',
    'terminalIdle': 'Idle',
    'terminalStarting': 'Starting',
    'terminalRunning': 'Running',
    'terminalExitCode': 'Exited with code {code}',
    'terminalFailed': 'Failed: {error}',
  },
  'zh': {
    'appTitle': 'SadCoder',
    'messageWithDetail': '{message}：{detail}',
    'hosts': '主机',
    'chat': '对话',
    'files': '文件',
    'sessions': '会话',
    'approvals': '审批',
    'settings': '设置',
    'settingsSectionPermissions': '权限',
    'settingsSectionAccount': '账户',
    'settingsSectionModels': '模型',
    'settingsSectionAppearance': '外观',
    'settingsSectionSsh': 'SSH',
    'settingsSectionDiagnostics': '诊断',
    'settingsSectionUnavailable': '此设置分组暂不可用。',
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
    'profileLoaded': '配置已加载。',
    'savedHosts': '已保存主机',
    'noSavedHosts': '暂无已保存 SSH 配置。',
    'useSshProfile': '使用配置',
    'deleteSshProfile': '删除配置',
    'deleteSshProfileTitle': '删除 SSH 配置？',
    'deleteSshProfileBody': '从已保存主机中删除 {name}。此配置保存的凭据也会一起删除。',
    'sshProfileDeleted': 'SSH 配置已删除。',
    'sshProfileDeleteFailed': 'SSH 配置删除失败',
    'savedHostProfileCount': '{count} 个配置',
    'importSshConfig': '导入 SSH config',
    'importingSshConfig': '正在导入 config',
    'sshConfigImported': '已导入 {count} 个 SSH 配置。',
    'sshConfigImportFailed': 'SSH config 导入失败',
    'sshConfigImportNoHosts': '未找到可导入的 SSH Host 条目。',
    'importPrivateKeyFile': '导入私钥',
    'importingPrivateKey': '正在导入私钥',
    'privateKeyImportedAndSaved': '私钥已导入，配置已安全保存。',
    'privateKeyImportNeedsProfile': '私钥已导入。补全主机和用户名后保存配置，即可安全持久化。',
    'privateKeyImportFailed': '私钥导入失败',
    'privateKeyImportNoPemBlock': '所选文件中未找到 PEM 私钥块。',
    'generateEd25519Key': '生成 ED25519',
    'generateRsaKey': '生成 RSA',
    'generatingSshKey': '正在生成密钥',
    'generatedPublicKey': '生成的公钥',
    'copyPublicKey': '复制公钥',
    'publicKeyCopied': '公钥已复制。',
    'exportPublicKey': '导出公钥',
    'exportingPublicKey': '正在导出公钥',
    'publicKeyExported': '公钥已导出。',
    'publicKeyExportFailed': '公钥导出失败',
    'sshKeyGeneratedAndSaved': 'SSH 密钥已生成，配置已安全保存。',
    'sshKeyGenerationNeedsProfile': 'SSH 密钥已生成。补全主机和用户名后保存配置，即可安全持久化。',
    'sshKeyGenerationFailed': 'SSH 密钥生成失败',
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
    'tcpConnect': 'TCP 连接',
    'sshHandshake': 'SSH 握手',
    'hostKey': '主机密钥',
    'sshAuth': 'SSH 认证',
    'remoteShell': '远端 shell',
    'codexVersion': 'Codex 版本',
    'agentVersion': 'Agent 版本',
    'agentStatus': 'Agent 状态',
    'agentStart': '启动 Agent',
    'proxyConnect': '代理连接',
    'agentHello': 'Agent 握手',
    'initialize': '初始化',
    'accountRead': '账户读取',
    'modelList': '模型列表',
    'configRead': '配置读取',
    'permissionProfileList': '权限配置列表',
    'threadList': '会话列表（limit 1）',
    'probeSuggestionCheckNetwork': '检查主机、端口、VPN、防火墙和网络连通性。',
    'probeSuggestionCheckSshServer': '检查 SSH 服务是否运行并支持当前协议。',
    'probeSuggestionVerifyHostKey': '信任此主机前请核对 SSH 主机密钥指纹。',
    'probeSuggestionCheckAuth': '检查用户名、密码或私钥凭据。',
    'probeSuggestionCheckRemoteShell': '确认远端登录 shell 可以执行非交互命令。',
    'probeSuggestionInstallCodex': '在远端主机安装 Codex，或将其加入 PATH。',
    'probeSuggestionUpdateCodex': '将 Codex 更新到受支持版本。',
    'probeSuggestionInstallAgent': '安装 sadcoder-agent，或修正 Agent 命令路径。',
    'probeSuggestionStartAgent': '启动 agent/backend，并检查服务日志。',
    'probeSuggestionCheckBackend': '检查 SadCoder agent service/backend 状态和日志。',
    'probeSuggestionLoginCodex': '在远端主机运行 codex login，或配置 API key。',
    'probeSuggestionCheckCwdOrPermissions': '检查配置的 cwd 和远端文件权限。',
    'probeSuggestionRetryProxy': '检查 sadcoder-agent proxy 和 backend 日志后重试。',
    'backend': '后端',
    'backendAgentService': 'agent service',
    'backendDaemon': '旧 daemon',
    'backendStdioFallback': 'stdio fallback',
    'backendUnknown': '未知',
    'backendReady': '就绪',
    'backendNotStarted': '未启动',
    'backendUnavailable': '不可用',
    'reconnectCacheSummary':
        '重连缓存：{pendingApprovals} 个待审批，{recentEvents} 个最近事件，{threads} 个线程',
    'reconnectCacheDeliveredCursor': '已投递 cursor：{cursor}',
    'statePath': '状态路径：{path}',
    'reconnectCacheLoadError': '重连缓存读取失败：{error}',
    'connect': '连接',
    'connecting': '连接中',
    'connected': '已连接',
    'reconnecting': '重连中',
    'restartBackend': '重启后端',
    'restartingBackend': '正在重启后端',
    'statusIdle': '空闲',
    'statusRunning': '运行中',
    'statusWorking': '工作中',
    'statusFailed': '失败',
    'disconnect': '断开',
    'disconnecting': '断开中',
    'connectionStatus': '连接状态',
    'connectionFailed': '连接失败',
    'activeConnection': '当前连接',
    'noActiveConnection': '暂无活动连接',
    'disconnected': '未连接',
    'hostKeyConfirmTitle': '信任此 SSH 主机密钥？',
    'hostKeyConfirmBody':
        '这是 SadCoder 首次看到 {endpoint}。\n\n密钥类型：{keyType}\n指纹：{fingerprint}\n\n只有在该指纹与预期服务器一致时才继续。',
    'hostKeyTrust': '信任并继续',
    'm0ProtocolClient': 'M0 协议客户端',
    'm0ProtocolClientBody':
        '应用已经具备 initialize、model/list 和 thread/list 的 JSON-RPC 客户端，SSH 传输复用同一接口。',
    'slashCommandSurface': '斜杠命令入口',
    'slashCommandSurfaceBody': '输入 / 后会打开 SadCoder 命令面板，而不是把斜杠文本当作普通提示词发送。',
    'showChatAdvancedControls': '高级控制',
    'hideChatAdvancedControls': '收起高级控制',
    'rawRpcTitle': '原始 RPC',
    'rawRpcDescription': '开发者专用 app-server JSON-RPC 请求。仅在功能尚未结构化时使用。',
    'rawRpcDisconnected': '连接主机后才能发送原始 RPC。',
    'rawRpcMethod': '方法',
    'rawRpcParams': '参数 JSON 对象',
    'rawRpcConfirm': '我了解此原始请求可能会修改服务器状态。',
    'rawRpcSend': '发送原始 RPC',
    'rawRpcResult': '结果',
    'rawRpcError': '错误',
    'rawRpcInvalidJsonObject': '参数必须是 JSON 对象',
    'rawRpcMethodRequired': '必须填写方法。',
    'connectBeforeTurn': '连接主机后才能发送任务',
    'connectBeforeLoadingThreads': '连接主机后加载会话。',
    'refreshThreads': '刷新会话',
    'activeThreads': '活动',
    'archivedThreads': '归档',
    'noThreads': '暂无会话',
    'noArchivedThreads': '暂无归档会话',
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
    'shellCommandFailed': 'Shell 命令执行失败',
    'timeline': '事件流',
    'noTimelineEvents': '暂无事件',
    'timelineUser': '你',
    'timelineCodex': 'Codex',
    'timelineReasoning': '推理',
    'timelinePlan': '计划',
    'timelineCommand': '命令',
    'timelineToolCall': '工具调用',
    'timelineItem': '条目',
    'timelineStatus': '状态',
    'timelineExitCode': '退出码',
    'timelineDuration': '耗时',
    'timelineDurationMilliseconds': '{milliseconds} 毫秒',
    'timelineFileChanges': '文件变更',
    'timelineTool': '工具',
    'forkedThread': '分叉',
    'subagentThread': '子 agent',
    'send': '发送',
    'slashCommands': '斜杠命令',
    'typeCommandName': '输入命令名称',
    'slashCommandUnknown': '未知命令：{slash}',
    'slashCommandAliases': '别名：{aliases}',
    'slashCommandMapping.appServer': 'app-server',
    'slashCommandMapping.uiOnly': '界面',
    'slashCommandMapping.agentFallback': 'agent 兜底',
    'slashCommandMapping.topology': '拓扑',
    'slashCommandMapping.notApplicable': '不适用',
    'slashCommandMapping.debug': '调试',
    'slashCommandPhase.mvp': 'MVP',
    'slashCommandPhase.secondStage': '第二阶段',
    'slashCommandPhase.secondStageExperimental': '实验',
    'slashCommandPhase.thirdStage': '第三阶段',
    'slashCommandPhase.advancedDebug': '调试',
    'slashCommandRiskLevel.low': '低',
    'slashCommandRiskLevel.medium': '中',
    'slashCommandRiskLevel.high': '高',
    'slashCommandGroup.common': '常用',
    'slashCommandGroup.session': '会话',
    'slashCommandGroup.configuration': '配置',
    'slashCommandGroup.filesAndCommands': '文件/命令',
    'slashCommandGroup.mcpAndExtensions': 'MCP/插件',
    'slashCommandGroup.debug': '调试',
    'slashCommandArgs': '参数：{hint}',
    'slashCommandNotSentAsPrompt': '不会作为普通提示词发送',
    'slashCommandSendAsText': '作为文本发送',
    'slashCommandWillSendAsPrompt': '将作为普通提示词发送',
    'slashCommandUnavailableDuringTask': '当前回合运行中不可用',
    'slashCommandUnavailableInSideConversation': '侧聊中不可用',
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
    'slashCommandDuplicatedThread': '已复制会话。',
    'slashCommandRewoundThread': '已回退会话。',
    'slashCommandCompactionStarted': '已开始压缩会话。',
    'slashCommandArchivedThread': '已归档会话。',
    'slashCommandDeletedThread': '已删除会话。',
    'slashCommandLoggedOut': '已退出服务器 Codex 账户。',
    'slashCommandFeedbackSubmitted': '已提交反馈。',
    'slashCommandAutoReviewApproved': '已审批最近一条自动复审拒绝。',
    'slashCommandThemeUpdated': '已更新主题。',
    'slashCommandTitleDisplayUpdated': '已更新标题显示。',
    'slashCommandStatusLineDisplayUpdated': '已更新状态栏显示。',
    'slashCommandIdeContextInserted': '已附加移动端上下文。',
    'slashCommandKeymapUpdated': '已更新键盘快捷键设置。',
    'slashCommandVimModeEnabled': '已启用编辑器 Vim 模式。',
    'slashCommandVimModeDisabled': '已关闭编辑器 Vim 模式。',
    'slashCommandPetsTuiOnly': '终端宠物在移动端保持为 TUI 专属。',
    'slashCommandPetsHidden': '已在移动端隐藏终端宠物。',
    'slashCommandMentionInserted': '已插入文件提及。',
    'slashCommandSideConversationStarted': '已开始侧聊。',
    'slashCommandReturnedToMainThread': '已返回主线会话。',
    'slashCommandAgentThreadSelected': '已切换 agent 会话。',
    'slashCommandAppHandoffUnavailable': '移动端暂不支持交接到 Codex Desktop。',
    'slashCommandImportUnavailable':
        '移动端尚未接入 Claude Code 导入流程。该能力需要在选中主机上通过受保护的 agent fallback 执行。',
    'slashCommandInitUnavailable':
        '移动端尚未接入 AGENTS.md 初始化流程。写入文件前必须先生成 diff 预览并完成审批。',
    'slashCommandSandboxSetupUnavailable':
        '移动端尚未接入默认沙箱设置流程。该能力需要在选中主机上通过受保护的 agent fallback 执行，并完成高风险确认。',
    'slashCommandSandboxReadDirUnavailable':
        '移动端尚未接入沙箱读取目录配置。该能力需要通过受保护的 Windows agent fallback 执行，并完成高风险确认。',
    'slashCommandRolloutCurrentPath': '当前 rollout 路径：{path}',
    'slashCommandRolloutPathUnavailable': '暂时无法获取 rollout 路径。',
    'slashCommandTestApprovalReason': 'SadCoder 测试审批请求',
    'slashCommandTestApprovalQueued': '已加入测试审批请求。',
    'slashCommandModelUpdated': '已更新模型覆盖。',
    'slashCommandPersonalityUpdated': '已更新协作风格覆盖。',
    'slashCommandPermissionsUpdated': '已更新权限覆盖。',
    'slashCommandPlanModeUpdated': '已应用计划模式。',
    'slashCommandCancelled': '已取消 {slash}。',
    'slashCommandExecuted': '已执行 {slash}。',
    'slashCommandUnsupported': '{slash} 暂未实现。',
    'slashCommandUnsupportedWithStatus': '{slash} 已注册但当前不可用：{status}。',
    'slashCommandUnsupportedTarget': '计划路径：{target}。',
    'slashCommandUnsupportedRisk': '风险：{risk}。',
    'slashCommandUnsupportedAppServer': '移动端 app-server 处理器尚未接入',
    'slashCommandUnsupportedUiOnly': '移动端 UI 流程尚未接入',
    'slashCommandUnsupportedAgentFallback': '受保护的 agent fallback 尚未接入',
    'slashCommandUnsupportedTopology': '会话拓扑动作尚未接入',
    'slashCommandUnsupportedNotApplicable': '不适用于移动端',
    'slashCommandUnsupportedDebug': '高级调试命令尚未在移动端接入',
    'slashCommandUnsupportedDesktopOnly': '仅桌面端命令',
    'slashCommandUnsupportedWindowsOnly': '仅 Windows 命令',
    'slashCommandUnsupportedTuiOnly': '仅 TUI 命令',
    'slashCommandUnsupportedDebugOnly': '仅调试命令',
    'slashCommandUnavailable': '{slash} 当前不可用。',
    'slashCommandFailed': '{slash} 执行失败：{error}',
    'noPendingApprovals': '暂无待审批请求',
    'approvalsBody': '命令、文件、Codex 提问和 MCP 请求会在这里显示对应的会话与回合 ID。',
    'approvalKindCommand': '命令审批',
    'approvalKindFileChange': '文件变更审批',
    'approvalKindPermissions': '权限审批',
    'approvalKindUserInput': 'Codex 提问',
    'approvalKindMcp': 'MCP 表单请求',
    'approvalKindUnknown': '未知请求',
    'approvalRequestId': '请求',
    'approvalThread': '会话',
    'approvalTurn': '回合',
    'approvalMethod': '方法',
    'approvalParameterKeys': '参数键',
    'approvalCommand': '命令',
    'approvalWorkingDirectory': '工作目录',
    'approvalPermissionScope': '权限范围',
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
    'approvalSecondConfirmTitle': '确认批准',
    'approvalSecondConfirmBody': '此请求看起来风险较高。批准前请再次检查命令或文件变更。',
    'approvalSecondConfirmProceed': '仍然批准',
    'toolUserInputOther': '其他',
    'toolUserInputOtherDescription': '输入不同的答案。',
    'toolUserInputAnswer': '回答',
    'toolUserInputSelectionRequired': '请选择一个选项。',
    'toolUserInputAnswerRequired': '请输入回答。',
    'toolUserInputSubmit': '提交回答',
    'toolUserInputSubmitting': '正在提交...',
    'toolUserInputShowSecret': '显示私密内容',
    'toolUserInputHideSecret': '隐藏私密内容',
    'toolUserInputAutoResolution': 'Codex 可能会在 {seconds} 秒后自动继续。',
    'serverDefaults': '服务器默认配置',
    'serverDefaultsBody': '默认沿用服务器上的 Codex 配置，只有显式设置时才覆盖。',
    'appDefaultOverrides': 'App 默认覆盖',
    'modelOverride': '模型',
    'modelProvider': '模型提供方',
    'effortOverride': '推理强度',
    'personalityOverride': '协作风格',
    'serviceTierOverride': '服务档位',
    'collaborationModeOverride': '协作模式',
    'approvalPolicy': '审批策略',
    'permissionProfile': '权限配置',
    'sandboxMode': '沙盒模式',
    'cwdOverride': '工作目录',
    'applyOverrides': '应用覆盖',
    'clearOverrides': '清除覆盖',
    'restoreServerDefaults': '恢复服务器默认',
    'overrideSource': '来源',
    'sourceServerDefault': '服务器默认',
    'sourceAppDefault': 'App 默认',
    'sourceSessionOverride': '会话覆盖',
    'sourceTurnOverride': '本次覆盖',
    'sessionOverrides': '会话覆盖',
    'editSessionOverrides': '编辑会话覆盖',
    'applySessionOverrides': '应用到会话',
    'clearSessionOverrides': '清除会话覆盖',
    'threadSettingsUpdateFailed': '更新会话设置失败',
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
    'unarchiveThread': '恢复会话',
    'threadUnarchived': '已恢复会话。',
    'deleteThreadTitle': '删除会话？',
    'deleteThreadBody': '这会永久删除当前会话和派生的子会话，无法撤销。',
    'deleteThreadConfirm': '删除',
    'logoutAccountTitle': '退出 Codex 账户？',
    'logoutAccountBody': '这会让使用同一 CODEX_HOME 的服务器 Codex 账户退出登录，服务器任务不会被中断。',
    'logoutAccountConfirm': '退出登录',
    'feedbackCommandTitle': '发送反馈',
    'feedbackCategoryLabel': '类别',
    'feedbackCategoryBug': 'Bug',
    'feedbackCategoryBadResult': '结果不理想',
    'feedbackCategoryGoodResult': '结果很好',
    'feedbackCategorySafetyCheck': '安全检查',
    'feedbackCategoryOther': '其他',
    'feedbackNoteLabel': '说明',
    'feedbackNoteHint': '可选补充信息',
    'feedbackIncludeLogs': '包含服务器日志',
    'feedbackLogsDisclosure': '日志可能包含提示词、路径、命令和此服务器上的诊断信息。',
    'feedbackLogsConfirmTitle': '随反馈发送日志？',
    'feedbackLogsConfirmBody':
        'SadCoder 会脱敏它采集的诊断日志，但服务器日志仍可能包含路径、命令、项目名和提示词。发送前请检查说明。',
    'feedbackLogsConfirmSubmit': '随日志发送',
    'feedbackSubmit': '发送反馈',
    'themeCommandTitle': '主题',
    'themeSystem': '跟随系统',
    'themeLight': '浅色',
    'themeDark': '深色',
    'colorPalette': '配色方案',
    'colorPaletteBody': '选择 App 强调色方案；代码、diff 和终端颜色仍保持语义配色。',
    'colorPalette.sadcoder': 'SadCoder',
    'colorPalette.candy': '糖果',
    'colorPalette.pastel-candy': '粉彩糖果',
    'colorPalette.candy-tones': '糖果色调',
    'colorPalette.candy-pop': '糖果汽水',
    'colorPalette.sugar-rush': '糖果冲击',
    'colorPalette.lagoon': '泻湖',
    'colorPalette.ember': '余烬',
    'fontSize': '字号',
    'fontSizeBody': '按阅读密度或舒适度缩放 App 文本。',
    'fontSize.extra-small': '极小',
    'fontSize.small': '小',
    'fontSize.medium': '中',
    'fontSize.large': '大',
    'fontSize.extra-large': '极大',
    'advancedAppearance': '高级外观',
    'backgroundConnectionKeepActiveTurn': '后台保持 active turn 连接',
    'backgroundConnectionKeepActiveTurnBody':
        '开启后，App 进入后台时会尽量继续观察 active turn。关闭后会断开观察连接，下次连接时回填状态。',
    'diagnosticLogs': '诊断日志',
    'diagnosticLogsBody': '当前连接中已脱敏的 JSON-RPC 消息。',
    'agentDoctor': 'Agent 诊断',
    'agentDoctorBody': '从 sadcoder-agent 非破坏性读取 Codex、backend 和重连缓存诊断。',
    'refreshAgentDoctor': '运行 agent 诊断',
    'agentDoctorUnavailable': '连接主机后运行 agent 诊断。',
    'agentDoctorLoadFailed': '运行 agent 诊断失败',
    'agentServiceLogs': 'Agent 服务日志',
    'agentServiceLogsBody':
        '从 sadcoder-agent service 和 app-server 读取有界 stderr 尾部。',
    'refreshAgentServiceLogs': '刷新 agent 日志',
    'agentServiceLogsUnavailable': '连接主机后刷新日志。',
    'agentServiceLogsLoadFailed': '读取 agent 服务日志失败',
    'agentServiceLogsEmpty': '未返回 agent 服务日志。',
    'agentServiceLogsMaxTail': '最大返回尾部：{size}',
    'agentSchema': 'App-server schema',
    'agentSchemaBody':
        '由 sadcoder-agent 生成并缓存的 JSON Schema，用于 app-server 兼容性诊断。',
    'refreshAgentSchema': '刷新 schema 缓存',
    'regenerateAgentSchema': '重新生成 schema 缓存',
    'agentSchemaStable': '稳定版',
    'agentSchemaExperimental': '实验版',
    'agentSchemaUnavailable': '连接主机后刷新 schema 诊断。',
    'agentSchemaLoadFailed': '读取 app-server schema 诊断失败',
    'agentSchemaGenerated': '本次请求已生成 schema 缓存。',
    'agentSchemaCached': '已读取现有 schema 缓存。',
    'agentSchemaMode': 'Schema 模式',
    'agentSchemaSource': 'Schema 来源',
    'agentSchemaFiles': 'Schema 文件',
    'agentSchemaFilesSummary': '{count} 个文件，{size}',
    'agentSchemaGeneratedAt': '生成时间',
    'agentSchemaDigest': 'Schema 摘要',
    'agentSchemaBundle': 'Schema bundle',
    'agentSchemaCache': 'Schema 缓存',
    'agentSchemaMetadata': 'Schema 元数据',
    'agentSchemaEmpty': '未返回 schema 文件。',
    'agentSchemaMoreFiles': '还有 {count} 个 schema 文件。',
    'agentLogPath': '日志路径',
    'agentLogSize': '日志大小：{size}；已返回尾部：{tail}',
    'agentLogTruncated': '当前只显示这份日志的最新部分。',
    'agentLogMissing': '日志文件尚未创建。',
    'agentLogEmpty': '日志文件为空。',
    'agentLogError': '日志读取错误：{error}',
    'agentCodexConfigure': 'Codex 配置',
    'agentCodexConfigureBody': '持久化 sadcoder-agent 使用的 Codex 程序和 PATH 前置项。',
    'codexArguments': 'Codex 参数',
    'codexPathPrepend': 'PATH 前置',
    'fillFromAgentDoctor': '填入诊断结果',
    'saveAgentCodexConfig': '保存配置',
    'savingAgentCodexConfig': '正在保存配置',
    'agentCodexConfigureFailed': '保存 Codex 配置失败',
    'codexProgramRequired': '请填写 Codex 程序。',
    'agentConfigPath': 'Agent 配置',
    'codexProgram': 'Codex 程序',
    'codexSource': 'Codex 来源',
    'codexCommandFailure': 'Codex 命令失败',
    'codexStatusFailure': 'Codex 状态失败',
    'backendDetail': 'Backend 详情',
    'copyDiagnosticLogs': '复制日志',
    'copyingDiagnosticLogs': '正在复制日志',
    'exportDiagnosticLogs': '导出日志',
    'exportingDiagnosticLogs': '正在导出日志',
    'diagnosticLogsEmpty': '暂无已捕获的诊断日志。',
    'diagnosticLogsConfirmTitle': '复制诊断日志？',
    'diagnosticLogsExportConfirmTitle': '导出诊断日志？',
    'diagnosticLogsConfirmBody':
        'SadCoder 会脱敏已捕获的 JSON-RPC 日志，但导出的日志仍可能包含路径、命令、项目名和提示词文本。',
    'diagnosticLogsCopied': '已复制 {count} 条诊断日志。',
    'diagnosticLogsExported': '已导出 {count} 条诊断日志。',
    'diagnosticLogsExportFailed': '诊断日志导出失败',
    'applyTheme': '应用主题',
    'titleCommandTitle': '标题显示',
    'titleDisplayThread': '当前会话标题',
    'titleDisplayWorkingDirectory': '工作目录',
    'applyTitleDisplay': '应用标题显示',
    'statusLineCommandTitle': '状态栏显示',
    'applyStatusLineDisplay': '应用状态栏',
    'composerInputModeStandard': '输入模式：标准',
    'composerInputModeVim': '输入模式：Vim',
    'composerSendShortcutEnter': '发送：Enter',
    'composerSendShortcutCtrlEnter': '发送：Ctrl+Enter',
    'keymapCommandTitle': '键盘快捷键',
    'keymapSendShortcutEnter': 'Enter 发送',
    'keymapSendShortcutCtrlEnter': 'Ctrl+Enter 发送',
    'applyKeymap': '应用快捷键',
    'composerTerminalPetTuiOnly': '终端宠物：仅 TUI',
    'composerTerminalPetHidden': '终端宠物：已隐藏',
    'terminalPetCommandTitle': '终端宠物',
    'terminalPetTuiOnly': '仅 TUI',
    'terminalPetHidden': '在移动端隐藏',
    'applyTerminalPetDisplay': '应用终端宠物显示',
    'showUnavailableSlashCommands': '显示不可用命令',
    'showUnavailableSlashCommandsBody': '在命令面板中显示桌面端专属和诊断用斜杠命令。',
    'diffTitle': 'Git 差异',
    'diffUnavailable': '连接到主机后才能计算 Git 差异。',
    'diffNotGitRepository': '当前工作区不在 Git 仓库中。',
    'diffNoChanges': '没有已跟踪或未跟踪的变更。',
    'diffLoadFailed': '计算差异失败',
    'diffTruncated': '正在显示 {shown} / {total} 行差异。',
    'diffShowFull': '显示完整差异',
    'mentionCommandTitle': '提及文件',
    'ideContextCommandTitle': '移动端上下文',
    'mentionSearchHint': '搜索文件',
    'ideContextSearchHint': '搜索要附加的文件',
    'mentionNoResults': '没有匹配的文件。',
    'mentionLoadFailed': '搜索文件失败',
    'sideConversationTitle': '侧聊',
    'sideConversationCommand': '命令',
    'sideConversationThread': '侧聊会话',
    'sideConversationParent': '主线会话',
    'sideConversationDropped': '连接已断开，侧聊已结束。',
    'returnToMainThread': '返回',
    'agentTopologyTitle': 'Agent 会话',
    'subagentTopologyTitle': '子 agent',
    'agentRole': 'Agent',
    'agentPath': 'Agent 路径',
    'agentParentThread': '父会话',
    'agentAncestorThread': '祖先会话',
    'activeThread': '当前',
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
    'refreshAccountStatus': '刷新账户',
    'accountStatusUnavailable': '连接主机后刷新账户状态。',
    'accountLoadFailed': '账户加载失败',
    'accountNotSignedIn': '未登录',
    'accountSignedIn': '已登录',
    'accountCredentialSource': '凭据来源',
    'openaiAuthRequired': '需要 OpenAI 认证',
    'openaiAuthNotRequired': '不需要 OpenAI 认证',
    'refreshModelList': '刷新模型列表',
    'modelListUnavailable': '连接主机后刷新模型列表。',
    'modelListLoadFailed': '模型列表加载失败',
    'modelListEmpty': '服务器没有返回可用模型。',
    'availableModels': '可用模型：{count}',
    'modelListMore': '还有 {count} 个模型可用。',
    'modelDefaultBadge': '默认',
    'modelDefaultValueSummary': '默认：{value}',
    'modelReasoningSummary': '推理：{summary}',
    'modelServiceTierSummary': '服务档位：{summary}',
    'modelAnnouncementSummary': '公告：{message}',
    'accountUsageStatus': '使用量',
    'accountUsageUnavailable': '连接主机后运行 /usage。',
    'accountUsageLoadFailed': '使用量加载失败',
    'accountUsageTokenSummary': 'Token 使用量',
    'accountUsageRecentDaily': '最近每日使用量',
    'accountUsageRateLimits': '速率限制',
    'accountUsageResetCredits': '重置额度',
    'threadTokenUsageStatus': '会话 token',
    'threadTokenUsageLast': '上一回合',
    'threadTokenUsageTotal': '会话累计',
    'threadTokenUsageContextWindow': '上下文窗口',
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
    'mcpServersReloaded': '已重新加载 MCP 服务器配置。',
    'mcpServersOAuthLoginStarted': '已为 {server} 启动 MCP OAuth 登录。',
    'mcpServersOAuthUrl': '打开 URL：{url}',
    'mcpServersOAuthUserCode': '验证码：{code}',
    'mcpServersUnavailable': '连接主机后运行 /mcp。',
    'mcpServersLoadFailed': 'MCP 服务器加载失败',
    'mcpServersEmpty': '未配置 MCP 服务器。',
    'mcpServerAuthStatus': '认证',
    'mcpServerTools': '工具',
    'mcpServerResources': '资源',
    'mcpServerResourceTemplates': '模板',
    'mcpServerInfo': '服务器',
    'mcpServerStartupStatus': '启动',
    'mcpServerStartupError': '错误',
    'mcpServerStartupFailureReason': '原因',
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
    'pluginMutationFailed': '插件更新失败',
    'pluginsEmpty': '暂无可用插件。',
    'pluginMarketplace': '市场',
    'pluginMarketplacePath': '市场路径',
    'pluginMarketplaceErrors': '市场错误',
    'pluginDescription': '说明',
    'pluginVersion': '版本',
    'pluginLocalVersion': '本地 {version}',
    'pluginSource': '来源',
    'pluginCapabilities': '能力',
    'pluginReadme': 'README',
    'pluginInstalled': '已安装',
    'pluginNotInstalled': '未安装',
    'pluginEnabled': '已启用',
    'pluginDisabled': '已禁用',
    'pluginAvailability': '可用性',
    'pluginInstallRequested': '已请求安装插件 {plugin}。',
    'pluginUninstallRequested': '已请求卸载插件 {plugin}。',
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
    'debugConfigOriginUnknown': '未知来源',
    'debugConfigLayerConfig': '配置',
    'debugConfigLayerMetadata': '元数据',
    'debugConfigLayerUnknown': '未知层',
    'experimentalTitle': '实验功能',
    'experimentalUnavailable': '连接主机后运行 /experimental。',
    'experimentalLoadFailed': '实验功能配置加载失败',
    'experimentalNoSnapshot': '尚未加载配置快照。',
    'experimentalApiCapability': 'App-server 实验 API',
    'experimentalConfigValues': '实验配置值',
    'experimentalNoConfigValues': '未找到实验配置值。',
    'memoriesTitle': '记忆',
    'memoriesUnavailable': '连接主机后运行 /memories。',
    'memoriesLoadFailed': '记忆配置加载失败',
    'memoriesNoSnapshot': '尚未加载配置快照。',
    'memoriesConfigValues': '记忆配置值',
    'memoriesNoConfigValues': '未找到记忆配置值。',
    'memoriesThreadMode': '线程记忆模式',
    'memoriesUnknownThreadMode': '未知',
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
    'totalTokens': '总计',
    'inputTokens': '输入',
    'cachedInputTokens': '缓存输入',
    'outputTokens': '输出',
    'reasoningOutputTokens': '推理输出',
    'tokenCount': '{count} 个 token',
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
    'themeBody': '支持跟随系统、浅色、深色和强调配色方案。',
    'workspaceFilesTitle': '工作区文件',
    'workspaceFilesRoot': '根目录：{root}',
    'workspaceFilesRootLabel': '工作区根目录',
    'workspaceFilesUseRoot': '打开根目录',
    'workspaceFilesUseDefaultRoot': '使用默认',
    'workspaceFilesSaveDefaultRoot': '保存为默认',
    'workspaceFilesSidebar': '文件树',
    'workspaceFilesNotConnected': '连接主机后浏览文件。',
    'workspaceFilesNoCwd': '请选择会话或设置工作目录。',
    'workspaceFilesRefresh': '刷新',
    'workspaceFilesSearchHint': '过滤文件',
    'workspaceFilesShowHidden': '显示隐藏文件',
    'workspaceFilesEmptyDirectory': '未找到文件',
    'workspaceFilesLoadMore': '加载更多',
    'workspaceFilesLoading': '正在加载文件',
    'workspaceFilesOpenFailed': '文件预览失败',
    'workspaceFilesCopyPath': '复制路径',
    'workspaceFilesPathCopied': '已复制路径。',
    'workspaceFilesPreviewEmpty': '选择文本文件进行预览。',
    'workspaceFilesRaw': '源码',
    'workspaceFilesRendered': '渲染',
    'workspaceFilesMarkdownRenderLimited': 'Markdown 仅在完整加载且低于渲染阈值时可用。',
    'workspaceFilesLargeFile': '此文件按分段加载；可继续加载后续内容。',
    'workspaceFilesBinary': '二进制文件不可预览。',
    'workspaceFilesNotFound': '路径不存在。',
    'workspaceFilesPermissionDenied': '读取路径时权限不足。',
    'workspaceFilesPathOutsideRoot': '路径位于工作区根目录之外。',
    'workspaceFilesReadFailed': '读取工作区文件失败。',
    'workspaceFilesTooLarge': '文件过大，无法预览。',
    'workspaceFilesFileSize': '大小：{size}',
    'workspaceFilesModifiedAt': '修改时间：{timestamp}',
    'workspaceFilesFileType': '类型：{type}',
    'workspaceFilesKindFile': '文件',
    'workspaceFilesKindDirectory': '目录',
    'workspaceFilesKindUnknown': '未知',
    'workspaceFilesDirectoryLoadFailed': '目录加载失败。',
    'workspaceFilesRetry': '重试',
    'workspaceFilesLoadedBytes': '已加载 {loaded} / {total}',
    'terminalTitle': '终端',
    'terminalCwd': '工作目录：{cwd}',
    'terminalCommand': '命令',
    'terminalRun': '运行',
    'terminalNotConnected': '连接主机后才能运行终端命令。',
    'terminalNoCwd': '选择工作区后才能运行终端命令。',
    'terminalNoOutput': '暂无输出。',
    'terminalOutputCapped': '输出已被服务器截断。',
    'terminalInput': '输入',
    'terminalSendInput': '发送输入',
    'terminalCloseStdin': '关闭标准输入',
    'terminalTerminate': '终止',
    'terminalIdle': '空闲',
    'terminalStarting': '正在启动',
    'terminalRunning': '运行中',
    'terminalExitCode': '退出码 {code}',
    'terminalFailed': '失败：{error}',
  },
};

const _slashCommandDescriptions = <String, Map<String, String>>{
  'zh': {
    'model': '选择模型和推理强度',
    'ide': '附加当前选择、打开文件等移动端上下文',
    'permissions': '选择 Codex 被允许执行的操作',
    'keymap': '调整移动端快捷键',
    'vim': '切换输入框 Vim 模式',
    'setup-default-sandbox': '设置提升权限的 agent 沙箱',
    'sandbox-add-read-dir': '允许沙箱读取目录：/sandbox-add-read-dir <absolute_path>',
    'experimental': '切换实验功能',
    'approve': '批准最近一次自动审查拒绝后的重试',
    'memories': '配置记忆使用和生成',
    'skills': '使用技能改进 Codex 执行特定任务',
    'import': '从 Claude Code 导入设置、项目和最近聊天',
    'hooks': '查看和管理生命周期 hooks',
    'review': '审查当前改动并找出问题',
    'rename': '重命名当前会话',
    'new': '在对话中开始新聊天',
    'archive': '归档此会话并退出',
    'delete': '永久删除此会话并退出',
    'resume': '恢复已保存的聊天',
    'fork': '派生当前聊天',
    'duplicate': '复制当前聊天',
    'rewind': '从某个回合检查点派生当前聊天',
    'app': '在 Codex Desktop 中继续此会话',
    'init': '创建包含 Codex 指令的 AGENTS.md 文件',
    'compact': '汇总对话以避免触及上下文上限',
    'plan': '切换到 Plan 模式',
    'goal': '设置或查看长任务目标',
    'agent': '切换活动 agent thread',
    'side': '在 ephemeral fork 中开始侧聊',
    'btw': '在 ephemeral fork 中开始侧聊',
    'copy': '以 Markdown 复制最后一条回复',
    'raw': '切换原始滚动记录模式，便于复制',
    'diff': '显示 git diff（包含未跟踪文件）',
    'mention': '提及文件',
    'status': '显示当前会话配置和 token 使用情况',
    'usage': '查看账号用量或使用重置额度',
    'debug-config': '显示配置层和需求来源用于调试',
    'title': '配置终端标题显示项',
    'statusline': '配置状态栏显示项',
    'theme': '选择语法高亮主题',
    'pets': '选择或隐藏终端 pet',
    'mcp': '列出 MCP 工具；可用 /mcp verbose、reload 或 login <server>',
    'apps': '管理 apps',
    'plugins': '浏览插件；可用 install/uninstall <id> 或按 marketplace 过滤',
    'logout': '退出服务器 Codex 账户',
    'quit': '关闭当前 App 会话/代理连接',
    'exit': '关闭当前 App 会话/代理连接',
    'feedback': '发送日志给维护者',
    'rollout': '打印 rollout 文件路径',
    'ps': '列出后台终端',
    'stop': '停止所有后台终端',
    'clear': '清空终端并开始新聊天',
    'personality': '选择 Codex 沟通风格',
    'test-approval': '测试审批请求',
    'subagents': '切换活动 agent thread',
    'debug-m-drop': '不要使用',
    'debug-m-update': '不要使用',
  },
};

const _slashCommandArgumentHints = <String, Map<String, String>>{
  'en': {
    'ide': '<query>',
    'keymap': '<enter|ctrl-enter>',
    'sandbox-add-read-dir': '<absolute_path>',
    'review': '[detached] [commit]',
    'rename': '<name>',
    'resume': '<thread_id>',
    'rewind': '<turn_id>',
    'plan': '[prompt]',
    'goal': '<show|set|status|budget|clear>',
    'side': '[prompt]',
    'btw': '[prompt]',
    'raw': '<on|off>',
    'usage': '[refresh]',
    'pets': '<show|hide>',
    'mcp': '<verbose|reload|login server>',
    'plugins': '<install|uninstall> <id> | [marketplace] <kind>',
  },
  'zh': {
    'ide': '<查询>',
    'keymap': '<enter|ctrl-enter>',
    'sandbox-add-read-dir': '<绝对路径>',
    'review': '[detached] [commit]',
    'rename': '<名称>',
    'resume': '<会话 ID>',
    'rewind': '<回合 ID>',
    'plan': '[提示词]',
    'goal': '<show|set|status|budget|clear>',
    'side': '[提示词]',
    'btw': '[提示词]',
    'raw': '<on|off>',
    'usage': '[refresh]',
    'pets': '<show|hide>',
    'mcp': '<verbose|reload|login server>',
    'plugins': '<install|uninstall> <id> | [marketplace] <kind>',
  },
};

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
