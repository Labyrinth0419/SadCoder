import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/codex_config_override_controller.dart';
import '../../files/file_search_reader.dart';
import '../../files/workspace_directory_reader.dart';
import '../../files/workspace_file_failure.dart';
import '../../files/workspace_file_kind.dart';
import '../../files/workspace_file_reader.dart';
import '../../files/workspace_path.dart';
import '../../i18n/app_localizations.dart';
import '../../session/codex_session_state_controller.dart';
import '../../theme/sadcoder_theme.dart';
import '../../threads/thread_detail_controller.dart';
import 'file_search_sheet.dart';

part 'workspace_file_preview.dart';

const _directoryPageLimit = 100;
const _fileChunkBytes = 32 * 1024;
const _markdownRenderLimitBytes = 256 * 1024;
const _unchanged = Object();

class WorkspaceFilesPage extends StatefulWidget {
  const WorkspaceFilesPage({
    super.key,
    this.sessionController,
    this.threadDetailController,
    this.configOverrideController,
    this.directoryReader,
    this.fileReader,
    this.fileSearchReader,
    this.root,
  });

  final CodexSessionStateController? sessionController;
  final ThreadDetailController? threadDetailController;
  final CodexConfigOverrideController? configOverrideController;
  final WorkspaceDirectoryReader? directoryReader;
  final WorkspaceFileReader? fileReader;
  final FileSearchReader? fileSearchReader;
  final String? root;

  @override
  State<WorkspaceFilesPage> createState() => _WorkspaceFilesPageState();
}

class _WorkspaceFilesPageState extends State<WorkspaceFilesPage> {
  final TextEditingController _filterController = TextEditingController();
  final Map<String, _DirectoryLoadState> _directories = {};
  final Map<String, int> _directoryRequestIds = {};
  final Set<String> _expandedDirectories = {''};
  int _nextDirectoryRequestId = 0;
  int _nextFileRequestId = 0;
  String _filter = '';
  String? _activeRoot;
  bool _includeHidden = false;
  _FilePreviewState _preview = const _FilePreviewState.idle();

  @override
  void initState() {
    super.initState();
    _filterController.addListener(_handleFilterChanged);
    _attachListeners();
    _activeRoot = _resolvedRoot();
    unawaited(_loadDirectory(''));
  }

  @override
  void didUpdateWidget(WorkspaceFilesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    var forceReload = false;
    if (oldWidget.sessionController != widget.sessionController ||
        oldWidget.threadDetailController != widget.threadDetailController ||
        oldWidget.configOverrideController != widget.configOverrideController) {
      _detachListeners(oldWidget);
      _attachListeners();
      forceReload = true;
    }
    if (oldWidget.directoryReader != widget.directoryReader ||
        oldWidget.fileReader != widget.fileReader ||
        oldWidget.root != widget.root) {
      forceReload = true;
    }
    if (forceReload) {
      _handleSourcesChanged(forceReload: true);
    }
  }

