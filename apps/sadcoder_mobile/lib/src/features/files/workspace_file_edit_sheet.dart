import 'package:flutter/material.dart';

import '../../i18n/app_localizations.dart';

Future<String?> showWorkspaceFileEditSheet({
  required BuildContext context,
  required String path,
  required String content,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WorkspaceFileEditSheet(path: path, content: content),
  );
}

class _WorkspaceFileEditSheet extends StatefulWidget {
  const _WorkspaceFileEditSheet({required this.path, required this.content});

  final String path;
  final String content;

  @override
  State<_WorkspaceFileEditSheet> createState() =>
      _WorkspaceFileEditSheetState();
}

class _WorkspaceFileEditSheetState extends State<_WorkspaceFileEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.path,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('workspace-file-edit-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.close,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('workspace-file-edit-field'),
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey('workspace-file-edit-save'),
                onPressed: () => Navigator.of(context).pop(_controller.text),
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.workspaceFilesSaveEdit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
