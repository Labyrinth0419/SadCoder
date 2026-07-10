part of 'workspace_files_page.dart';

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.preview,
    required this.onModeChanged,
    required this.onLoadMore,
    this.errorText,
  });

  final _FilePreviewState preview;
  final ValueChanged<_PreviewMode> onModeChanged;
  final VoidCallback onLoadMore;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (preview.status) {
          _PreviewStatus.idle => _PreviewEmpty(
            text: l10n.workspaceFilesPreviewEmpty,
          ),
          _PreviewStatus.loading => _PreviewLoading(
            root: preview.root,
            path: preview.path,
          ),
          _PreviewStatus.failed => _PreviewError(
            root: preview.root,
            path: preview.path,
            stat: preview.stat,
            text: errorText ?? l10n.workspaceFilesReadFailed,
          ),
          _PreviewStatus.loaded => _PreviewContent(
            preview: preview,
            onModeChanged: onModeChanged,
            onLoadMore: onLoadMore,
            loadMoreErrorText: preview.loadMoreError == null
                ? null
                : _workspaceFailureMessage(l10n, preview.loadMoreError!),
          ),
        },
      ),
    );
  }
}

class _PreviewEmpty extends StatelessWidget {
  const _PreviewEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.description_outlined, size: 36),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}

class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading({required this.root, required this.path});

  final String? root;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final displayPath = _workspaceDisplayPath(
      root: root,
      path: path,
      fallback: context.l10n.workspaceFilesLoading,
    );
    return Row(
      children: [
        const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(displayPath)),
      ],
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({
    required this.root,
    required this.path,
    required this.text,
    this.stat,
  });

  final String? root;
  final String? path;
  final String text;
  final WorkspaceFileStat? stat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stat = this.stat;
    final displayPath = _workspaceDisplayPath(
      root: root,
      path: path,
      fallback: l10n.workspaceFilesOpenFailed,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(displayPath)),
          ],
        ),
        if (stat != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (stat.sizeBytes != null)
                Chip(label: Text(l10n.workspaceFilesFileSize(stat.sizeBytes!))),
              Chip(
                label: Text(
                  l10n.workspaceFilesFileType(_fileTypeLabel(l10n, stat)),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(text),
      ],
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({
    required this.preview,
    required this.onModeChanged,
    required this.onLoadMore,
    this.loadMoreErrorText,
  });

  final _FilePreviewState preview;
  final ValueChanged<_PreviewMode> onModeChanged;
  final VoidCallback onLoadMore;
  final String? loadMoreErrorText;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isMarkdown = preview.isMarkdown;
    final canRenderMarkdown =
        isMarkdown &&
        !preview.hasMore &&
        preview.sizeBytes <= _markdownRenderLimitBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(_fileIcon(preview.path ?? '')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _previewDisplayPath(preview),
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.workspaceFilesLoadedBytes(
                      preview.bytesLoaded,
                      preview.sizeBytes,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isMarkdown) ...[
          const SizedBox(height: 12),
          SegmentedButton<_PreviewMode>(
            key: const ValueKey('workspace-files-markdown-mode'),
            segments: [
              ButtonSegment(
                value: _PreviewMode.render,
                enabled: canRenderMarkdown,
                icon: const Icon(Icons.article_outlined),
                label: Text(l10n.workspaceFilesRendered),
              ),
              ButtonSegment(
                value: _PreviewMode.raw,
                icon: const Icon(Icons.code),
                label: Text(l10n.workspaceFilesRaw),
              ),
            ],
            selected: {canRenderMarkdown ? preview.mode : _PreviewMode.raw},
            onSelectionChanged: (selection) {
              onModeChanged(selection.single);
            },
          ),
        ],
        if (preview.hasMore) ...[
          const SizedBox(height: 12),
          Text(l10n.workspaceFilesLargeFile),
        ],
        const SizedBox(height: 12),
        _PreviewBody(preview: preview, canRenderMarkdown: canRenderMarkdown),
        if (preview.hasMore) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('workspace-files-preview-load-more'),
              onPressed: preview.loadingMore ? null : onLoadMore,
              icon: preview.loadingMore
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(l10n.workspaceFilesLoadMore),
            ),
          ),
        ],
        if (loadMoreErrorText != null) ...[
          const SizedBox(height: 8),
          Text(
            loadMoreErrorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

String _previewDisplayPath(_FilePreviewState preview) {
  return _workspaceDisplayPath(
    root: preview.root,
    path: preview.path,
    fallback: '',
  );
}

String _workspaceDisplayPath({
  required String? root,
  required String? path,
  required String fallback,
}) {
  if (root == null || path == null) {
    return path ?? fallback;
  }
  try {
    return WorkspacePath.fromRoot(root, path).absolutePath;
  } on Object {
    return path;
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.preview, required this.canRenderMarkdown});

  final _FilePreviewState preview;
  final bool canRenderMarkdown;

  @override
  Widget build(BuildContext context) {
    final content = preview.content;
    if (preview.isMarkdown &&
        preview.mode == _PreviewMode.render &&
        canRenderMarkdown) {
      return _MarkdownPreview(content: content);
    }
    if (_isCodeLanguage(preview.stat?.language) ||
        _isCodePath(preview.path ?? '')) {
      return _CodePreview(content: content, language: preview.stat?.language);
    }
    return _RawPreview(content: content);
  }
}

class _RawPreview extends StatelessWidget {
  const _RawPreview({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final colors = SadCoderThemeColors.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.codeBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(
          content,
          style: TextStyle(
            fontFamily: 'monospace',
            color: colors.codeForeground,
          ),
        ),
      ),
    );
  }
}

