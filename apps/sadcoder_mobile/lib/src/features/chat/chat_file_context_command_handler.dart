import 'package:flutter/material.dart';

import '../../commands/slash_command_action_dispatcher.dart';
import '../../files/file_search_reader.dart';
import '../../i18n/app_localizations.dart';
import '../files/file_search_sheet.dart';

typedef ChatFileContextRootsProvider = List<String> Function();
typedef ChatFileContextMentionInserter = void Function(FileSearchMatch match);

class ChatFileContextCommandHandler {
  const ChatFileContextCommandHandler({
    required this.context,
    required this.mounted,
    required this.fileSearchReader,
    required this.currentWorkspaceCwdsProvider,
    required this.insertMention,
  });

  final BuildContext context;
  final bool Function() mounted;
  final FileSearchReader? fileSearchReader;
  final ChatFileContextRootsProvider currentWorkspaceCwdsProvider;
  final ChatFileContextMentionInserter insertMention;

  Future<SlashCommandCallbackResult> mentionFile() async {
    return _selectFileMention(
      title: context.l10n.mentionCommandTitle,
      searchHint: context.l10n.mentionSearchHint,
    );
  }

  Future<SlashCommandCallbackResult> attachIdeContext(String arguments) async {
    return _selectFileMention(
      title: context.l10n.ideContextCommandTitle,
      searchHint: context.l10n.ideContextSearchHint,
      initialQuery: arguments.trim(),
    );
  }

  Future<SlashCommandCallbackResult> _selectFileMention({
    required String title,
    required String searchHint,
    String initialQuery = '',
  }) async {
    final reader = fileSearchReader;
    final roots = currentWorkspaceCwdsProvider();
    if (reader == null || roots.isEmpty) {
      return SlashCommandCallbackResult.unavailable;
    }

    final match = await showModalBottomSheet<FileSearchMatch>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FileSearchSheet(
        reader: reader,
        roots: roots,
        title: title,
        searchHint: searchHint,
        initialQuery: initialQuery,
      ),
    );
    if (!mounted() || match == null) {
      return SlashCommandCallbackResult.cancelled;
    }

    insertMention(match);
    return SlashCommandCallbackResult.executed;
  }
}
