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
  String get agentCommand => _text('agentCommand');
  String get saveProfile => _text('saveProfile');
  String get savingProfile => _text('savingProfile');
  String get profileSaved => _text('profileSaved');
  String get test => _text('test');
  String get testing => _text('testing');
  String get hostRequired => _text('hostRequired');
  String get usernameRequired => _text('usernameRequired');
  String get passwordRequired => _text('passwordRequired');
  String get agentCommandRequired => _text('agentCommandRequired');
  String get invalidPort => _text('invalidPort');
  String get notTested => _text('notTested');
  String get testingConnection => _text('testingConnection');
  String get probePassed => _text('probePassed');
  String get probeFailed => _text('probeFailed');
  String get agentStatus => _text('agentStatus');
  String get proxyConnect => _text('proxyConnect');
  String get initialize => _text('initialize');
  String get modelList => _text('modelList');
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
  String get approvalPolicy => _text('approvalPolicy');
  String get sandboxMode => _text('sandboxMode');
  String get cwdOverride => _text('cwdOverride');
  String get applyOverrides => _text('applyOverrides');
  String get clearOverrides => _text('clearOverrides');
  String get overrideSource => _text('overrideSource');
  String get sourceServerDefault => _text('sourceServerDefault');
  String get sourceAppDefault => _text('sourceAppDefault');
  String get sourceSessionOverride => _text('sourceSessionOverride');
  String get sourceTurnOverride => _text('sourceTurnOverride');
  String get nextTurnOverrides => _text('nextTurnOverrides');
  String get editTurnOverrides => _text('editTurnOverrides');
  String get applyTurnOverrides => _text('applyTurnOverrides');
  String get clearTurnOverrides => _text('clearTurnOverrides');
  String get serverConfigSnapshot => _text('serverConfigSnapshot');
  String get refreshServerConfig => _text('refreshServerConfig');
  String get serverConfigUnavailable => _text('serverConfigUnavailable');
  String get serverConfigLoadFailed => _text('serverConfigLoadFailed');
  String get serverValueUnset => _text('serverValueUnset');
  String configLayersLoaded(int count) =>
      _text('configLayersLoaded').replaceAll('{count}', count.toString());
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
    'agentCommand': 'Agent command',
    'saveProfile': 'Save profile',
    'savingProfile': 'Saving',
    'profileSaved': 'Profile saved.',
    'test': 'Test',
    'testing': 'Testing',
    'hostRequired': 'Host is required',
    'usernameRequired': 'Username is required',
    'passwordRequired': 'Password is required',
    'agentCommandRequired': 'Agent command is required',
    'invalidPort': 'Invalid port',
    'notTested': 'Not tested',
    'testingConnection': 'Testing connection',
    'probePassed': 'Probe passed',
    'probeFailed': 'Probe failed',
    'agentStatus': 'Agent status',
    'proxyConnect': 'Proxy connect',
    'initialize': 'Initialize',
    'modelList': 'Model list',
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
    'approvalPolicy': 'Approval policy',
    'sandboxMode': 'Sandbox mode',
    'cwdOverride': 'Working directory',
    'applyOverrides': 'Apply overrides',
    'clearOverrides': 'Clear overrides',
    'overrideSource': 'Source',
    'sourceServerDefault': 'server default',
    'sourceAppDefault': 'app default',
    'sourceSessionOverride': 'session override',
    'sourceTurnOverride': 'turn override',
    'nextTurnOverrides': 'Next turn overrides',
    'editTurnOverrides': 'Edit next turn overrides',
    'applyTurnOverrides': 'Apply to next turn',
    'clearTurnOverrides': 'Clear next turn overrides',
    'serverConfigSnapshot': 'Server config snapshot',
    'refreshServerConfig': 'Refresh server config',
    'serverConfigUnavailable': 'Connect to a host, then refresh server config.',
    'serverConfigLoadFailed': 'Failed to load server config',
    'serverValueUnset': 'not set',
    'configLayersLoaded': 'Config layers loaded: {count}',
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
    'agentCommand': 'Agent 命令',
    'saveProfile': '保存配置',
    'savingProfile': '保存中',
    'profileSaved': '配置已保存。',
    'test': '测试',
    'testing': '测试中',
    'hostRequired': '请填写主机',
    'usernameRequired': '请填写用户名',
    'passwordRequired': '请填写密码',
    'agentCommandRequired': '请填写 Agent 命令',
    'invalidPort': '端口无效',
    'notTested': '未测试',
    'testingConnection': '正在测试连接',
    'probePassed': '测试通过',
    'probeFailed': '测试失败',
    'agentStatus': 'Agent 状态',
    'proxyConnect': '代理连接',
    'initialize': '初始化',
    'modelList': '模型列表',
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
    'approvalPolicy': '审批策略',
    'sandboxMode': '沙盒模式',
    'cwdOverride': '工作目录',
    'applyOverrides': '应用覆盖',
    'clearOverrides': '清除覆盖',
    'overrideSource': '来源',
    'sourceServerDefault': '服务器默认',
    'sourceAppDefault': 'App 默认',
    'sourceSessionOverride': '会话覆盖',
    'sourceTurnOverride': '本次覆盖',
    'nextTurnOverrides': '本次回合覆盖',
    'editTurnOverrides': '编辑本次回合覆盖',
    'applyTurnOverrides': '应用到本次回合',
    'clearTurnOverrides': '清除本次回合覆盖',
    'serverConfigSnapshot': '服务器配置快照',
    'refreshServerConfig': '刷新服务器配置',
    'serverConfigUnavailable': '连接主机后刷新服务器配置。',
    'serverConfigLoadFailed': '服务器配置加载失败',
    'serverValueUnset': '未设置',
    'configLayersLoaded': '已加载配置层：{count}',
    'theme': '主题',
    'themeBody': '支持跟随系统、浅色和深色模式。',
  },
};

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