  @override
  void dispose() {
    _detachListeners(widget);
    _filterController
      ..removeListener(_handleFilterChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final root = _resolvedRoot();
    final directoryReader = _directoryReader;
    final fileReader = _fileReader;

    if (root != _activeRoot) {
      _scheduleSourceRefresh();
    } else if (root != null &&
        directoryReader != null &&
        fileReader != null &&
        !_directories.containsKey('')) {
      _scheduleDirectoryLoad('');
    }

    return ListView(
      key: const ValueKey('workspace-files-page'),
      padding: const EdgeInsets.all(16),
      children: [
        _FilesHeader(root: root),
        const SizedBox(height: 12),
        if (directoryReader == null || fileReader == null)
          _StatusPanel(
            icon: Icons.link_off,
            title: l10n.workspaceFilesNotConnected,
          )
        else if (root == null)
          _StatusPanel(
            icon: Icons.folder_off_outlined,
            title: l10n.workspaceFilesNoCwd,
          )
        else ...[
          _FilesToolbar(
            filterController: _filterController,
            includeHidden: _includeHidden,
            onIncludeHiddenChanged: _setIncludeHidden,
            onSearch: _fileSearchReader == null ? null : _searchWorkspace,
            onRefresh: _refreshWorkspace,
          ),
          const SizedBox(height: 12),
          _DirectoryPanel(
            root: root,
            rows: _directoryRows(l10n, root: root, path: '', depth: 0),
          ),
          const SizedBox(height: 12),
          _PreviewPanel(
            preview: _preview,
            onModeChanged: _setPreviewMode,
            onLoadMore: _loadMorePreview,
            errorText: _preview.error == null
                ? null
                : _workspaceFailureMessage(l10n, _preview.error!),
          ),
        ],
      ],
    );
  }

  void _attachListeners() {
    widget.sessionController?.addListener(_handleSourcesChanged);
    widget.threadDetailController?.addListener(_handleSourcesChanged);
    widget.configOverrideController?.addListener(_handleSourcesChanged);
  }

  void _detachListeners(WorkspaceFilesPage widget) {
    widget.sessionController?.removeListener(_handleSourcesChanged);
    widget.threadDetailController?.removeListener(_handleSourcesChanged);
    widget.configOverrideController?.removeListener(_handleSourcesChanged);
  }

  WorkspaceDirectoryReader? get _directoryReader =>
      widget.directoryReader ??
      widget.sessionController?.workspaceDirectoryReader;

  WorkspaceFileReader? get _fileReader =>
      widget.fileReader ?? widget.sessionController?.workspaceFileReader;

  FileSearchReader? get _fileSearchReader =>
      widget.fileSearchReader ?? widget.sessionController?.fileSearchReader;

  String? _resolvedRoot() {
    final explicitRoot = _normalizedText(widget.root);
    if (explicitRoot != null) {
      return explicitRoot;
    }
    final overrideRoot = _normalizedText(
      widget.configOverrideController?.resolved.cwd,
    );
    if (overrideRoot != null) {
      return overrideRoot;
    }
    final threadRoot = _normalizedText(
      widget.threadDetailController?.detail?.thread.cwd,
    );
    if (threadRoot != null) {
      return threadRoot;
    }
    return _normalizedText(widget.sessionController?.profile?.defaultCwd);
  }

  void _handleFilterChanged() {
    final next = _filterController.text.trim().toLowerCase();
    if (next == _filter) {
      return;
    }
    setState(() => _filter = next);
  }

  void _handleSourcesChanged({bool forceReload = false}) {
    final nextRoot = _resolvedRoot();
    final rootChanged = nextRoot != _activeRoot;
    if (rootChanged || forceReload) {
      _activeRoot = nextRoot;
      _directories.clear();
      _directoryRequestIds.clear();
      _expandedDirectories
        ..clear()
        ..add('');
      _preview = const _FilePreviewState.idle();
    }
    if (mounted) {
      setState(() {});
    }
    if ((rootChanged || forceReload || !_directories.containsKey('')) &&
        nextRoot != null &&
        _directoryReader != null) {
      unawaited(_loadDirectory(''));
    }
  }

  void _scheduleSourceRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleSourcesChanged();
      }
    });
  }

  void _scheduleDirectoryLoad(String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_directories.containsKey(path)) {
        unawaited(_loadDirectory(path));
      }
    });
  }

  Future<void> _loadDirectory(
    String path, {
    String? cursor,
    bool append = false,
  }) async {
    final root = _activeRoot;
    final reader = _directoryReader;
    if (root == null || reader == null) {
      return;
    }

    final requestId = ++_nextDirectoryRequestId;
    _directoryRequestIds[path] = requestId;
    final existing =
        _directories[path] ?? const _DirectoryLoadState(entries: []);
    setState(() {
      _directories[path] = existing.copyWith(
        status: _DirectoryStatus.loading,
        error: null,
      );
    });

    try {
      final page = await reader.listDirectory(
        root: root,
        path: path,
        limit: _directoryPageLimit,
        cursor: cursor,
        includeHidden: _includeHidden,
      );
      if (!mounted ||
          _activeRoot != root ||
          _directoryRequestIds[path] != requestId) {
        return;
      }
      final entries = append
          ? [...existing.entries, ...page.entries]
          : page.entries;
      setState(() {
        _directories[path] = _DirectoryLoadState(
          status: _DirectoryStatus.loaded,
          entries: entries,
          nextCursor: page.nextCursor,
        );
      });
    } on Object catch (error) {
      if (!mounted ||
          _activeRoot != root ||
          _directoryRequestIds[path] != requestId) {
        return;
      }
      setState(() {
        _directories[path] = existing.copyWith(
          status: _DirectoryStatus.failed,
          error: error,
        );
      });
    }
  }

  void _toggleDirectory(String path) {
    final expanded = _expandedDirectories.contains(path);
    setState(() {
      if (expanded) {
        _expandedDirectories.remove(path);
      } else {
        _expandedDirectories.add(path);
      }
    });
    if (!expanded && !_directories.containsKey(path)) {
      unawaited(_loadDirectory(path));
    }
  }

  void _refreshWorkspace() {
    setState(() {
      _directories.clear();
      _directoryRequestIds.clear();
      _expandedDirectories
        ..clear()
        ..add('');
    });
    unawaited(_loadDirectory(''));
  }

  void _setIncludeHidden(bool value) {
    if (value == _includeHidden) {
      return;
    }
    setState(() {
      _includeHidden = value;
      _directories.clear();
      _directoryRequestIds.clear();
      _expandedDirectories
        ..clear()
        ..add('');
    });
    unawaited(_loadDirectory(''));
  }

  Future<void> _openFile(WorkspaceDirectoryEntry entry) {
    if (entry.isSymlink) {
      return _showSymlinkPreviewError(entry.path);
    }
    return _openFilePath(entry.path);
  }

  Future<void> _showSymlinkPreviewError(String path) async {
    final root = _activeRoot;
    if (root == null) {
      return;
    }
    setState(() {
      _preview = _FilePreviewState.failed(
        root: root,
        path: path,
        error: const WorkspaceFileException(
          WorkspaceFileFailureCode.pathOutsideRoot,
          'Workspace path is outside the workspace root.',
          detail: 'Symbolic links are not previewed.',
        ),
      );
    });
  }

  Future<void> _openFilePath(String path) async {
    final root = _activeRoot;
    final reader = _fileReader;
    if (root == null || reader == null) {
      return;
    }
    late final WorkspacePath workspacePath;
    try {
      workspacePath = WorkspacePath.fromRoot(root, path);
    } on Object catch (error) {
      setState(() {
        _preview = _FilePreviewState.failed(
          root: root,
          path: path,
          error: error,
        );
      });
      return;
    }
    final relativePath = workspacePath.relativePath;

    final requestId = ++_nextFileRequestId;
    setState(() {
      _preview = _FilePreviewState.loading(root: root, path: relativePath);
    });

    try {
      final stat = await reader.statFile(root: root, path: relativePath);
      final unpreviewable = _unpreviewableStatError(stat);
      if (unpreviewable != null) {
        if (!mounted ||
            requestId != _nextFileRequestId ||
            _activeRoot != root) {
          return;
        }
        setState(() {
          _preview = _FilePreviewState.failed(
            root: root,
            path: relativePath,
            stat: stat,
            error: unpreviewable,
          );
        });
        return;
      }
      final chunk = await reader.readFile(
        root: root,
        path: relativePath,
        limitBytes: _fileChunkBytes,
      );
      if (!mounted || requestId != _nextFileRequestId || _activeRoot != root) {
        return;
      }
      setState(() {
        _preview = _FilePreviewState.loaded(
          root: root,
          path: relativePath,
          stat: stat,
          content: chunk.content,
          sizeBytes: chunk.sizeBytes,
          bytesLoaded: chunk.bytesRead,
          nextOffset: chunk.nextOffset,
          hasMore: chunk.hasMore,
          mode: _initialPreviewMode(path, stat, chunk),
        );
      });
    } on Object catch (error) {
      if (!mounted || requestId != _nextFileRequestId || _activeRoot != root) {
        return;
      }
      setState(() {
        _preview = _FilePreviewState.failed(
          root: root,
          path: relativePath,
          error: error,
        );
      });
    }
  }

  Future<void> _searchWorkspace() async {
    final root = _activeRoot;
    final reader = _fileSearchReader;
    if (root == null || reader == null) {
      return;
    }
    final match = await showModalBottomSheet<FileSearchMatch>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FileSearchSheet(
        reader: reader,
        roots: [root],
        title: context.l10n.workspaceFilesTitle,
        searchHint: context.l10n.mentionSearchHint,
      ),
    );
    if (!mounted || match == null || _activeRoot != root) {
      return;
    }
    final matchRoot = _normalizedText(match.root) ?? root;
    if (matchRoot != root) {
      setState(() {
        _preview = _FilePreviewState.failed(
          root: root,
          path: match.path,
          error: const WorkspaceFileException(
            WorkspaceFileFailureCode.pathOutsideRoot,
            'Workspace path is outside the workspace root.',
          ),
        );
      });
      return;
    }
    await _openFilePath(match.path);
  }

  Future<void> _loadMorePreview() async {
    final preview = _preview;
    final root = preview.root;
    final path = preview.path;
    final offset = preview.nextOffset;
    final reader = _fileReader;
    if (preview.status != _PreviewStatus.loaded ||
        root == null ||
        path == null ||
        offset == null ||
        reader == null ||
        preview.loadingMore) {
      return;
    }

    final requestId = ++_nextFileRequestId;
    setState(() {
      _preview = preview.copyWith(loadingMore: true, loadMoreError: null);
    });

    try {
      final chunk = await reader.readFile(
        root: root,
        path: path,
        offset: offset,
        limitBytes: _fileChunkBytes,
      );
      if (!mounted || requestId != _nextFileRequestId || _activeRoot != root) {
        return;
      }
      setState(() {
        _preview = _preview.copyWith(
          content: '${preview.content}${chunk.content}',
          sizeBytes: chunk.sizeBytes,
          bytesLoaded: preview.bytesLoaded + chunk.bytesRead,
          nextOffset: chunk.nextOffset,
          hasMore: chunk.hasMore,
          loadingMore: false,
        );
      });
    } on Object catch (error) {
      if (!mounted || requestId != _nextFileRequestId || _activeRoot != root) {
        return;
      }
      setState(() {
        _preview = _preview.copyWith(loadingMore: false, loadMoreError: error);
      });
    }
  }

  void _setPreviewMode(_PreviewMode mode) {
    setState(() => _preview = _preview.copyWith(mode: mode));
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.workspaceFilesPathCopied)),
    );
  }

  List<Widget> _directoryRows(
    AppLocalizations l10n, {
    required String root,
    required String path,
    required int depth,
  }) {
    final state = _directories[path];
    if (state == null || state.status == _DirectoryStatus.loading) {
      return [
        _IndentedStatusRow(
          depth: depth,
          icon: Icons.hourglass_empty,
          text: l10n.workspaceFilesLoading,
        ),
      ];
    }
    if (state.status == _DirectoryStatus.failed) {
      return [
        _IndentedErrorRow(
          depth: depth,
          text: _workspaceFailureMessage(l10n, state.error),
          onRetry: () => _loadDirectory(path),
        ),
      ];
    }
    if (state.entries.isEmpty) {
      return [
        _IndentedStatusRow(
          depth: depth,
          icon: Icons.folder_open,
          text: l10n.workspaceFilesEmptyDirectory,
        ),
      ];
    }

    final rows = <Widget>[];
    for (final entry in state.entries) {
      if (!_matchesFilter(entry)) {
        continue;
      }
      final isDirectory =
          entry.kind == WorkspaceFileKind.directory && !entry.isSymlink;
      final expanded = _expandedDirectories.contains(entry.path);
      final displayPath = WorkspacePath.fromRoot(root, entry.path).absolutePath;
      rows.add(
        _WorkspaceEntryRow(
          key: ValueKey('workspace-files-entry-${entry.path}'),
          entry: entry,
          displayPath: displayPath,
          depth: depth,
          expanded: expanded,
          selected: entry.path == _preview.path,
          onTap: isDirectory
              ? () => _toggleDirectory(entry.path)
              : () => _openFile(entry),
          onCopy: () => _copyPath(displayPath),
        ),
      );
      if (isDirectory && expanded) {
        rows.addAll(
          _directoryRows(l10n, root: root, path: entry.path, depth: depth + 1),
        );
      }
    }
    if (state.nextCursor != null) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(left: 16.0 + depth * 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('workspace-files-load-more-$path'),
              onPressed: () =>
                  _loadDirectory(path, cursor: state.nextCursor, append: true),
              icon: const Icon(Icons.expand_more),
              label: Text(l10n.workspaceFilesLoadMore),
            ),
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      rows.add(
        _IndentedStatusRow(
          depth: depth,
          icon: Icons.search_off,
          text: l10n.workspaceFilesEmptyDirectory,
        ),
      );
    }
    return rows;
  }

  bool _matchesFilter(WorkspaceDirectoryEntry entry) {
    if (_filter.isEmpty) {
      return true;
    }
    return entry.name.toLowerCase().contains(_filter) ||
        entry.path.toLowerCase().contains(_filter);
  }
}