class _CodePreview extends StatelessWidget {
  const _CodePreview({required this.content, this.language});

  final String content;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final colors = SadCoderThemeColors.of(context);
    final base = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      color: colors.codeForeground,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.codeBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText.rich(
          TextSpan(
            style: base,
            children: _highlightSpans(context, content, language),
          ),
        ),
      ),
    );
  }
}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    final codeBuffer = StringBuffer();
    var inCode = false;
    for (final line in lines) {
      if (line.trimLeft().startsWith('```')) {
        if (inCode) {
          widgets.add(_CodeBlock(text: codeBuffer.toString()));
          codeBuffer.clear();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        codeBuffer.writeln(line);
        continue;
      }
      widgets.add(_markdownLine(context, line));
    }
    if (codeBuffer.isNotEmpty) {
      widgets.add(_CodeBlock(text: codeBuffer.toString()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = SadCoderThemeColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.codeBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            color: colors.codeForeground,
          ),
        ),
      ),
    );
  }
}

Widget _markdownLine(BuildContext context, String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return const SizedBox(height: 8);
  }
  if (trimmed.startsWith('# ')) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: SelectableText(
        trimmed.substring(2),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
  if (trimmed.startsWith('## ')) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: SelectableText(
        trimmed.substring(3),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
  if (trimmed.startsWith('- ')) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: SelectableText(trimmed.substring(2))),
        ],
      ),
    );
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: SelectableText(line),
  );
}

List<TextSpan> _highlightSpans(
  BuildContext context,
  String content,
  String? language,
) {
  final colors = SadCoderThemeColors.of(context);
  final keywordStyle = TextStyle(
    color: colors.codeKeyword,
    fontWeight: FontWeight.w600,
  );
  final stringStyle = TextStyle(color: colors.codeString);
  final commentStyle = TextStyle(color: colors.codeComment);
  final keywordPattern = _keywordPattern(language);
  final spans = <TextSpan>[];
  for (final line in content.split('\n')) {
    final commentIndex = _commentIndex(line);
    final code = commentIndex == -1 ? line : line.substring(0, commentIndex);
    final comment = commentIndex == -1 ? '' : line.substring(commentIndex);
    spans.addAll(
      _codeLineSpans(code, keywordPattern, keywordStyle, stringStyle),
    );
    if (comment.isNotEmpty) {
      spans.add(TextSpan(text: comment, style: commentStyle));
    }
    spans.add(const TextSpan(text: '\n'));
  }
  return spans;
}

List<TextSpan> _codeLineSpans(
  String code,
  RegExp keywordPattern,
  TextStyle keywordStyle,
  TextStyle stringStyle,
) {
  final spans = <TextSpan>[];
  final pattern = RegExp(
    '("(?:[^"\\\\]|\\\\.)*"|\'(?:[^\'\\\\]|\\\\.)*\'|${keywordPattern.pattern})',
  );
  var cursor = 0;
  for (final match in pattern.allMatches(code)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: code.substring(cursor, match.start)));
    }
    final text = match.group(0)!;
    final isString = text.startsWith('"') || text.startsWith("'");
    spans.add(
      TextSpan(text: text, style: isString ? stringStyle : keywordStyle),
    );
    cursor = match.end;
  }
  if (cursor < code.length) {
    spans.add(TextSpan(text: code.substring(cursor)));
  }
  return spans;
}

RegExp _keywordPattern(String? language) {
  final common = switch (language?.toLowerCase()) {
    'dart' => [
      'class',
      'const',
      'final',
      'return',
      'if',
      'else',
      'for',
      'while',
      'switch',
      'case',
      'import',
      'Future',
      'void',
    ],
    'rust' => [
      'fn',
      'let',
      'mut',
      'pub',
      'impl',
      'struct',
      'enum',
      'match',
      'use',
      'mod',
      'async',
      'await',
      'return',
    ],
    _ => [
      'class',
      'const',
      'final',
      'return',
      'if',
      'else',
      'for',
      'while',
      'switch',
      'case',
      'fn',
      'let',
    ],
  };
  return RegExp('\\b(?:${common.join('|')})\\b');
}

int _commentIndex(String line) {
  var inSingleQuotedString = false;
  var inDoubleQuotedString = false;
  var escaped = false;
  for (var index = 0; index < line.length; index++) {
    final char = line[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (inSingleQuotedString || inDoubleQuotedString) {
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (char == "'" && inSingleQuotedString) {
        inSingleQuotedString = false;
      } else if (char == '"' && inDoubleQuotedString) {
        inDoubleQuotedString = false;
      }
      continue;
    }
    if (char == "'") {
      inSingleQuotedString = true;
      continue;
    }
    if (char == '"') {
      inDoubleQuotedString = true;
      continue;
    }
    if (char == '/' && index + 1 < line.length && line[index + 1] == '/') {
      return index;
    }
  }

  final firstNonWhitespace = line.indexOf(RegExp(r'\S'));
  if (firstNonWhitespace != -1 && line[firstNonWhitespace] == '#') {
    return firstNonWhitespace;
  }
  return -1;
}
