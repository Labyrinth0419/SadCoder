sealed class ChatMcpCommand {
  const ChatMcpCommand();
}

final class ChatMcpSummaryCommand extends ChatMcpCommand {
  const ChatMcpSummaryCommand({required this.verbose});

  final bool verbose;
}

final class ChatMcpReloadCommand extends ChatMcpCommand {
  const ChatMcpReloadCommand({required this.verbose});

  final bool verbose;
}

final class ChatMcpLoginCommand extends ChatMcpCommand {
  const ChatMcpLoginCommand({required this.serverName});

  final String serverName;
}

ChatMcpCommand? parseChatMcpCommand(String arguments) {
  final parts = arguments
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return const ChatMcpSummaryCommand(verbose: false);
  }

  final command = parts.first.toLowerCase();
  if (parts.length == 1 && command == 'verbose') {
    return const ChatMcpSummaryCommand(verbose: true);
  }
  if (parts.length == 1 && (command == 'reload' || command == 'refresh')) {
    return const ChatMcpReloadCommand(verbose: false);
  }
  if (parts.length == 2 &&
      (command == 'login' || command == 'oauth' || command == 'auth')) {
    return ChatMcpLoginCommand(serverName: parts[1]);
  }
  return null;
}