class _FilesHeader extends StatelessWidget {
  const _FilesHeader({required this.root});

  final String? root;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_copy_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.workspaceFilesTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        if (root != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.workspaceFilesRoot(root!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _FilesToolbar extends StatelessWidget {
  const _FilesToolbar({
    required this.filterController,
    required this.includeHidden,
    required this.onIncludeHiddenChanged,
    required this.onSearch,
    required this.onRefresh,
  });

  final TextEditingController filterController;
  final bool includeHidden;
  final ValueChanged<bool> onIncludeHiddenChanged;
  final VoidCallback? onSearch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              key: const ValueKey('workspace-files-filter'),
              controller: filterController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.workspaceFilesSearchHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    key: const ValueKey('workspace-files-hidden-toggle'),
                    contentPadding: EdgeInsets.zero,
                    value: includeHidden,
                    onChanged: (value) =>
                        onIncludeHiddenChanged(value ?? false),
                    title: Text(l10n.workspaceFilesShowHidden),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('workspace-files-remote-search'),
                  onPressed: onSearch,
                  tooltip: l10n.mentionSearchHint,
                  icon: const Icon(Icons.manage_search),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const ValueKey('workspace-files-refresh'),
                  onPressed: onRefresh,
                  tooltip: l10n.workspaceFilesRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectoryPanel extends StatelessWidget {
  const _DirectoryPanel({required this.root, required this.rows});

  final String root;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(root),
          ),
          const Divider(height: 1),
          ...rows,
        ],
      ),
    );
  }
}

