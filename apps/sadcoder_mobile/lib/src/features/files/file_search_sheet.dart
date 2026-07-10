import 'dart:async';

import 'package:flutter/material.dart';

import '../../files/file_search_reader.dart';
import '../../i18n/app_localizations.dart';

class FileSearchSheet extends StatefulWidget {
  const FileSearchSheet({
    super.key,
    required this.reader,
    required this.roots,
    required this.title,
    required this.searchHint,
    this.initialQuery = '',
  });

  final FileSearchReader reader;
  final List<String> roots;
  final String title;
  final String searchHint;
  final String initialQuery;

  @override
  State<FileSearchSheet> createState() => _FileSearchSheetState();
}

class _FileSearchSheetState extends State<FileSearchSheet> {
  final TextEditingController _queryController = TextEditingController();
  FileSearchResultPage? _page;
  Object? _error;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.initialQuery.trim();
    unawaited(_load());
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.attach_file),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: l10n.approvalCancel,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('chat-mention-search-field'),
                controller: _queryController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _load(),
              ),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              Flexible(child: _buildResults(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final l10n = context.l10n;
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          '${l10n.mentionLoadFailed}: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    final files = _page?.files ?? const <FileSearchMatch>[];
    if (files.isEmpty && _loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(l10n.mentionNoResults),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return ListTile(
          key: ValueKey('chat-mention-file-${file.path}'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(file.path, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: file.root.isEmpty
              ? null
              : Text(file.root, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.of(context).pop(file),
        );
      },
    );
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.reader.searchFiles(
        query: _queryController.text.trim(),
        roots: widget.roots,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _page = page;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }
}
