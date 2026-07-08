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
  String get approvals => _text('approvals');
  String get settings => _text('settings');
  String get sshProfile => _text('sshProfile');
  String get name => _text('name');
  String get host => _text('host');
  String get port => _text('port');
  String get username => _text('username');
  String get password => _text('password');
  String get agentCommand => _text('agentCommand');
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
  String get disconnected => _text('disconnected');
  String get m0ProtocolClient => _text('m0ProtocolClient');
  String get m0ProtocolClientBody => _text('m0ProtocolClientBody');
  String get slashCommandSurface => _text('slashCommandSurface');
  String get slashCommandSurfaceBody => _text('slashCommandSurfaceBody');
  String get connectBeforeTurn => _text('connectBeforeTurn');
  String get send => _text('send');
  String get slashCommands => _text('slashCommands');
  String get typeCommandName => _text('typeCommandName');
  String slashCommandUnknown(String slash) =>
      _text('slashCommandUnknown').replaceAll('{slash}', slash);
  String get slashCommandNotSentAsPrompt =>
      _text('slashCommandNotSentAsPrompt');
  String get noPendingApprovals => _text('noPendingApprovals');
  String get approvalsBody => _text('approvalsBody');
  String get serverDefaults => _text('serverDefaults');
  String get serverDefaultsBody => _text('serverDefaultsBody');
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
    'approvals': 'Approvals',
    'settings': 'Settings',
    'sshProfile': 'SSH profile',
    'name': 'Name',
    'host': 'Host',
    'port': 'Port',
    'username': 'Username',
    'password': 'Password',
    'agentCommand': 'Agent command',
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
    'disconnected': 'Disconnected',
    'm0ProtocolClient': 'M0 protocol client',
    'm0ProtocolClientBody':
        'The app has a JSON-RPC client for initialize, model/list, and thread/list. SSH transport uses the same interface.',
    'slashCommandSurface': 'Slash command surface',
    'slashCommandSurfaceBody':
        'Typing / will later open the SadCoder command palette instead of sending slash text as a normal prompt.',
    'connectBeforeTurn': 'Connect to a host before sending a turn',
    'send': 'Send',
    'slashCommands': 'Slash commands',
    'typeCommandName': 'Type a command name',
    'slashCommandUnknown': 'Unknown command: {slash}',
    'slashCommandNotSentAsPrompt': 'Not sent as a prompt',
    'noPendingApprovals': 'No pending approvals',
    'approvalsBody':
        'Command, file, and MCP requests will appear here with their thread and turn IDs.',
    'serverDefaults': 'Server defaults',
    'serverDefaultsBody':
        'Codex configuration is inherited from the server unless an override is explicitly set.',
    'theme': 'Theme',
    'themeBody': 'System, light, and dark modes are supported.',
  },
  'zh': {
    'appTitle': 'SadCoder',
    'hosts': '主机',
    'chat': '对话',
    'approvals': '审批',
    'settings': '设置',
    'sshProfile': 'SSH 配置',
    'name': '名称',
    'host': '主机',
    'port': '端口',
    'username': '用户名',
    'password': '密码',
    'agentCommand': 'Agent 命令',
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
    'disconnected': '未连接',
    'm0ProtocolClient': 'M0 协议客户端',
    'm0ProtocolClientBody':
        '应用已经具备 initialize、model/list 和 thread/list 的 JSON-RPC 客户端，SSH 传输复用同一接口。',
    'slashCommandSurface': '斜杠命令入口',
    'slashCommandSurfaceBody': '输入 / 后会打开 SadCoder 命令面板，而不是把斜杠文本当作普通提示词发送。',
    'connectBeforeTurn': '连接主机后才能发送任务',
    'send': '发送',
    'slashCommands': '斜杠命令',
    'typeCommandName': '输入命令名称',
    'slashCommandUnknown': '未知命令：{slash}',
    'slashCommandNotSentAsPrompt': '不会作为普通提示词发送',
    'noPendingApprovals': '暂无待审批请求',
    'approvalsBody': '命令、文件和 MCP 请求会在这里显示对应的会话与回合 ID。',
    'serverDefaults': '服务器默认配置',
    'serverDefaultsBody': '默认沿用服务器上的 Codex 配置，只有显式设置时才覆盖。',
    'theme': '主题',
    'themeBody': '支持跟随系统、浅色和深色模式。',
  },
};

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