class _WorkspaceEntryRow extends StatelessWidget {
  const _WorkspaceEntryRow({
    super.key,
    required this.entry,
    required this.displayPath,
    required this.depth,
    required this.expanded,
    required this.selected,
    required this.onTap,
    required this.onCopy,
  });

  final WorkspaceDirectoryEntry entry;
  final String displayPath;
  final int depth;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDirectory =
        entry.kind == WorkspaceFileKind.directory && !entry.isSymlink;
    final details = [
      displayPath,
      if (!isDirectory && entry.sizeBytes != null)
        l10n.workspaceFilesFileSize(entry.sizeBytes!),
      if (entry.modifiedAt != null)
        l10n.workspaceFilesModifiedAt(entry.modifiedAt!),
    ];
    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: 16.0 + depth * 20,
        end: 8,
      ),
      selected: selected,
      leading: Icon(
        entry.isSymlink
            ? Icons.link
            : isDirectory
            ? expanded
                  ? Icons.folder_open
                  : Icons.folder_outlined
            : _fileIcon(entry.path),
      ),
      title: Text(entry.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(details.join(' | '), overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        onPressed: onCopy,
        tooltip: l10n.workspaceFilesCopyPath,
        icon: const Icon(Icons.copy),
      ),
      onTap: onTap,
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _IndentedStatusRow extends StatelessWidget {
  const _IndentedStatusRow({
    required this.depth,
    required this.icon,
    required this.text,
  });

  final int depth;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: 16.0 + depth * 20,
        end: 16,
      ),
      leading: Icon(icon),
      title: Text(text),
    );
  }
}

