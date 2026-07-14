import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_mcp_command.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_resource_reader.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_config_runner.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_oauth_runner.dart'
    show McpServerOAuthLoginResult, McpServerOAuthRunner;
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_controller.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_reader.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test('empty arguments default to a compact MCP summary command', () {
    final command = parseChatMcpCommand('');

    expect(command, isA<ChatMcpSummaryCommand>());
    expect((command as ChatMcpSummaryCommand).verbose, isFalse);
  });

  test('verbose arguments enable full MCP summaries', () {
    final command = parseChatMcpCommand('verbose');

    expect(command, isA<ChatMcpSummaryCommand>());
    expect((command as ChatMcpSummaryCommand).verbose, isTrue);
  });

  test('reload and refresh map to reload commands', () {
    final reload = parseChatMcpCommand('reload');
    final refresh = parseChatMcpCommand('refresh');

    expect(reload, isA<ChatMcpReloadCommand>());
    expect((reload as ChatMcpReloadCommand).verbose, isFalse);
    expect(refresh, isA<ChatMcpReloadCommand>());
    expect((refresh as ChatMcpReloadCommand).verbose, isFalse);
  });

  test('login aliases parse the target server name', () {
    final login = parseChatMcpCommand('login my-server');
    final oauth = parseChatMcpCommand('oauth other-server');
    final auth = parseChatMcpCommand('auth service-1');

    expect(login, isA<ChatMcpLoginCommand>());
    expect((login as ChatMcpLoginCommand).serverName, 'my-server');
    expect(oauth, isA<ChatMcpLoginCommand>());
    expect((oauth as ChatMcpLoginCommand).serverName, 'other-server');
    expect(auth, isA<ChatMcpLoginCommand>());
    expect((auth as ChatMcpLoginCommand).serverName, 'service-1');
  });

  test('resource aliases parse the server name and URI', () {
    final resource = parseChatMcpCommand('resource docs docs://guide');
    final alias = parseChatMcpCommand('read-resource github repo://readme');

    expect(resource, isA<ChatMcpResourceReadCommand>());
    expect(
      resource,
      isA<ChatMcpResourceReadCommand>()
          .having((command) => command.serverName, 'serverName', 'docs')
          .having((command) => command.uri, 'uri', 'docs://guide'),
    );
    expect(
      alias,
      isA<ChatMcpResourceReadCommand>()
          .having((command) => command.serverName, 'serverName', 'github')
          .having((command) => command.uri, 'uri', 'repo://readme'),
    );
  });

  test('unsupported arguments are rejected', () {
    expect(parseChatMcpCommand('verbose extra'), isNull);
    expect(parseChatMcpCommand('reload now'), isNull);
    expect(parseChatMcpCommand('login'), isNull);
    expect(parseChatMcpCommand('resource'), isNull);
    expect(parseChatMcpCommand('resource docs'), isNull);
    expect(parseChatMcpCommand('resource docs docs://guide extra'), isNull);
    expect(parseChatMcpCommand('unknown'), isNull);
  });

  group('buildMcpSummaryFromCommand', () {
    test('summarizes the selected MCP servers', () async {
      final reader = _RecordingMcpServerStatusReader(
        page: McpServerStatusPage.fromJson({
          'data': [
            {
              'name': 'filesystem',
              'authStatus': 'unsupported',
              'tools': {
                'read_file': {'name': 'read_file'},
              },
            },
          ],
        }),
      );
      final controller = McpServerStatusController(
        readerProvider: () => reader,
      );
      addTearDown(controller.dispose);

      final summary = await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: controller,
        oauthRunner: null,
        configRunner: null,
        threadId: 'thr_1',
        arguments: '',
      );

      expect(reader.threadIds, ['thr_1']);
      expect(reader.limits, [25]);
      expect(reader.details, [McpServerStatusDetail.toolsAndAuthOnly]);
      expect(summary, contains('MCP servers'));
      expect(summary, contains('filesystem: auth: unsupported, tools: 1'));
    });

    test('verbose summaries request full MCP detail', () async {
      final reader = _RecordingMcpServerStatusReader(
        page: const McpServerStatusPage(servers: []),
      );
      final controller = McpServerStatusController(
        readerProvider: () => reader,
      );
      addTearDown(controller.dispose);

      await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: controller,
        oauthRunner: null,
        configRunner: null,
        threadId: 'thr_1',
        arguments: 'verbose',
      );

      expect(reader.details, [McpServerStatusDetail.full]);
    });

    test('reloads MCP config before summarizing', () async {
      final reader = _RecordingMcpServerStatusReader(
        page: McpServerStatusPage.fromJson({
          'data': [
            {
              'name': 'filesystem',
              'authStatus': 'unsupported',
              'tools': {
                'read_file': {'name': 'read_file'},
              },
            },
          ],
        }),
      );
      final controller = McpServerStatusController(
        readerProvider: () => reader,
      );
      final configRunner = _RecordingMcpServerConfigRunner();
      addTearDown(controller.dispose);

      final summary = await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: controller,
        oauthRunner: null,
        configRunner: configRunner,
        threadId: 'thr_1',
        arguments: 'reload',
      );

      expect(configRunner.reloadCalls, 1);
      expect(summary, contains(l10n.mcpServersReloaded));
      expect(summary, contains('filesystem: auth: unsupported, tools: 1'));
    });

    test('starts OAuth login when a server name is provided', () async {
      final oauthRunner = _RecordingMcpServerOAuthRunner(
        result: const McpServerOAuthLoginResult(
          serverName: 'github',
          authorizationUrl: 'https://example.test/oauth',
          userCode: 'ABCD-1234',
          raw: <String, Object?>{},
        ),
      );

      final summary = await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: null,
        oauthRunner: oauthRunner,
        configRunner: null,
        threadId: 'thr_1',
        arguments: 'login github',
      );

      expect(oauthRunner.serverNames, ['github']);
      expect(summary, contains('Started MCP OAuth login for github.'));
      expect(summary, contains('Open URL: https://example.test/oauth'));
      expect(summary, contains('Code: ABCD-1234'));
    });

    test('reads MCP resource text for the current thread exactly', () async {
      final reader = _RecordingMcpResourceReader(
        result: McpResourceReadResult.fromJson({
          'contents': [
            {
              'uri': 'docs://guide',
              'mimeType': 'text/markdown',
              'text': '  First line\nSecond line\n',
            },
          ],
        }),
      );

      final summary = await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: null,
        oauthRunner: null,
        configRunner: null,
        resourceReader: reader,
        threadId: 'thr_1',
        arguments: 'resource docs docs://guide',
      );

      expect(reader.calls, [
        (threadId: 'thr_1', server: 'docs', uri: 'docs://guide'),
      ]);
      expect(
        summary,
        'MCP servers\n'
        'server: docs\n'
        'resources: docs://guide\n'
        'docs://guide (text/markdown)\n'
        '  First line\nSecond line\n',
      );
    });

    test('summarizes blob and empty MCP resource results', () async {
      final blobReader = _RecordingMcpResourceReader(
        result: McpResourceReadResult.fromJson({
          'contents': [
            {'uri': 'docs://logo', 'mimeType': 'image/png', 'blob': 'AAEC'},
          ],
        }),
      );
      final emptyReader = _RecordingMcpResourceReader(
        result: McpResourceReadResult.fromJson({'contents': <Object?>[]}),
      );

      final blobSummary = await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: null,
        oauthRunner: null,
        configRunner: null,
        resourceReader: blobReader,
        threadId: null,
        arguments: 'read-resource docs docs://logo',
      );
      final emptySummary = await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: null,
        oauthRunner: null,
        configRunner: null,
        resourceReader: emptyReader,
        threadId: null,
        arguments: 'resource docs docs://empty',
      );

      expect(blobSummary, contains('docs://logo (image/png)'));
      expect(blobSummary, contains('Binary resource (4 base64 characters).'));
      expect(blobSummary, isNot(contains('AAEC')));
      expect(emptySummary, contains('The MCP resource returned no contents.'));
    });

    test('localizes MCP resource failures and preserves raw detail', () async {
      final summary = await buildMcpSummaryFromCommand(
        l10n: const AppLocalizations(Locale('zh')),
        statusController: null,
        oauthRunner: null,
        configRunner: null,
        resourceReader: _ThrowingMcpResourceReader(StateError('raw detail')),
        threadId: 'thr_1',
        arguments: 'resource docs docs://guide',
      );

      expect(summary, contains('MCP 资源读取失败'));
      expect(summary, contains('raw detail'));
    });

    test('resource commands require a connected resource reader', () async {
      final summary = await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: null,
        oauthRunner: null,
        configRunner: null,
        resourceReader: null,
        threadId: 'thr_1',
        arguments: 'resource docs docs://guide',
      );

      expect(summary, isNull);
    });

    test('rejects missing runners and unsupported inputs', () async {
      final summaryUnavailable = await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: null,
        oauthRunner: null,
        configRunner: null,
        threadId: 'thr_1',
        arguments: '',
      );
      final loginUnavailable = await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: null,
        oauthRunner: null,
        configRunner: null,
        threadId: 'thr_1',
        arguments: 'login github',
      );
      final reloadUnavailable = await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: null,
        oauthRunner: null,
        configRunner: null,
        threadId: 'thr_1',
        arguments: 'reload',
      );
      final unsupported = await buildMcpSummaryFromCommand(
        l10n: l10n,
        statusController: null,
        oauthRunner: null,
        configRunner: null,
        threadId: 'thr_1',
        arguments: 'sideways',
      );

      expect(summaryUnavailable, contains('MCP servers'));
      expect(summaryUnavailable, contains(l10n.mcpServersUnavailable));
      expect(loginUnavailable, isNull);
      expect(reloadUnavailable, isNull);
      expect(unsupported, isNull);
    });
  });
}

