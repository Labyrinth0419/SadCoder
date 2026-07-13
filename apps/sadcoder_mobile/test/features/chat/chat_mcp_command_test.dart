import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_mcp_command.dart';

void main() {
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

  test('unsupported arguments are rejected', () {
    expect(parseChatMcpCommand('verbose extra'), isNull);
    expect(parseChatMcpCommand('reload now'), isNull);
    expect(parseChatMcpCommand('login'), isNull);
    expect(parseChatMcpCommand('unknown'), isNull);
  });
}