class _IndentedErrorRow extends StatelessWidget {
  const _IndentedErrorRow({
    required this.depth,
    required this.text,
    required this.onRetry,
  });

  final int depth;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: 16.0 + depth * 20,
        end: 8,
      ),
      leading: const Icon(Icons.error_outline),
      title: Text(text),
      trailing: TextButton(
        onPressed: onRetry,
        child: Text(l10n.workspaceFilesRetry),
      ),
    );
  }
}

IconData _fileIcon(String path) {
  final extension = _extension(path);
  return switch (extension) {
    'md' || 'markdown' => Icons.article_outlined,
    'dart' ||
    'rs' ||
    'js' ||
    'ts' ||
    'py' ||
    'sh' ||
    'ps1' ||
    'json' => Icons.code,
    _ => Icons.description_outlined,
  };
}

String _fileTypeLabel(AppLocalizations l10n, WorkspaceFileStat stat) {
  final mimeType = _normalizedText(stat.mimeType);
  if (mimeType != null) {
    return mimeType;
  }
  final language = _normalizedText(stat.language);
  if (language != null) {
    return language;
  }
  return switch (stat.kind) {
    WorkspaceFileKind.file => l10n.workspaceFilesKindFile,
    WorkspaceFileKind.directory => l10n.workspaceFilesKindDirectory,
    WorkspaceFileKind.unknown => l10n.workspaceFilesKindUnknown,
  };
}