class _RecordingMcpServerStatusReader implements McpServerStatusReader {
  _RecordingMcpServerStatusReader({required this.page});

  final McpServerStatusPage page;
  final threadIds = <String?>[];
  final cursors = <String?>[];
  final limits = <int?>[];
  final details = <McpServerStatusDetail>[];

  @override
  Future<McpServerStatusPage> listMcpServers({
    String? threadId,
    String? cursor,
    int? limit,
    McpServerStatusDetail detail = McpServerStatusDetail.toolsAndAuthOnly,
  }) async {
    threadIds.add(threadId);
    cursors.add(cursor);
    limits.add(limit);
    details.add(detail);
    return page;
  }
}

class _RecordingMcpServerOAuthRunner implements McpServerOAuthRunner {
  _RecordingMcpServerOAuthRunner({required this.result});

  final McpServerOAuthLoginResult result;
  final serverNames = <String>[];

  @override
  Future<McpServerOAuthLoginResult> startOAuthLogin({
    required String serverName,
  }) async {
    serverNames.add(serverName);
    return result;
  }
}

class _RecordingMcpServerConfigRunner implements McpServerConfigRunner {
  var reloadCalls = 0;

  @override
  Future<void> reloadMcpServers() async {
    reloadCalls++;
  }
}

class _RecordingMcpResourceReader implements McpResourceReader {
  _RecordingMcpResourceReader({required this.result});

  final McpResourceReadResult result;
  final calls = <({String? threadId, String server, String uri})>[];

  @override
  Future<McpResourceReadResult> readResource({
    String? threadId,
    required String server,
    required String uri,
  }) async {
    calls.add((threadId: threadId, server: server, uri: uri));
    return result;
  }
}

class _ThrowingMcpResourceReader implements McpResourceReader {
  const _ThrowingMcpResourceReader(this.error);

  final Object error;

  @override
  Future<McpResourceReadResult> readResource({
    String? threadId,
    required String server,
    required String uri,
  }) async {
    throw error;
  }
}
