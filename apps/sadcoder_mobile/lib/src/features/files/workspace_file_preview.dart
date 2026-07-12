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
    if (preview.status == _PreviewStatus.idle) {
      return _StatusPanel(
        icon: Icons.description_outlined,
        title: l10n.workspaceFilesPreviewEmpty,
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('workspace-files-preview-surface'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 260),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (preview.status) {
            _PreviewStatus.idle => const SizedBox.shrink(),
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
      ),
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
    final canRenderMarkdown = _canRenderMarkdown(preview);
    final hasLoadMoreError = loadMoreErrorText != null;
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
          if (!canRenderMarkdown) ...[
            const SizedBox(height: 8),
            Text(
              l10n.workspaceFilesMarkdownRenderLimited,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
                  : Icon(hasLoadMoreError ? Icons.refresh : Icons.expand_more),
              label: Text(
                hasLoadMoreError
                    ? l10n.workspaceFilesRetry
                    : l10n.workspaceFilesLoadMore,
              ),
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
      return WorkspaceMarkdownPreview(content: content);
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
    final highlighter = WorkspaceSyntaxHighlighter(
      colors: colors,
      language: language,
      baseStyle: base,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.codeBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText.rich(highlighter.format(content)),
      ),
    );
  }
}