String? _normalizedText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}

WorkspaceFileException? _unpreviewableStatError(WorkspaceFileStat stat) {
  if (stat.kind == WorkspaceFileKind.directory) {
    return const WorkspaceFileException(
      WorkspaceFileFailureCode.readFailed,
      'Workspace file request failed.',
      detail: 'Path is a directory.',
    );
  }
  if (stat.isSymlink) {
    return const WorkspaceFileException(
      WorkspaceFileFailureCode.pathOutsideRoot,
      'Workspace path is outside the workspace root.',
      detail: 'Symbolic links are not previewed.',
    );
  }
  if (stat.isBinary == true) {
    return const WorkspaceFileException(
      WorkspaceFileFailureCode.binaryNotPreviewable,
      'Binary files cannot be previewed as text.',
    );
  }
  return null;
}

_PreviewMode _initialPreviewMode(
  String path,
  WorkspaceFileStat stat,
  WorkspaceFileReadChunk chunk,
) {
  final markdown = _isMarkdownPath(path) || stat.language == 'markdown';
  if (markdown &&
      !chunk.hasMore &&
      chunk.sizeBytes <= _markdownRenderLimitBytes) {
    return _PreviewMode.render;
  }
  return _PreviewMode.raw;
}

bool _isMarkdownPath(String path) {
  final extension = _extension(path);
  return extension == 'md' || extension == 'markdown';
}

bool _isCodePath(String path) {
  return switch (_extension(path)) {
    'dart' ||
    'rs' ||
    'js' ||
    'ts' ||
    'jsx' ||
    'tsx' ||
    'py' ||
    'sh' ||
    'ps1' ||
    'json' ||
    'yaml' ||
    'yml' ||
    'toml' ||
    'html' ||
    'css' => true,
    _ => false,
  };
}

bool _isCodeLanguage(String? language) {
  return switch (language?.toLowerCase()) {
    'dart' ||
    'rust' ||
    'javascript' ||
    'typescript' ||
    'python' ||
    'shell' ||
    'powershell' ||
    'json' ||
    'yaml' ||
    'toml' ||
    'html' ||
    'css' => true,
    _ => false,
  };
}

String? _extension(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) {
    return null;
  }
  return name.substring(dot + 1).toLowerCase();
}

String _workspaceFailureMessage(AppLocalizations l10n, Object? error) {
  final exception = error is WorkspaceFileException
      ? error
      : normalizeWorkspaceFileException(
          error ?? StateError('Workspace file request failed.'),
        );
  return switch (exception.code) {
    WorkspaceFileFailureCode.notConnected => l10n.workspaceFilesNotConnected,
    WorkspaceFileFailureCode.noCwd => l10n.workspaceFilesNoCwd,
    WorkspaceFileFailureCode.notFound => l10n.workspaceFilesNotFound,
    WorkspaceFileFailureCode.permissionDenied =>
      l10n.workspaceFilesPermissionDenied,
    WorkspaceFileFailureCode.pathOutsideRoot =>
      l10n.workspaceFilesPathOutsideRoot,
    WorkspaceFileFailureCode.binaryNotPreviewable => l10n.workspaceFilesBinary,
    WorkspaceFileFailureCode.tooLarge => l10n.workspaceFilesTooLarge,
    WorkspaceFileFailureCode.readFailed => l10n.workspaceFilesReadFailed,
  };
}

enum _DirectoryStatus { idle, loading, loaded, failed }

class _DirectoryLoadState {
  const _DirectoryLoadState({
    this.status = _DirectoryStatus.idle,
    required this.entries,
    this.nextCursor,
    this.error,
  });

  final _DirectoryStatus status;
  final List<WorkspaceDirectoryEntry> entries;
  final String? nextCursor;
  final Object? error;

  _DirectoryLoadState copyWith({
    _DirectoryStatus? status,
    List<WorkspaceDirectoryEntry>? entries,
    String? nextCursor,
    Object? error,
  }) {
    return _DirectoryLoadState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      nextCursor: nextCursor ?? this.nextCursor,
      error: error,
    );
  }
}

enum _PreviewStatus { idle, loading, loaded, failed }

enum _PreviewMode { render, raw }

class _FilePreviewState {
  const _FilePreviewState._({
    required this.status,
    this.root,
    this.path,
    this.stat,
    this.content = '',
    this.sizeBytes = 0,
    this.bytesLoaded = 0,
    this.nextOffset,
    this.hasMore = false,
    this.mode = _PreviewMode.raw,
    this.error,
    this.loadingMore = false,
    this.loadMoreError,
  });

  const _FilePreviewState.idle() : this._(status: _PreviewStatus.idle);

  factory _FilePreviewState.loading({
    required String root,
    required String path,
  }) {
    return _FilePreviewState._(
      status: _PreviewStatus.loading,
      root: root,
      path: path,
    );
  }

  factory _FilePreviewState.loaded({
    required String root,
    required String path,
    required WorkspaceFileStat stat,
    required String content,
    required int sizeBytes,
    required int bytesLoaded,
    required int? nextOffset,
    required bool hasMore,
    required _PreviewMode mode,
  }) {
    return _FilePreviewState._(
      status: _PreviewStatus.loaded,
      root: root,
      path: path,
      stat: stat,
      content: content,
      sizeBytes: sizeBytes,
      bytesLoaded: bytesLoaded,
      nextOffset: nextOffset,
      hasMore: hasMore,
      mode: mode,
    );
  }

  factory _FilePreviewState.failed({
    required String root,
    required String path,
    required Object error,
    WorkspaceFileStat? stat,
  }) {
    return _FilePreviewState._(
      status: _PreviewStatus.failed,
      root: root,
      path: path,
      stat: stat,
      error: error,
    );
  }

  final _PreviewStatus status;
  final String? root;
  final String? path;
  final WorkspaceFileStat? stat;
  final String content;
  final int sizeBytes;
  final int bytesLoaded;
  final int? nextOffset;
  final bool hasMore;
  final _PreviewMode mode;
  final Object? error;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get isMarkdown =>
      _isMarkdownPath(path ?? '') || stat?.language == 'markdown';

  _FilePreviewState copyWith({
    String? content,
    int? sizeBytes,
    int? bytesLoaded,
    Object? nextOffset = _unchanged,
    bool? hasMore,
    _PreviewMode? mode,
    bool? loadingMore,
    Object? loadMoreError = _unchanged,
  }) {
    return _FilePreviewState._(
      status: status,
      root: root,
      path: path,
      stat: stat,
      content: content ?? this.content,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      bytesLoaded: bytesLoaded ?? this.bytesLoaded,
      nextOffset: identical(nextOffset, _unchanged)
          ? this.nextOffset
          : nextOffset as int?,
      hasMore: hasMore ?? this.hasMore,
      mode: mode ?? this.mode,
      error: error,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreError: identical(loadMoreError, _unchanged)
          ? this.loadMoreError
          : loadMoreError,
    );
  }
}
