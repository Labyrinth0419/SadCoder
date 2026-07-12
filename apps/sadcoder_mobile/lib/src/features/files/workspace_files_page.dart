import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/codex_config_override_controller.dart';
import '../../config/codex_config_overrides.dart';
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
import 'workspace_markdown_preview.dart';
import 'workspace_syntax_highlighter.dart';

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
  final TextEditingController _rootController = TextEditingController();
  final Map<String, _DirectoryLoadState> _directories = {};
  final Map<String, int> _directoryRequestIds = {};
  final Set<String> _expandedDirectories = {''};
  int _nextDirectoryRequestId = 0;
  int _nextFileRequestId = 0;
  String _filter = '';
  String? _manualRoot;
  String? _activeRoot;
  bool _includeHidden = false;
  bool? _fileSidebarOverride;
  _FilePreviewState _preview = const _FilePreviewState.idle();

  @override
  void initState() {
    super.initState();
    _filterController.addListener(_handleFilterChanged);
    _attachListeners();
    _activeRoot = _resolvedRoot();
    _setRootControllerText(_activeRoot ?? '');
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
    _rootController.dispose();
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final overlaySidebar = constraints.maxWidth < 720;
        final sidebarVisible = _fileSidebarOverride ?? !overlaySidebar;
        final sidebarWidth = _filesSidebarWidthFor(constraints.maxWidth);
        return Column(
          key: const ValueKey('workspace-files-page'),
          children: [
            _FilesTopBar(
              root: root,
              sidebarVisible: sidebarVisible,
              onToggleSidebar: () => _toggleFileSidebar(sidebarVisible),
            ),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    left: sidebarVisible && !overlaySidebar ? sidebarWidth : 0,
                    child: ListView(
                      key: const ValueKey('workspace-files-main'),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                      children: [
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
                        else
                          _PreviewPanel(
                            preview: _preview,
                            onModeChanged: _setPreviewMode,
                            onLoadMore: _loadMorePreview,
                            errorText: _preview.error == null
                                ? null
                                : _workspaceFailureMessage(
                                    l10n,
                                    _preview.error!,
                                  ),
                          ),
                      ],
                    ),
                  ),
                  if (sidebarVisible)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: sidebarWidth,
                      child: _FilesSidebar(
                        overlay: overlaySidebar,
                        root: root,
                        rootController: _rootController,
                        canSaveDefaultRoot:
                            widget.configOverrideController != null,
                        onUseRoot: _setWorkspaceRoot,
                        onUseDefaultRoot: _useDefaultWorkspaceRoot,
                        onSaveDefaultRoot: _saveDefaultWorkspaceRoot,
                        toolbar: directoryReader == null || fileReader == null
                            ? null
                            : _FilesToolbar(
                                filterController: _filterController,
                                includeHidden: _includeHidden,
                                onIncludeHiddenChanged: _setIncludeHidden,
                                onSearch: _fileSearchReader == null
                                    ? null
                                    : _searchWorkspace,
                                onRefresh: _refreshWorkspace,
                              ),
                        directory:
                            root == null ||
                                directoryReader == null ||
                                fileReader == null
                            ? null
                            : _DirectoryPanel(
                                root: root,
                                rows: _directoryRows(
                                  l10n,
                                  root: root,
                                  path: '',
                                  depth: 0,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
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
    final manualRoot = _normalizedText(_manualRoot);
    if (manualRoot != null) {
      return manualRoot;
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
      _setRootControllerText(nextRoot ?? '');
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

  void _toggleFileSidebar(bool currentlyVisible) {
    setState(() => _fileSidebarOverride = !currentlyVisible);
  }

  void _setWorkspaceRoot() {
    final nextRoot = _normalizedText(_rootController.text);
    if (nextRoot == _manualRoot) {
      return;
    }
    _manualRoot = nextRoot;
    _handleSourcesChanged(forceReload: true);
  }

  void _useDefaultWorkspaceRoot() {
    if (_manualRoot == null) {
      _setRootControllerText(_resolvedRoot() ?? '');
      return;
    }
    _manualRoot = null;
    _handleSourcesChanged(forceReload: true);
  }

  void _saveDefaultWorkspaceRoot() {
    final nextRoot = _normalizedText(_rootController.text);
    final controller = widget.configOverrideController;
    if (nextRoot == null || controller == null) {
      return;
    }
    _manualRoot = null;
    controller.setAppDefault(
      _copyOverridesWithCwd(controller.layers.appDefault, nextRoot),
    );
  }

  void _setRootControllerText(String value) {
    if (_rootController.text == value) {
      return;
    }
    _rootController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
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
    if (mode == _PreviewMode.render && !_canRenderMarkdown(_preview)) {
      return;
    }
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
          entryKey: ValueKey('workspace-files-entry-${entry.path}'),
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

double _filesSidebarWidthFor(double maxWidth) {
  if (maxWidth <= 320) {
    return maxWidth;
  }
  if (maxWidth < 720) {
    return maxWidth * 0.88;
  }
  return 340;
}

CodexConfigOverrides _copyOverridesWithCwd(
  CodexConfigOverrides overrides,
  String cwd,
) {
  return CodexConfigOverrides(
    model: overrides.model,
    effort: overrides.effort,
    summary: overrides.summary,
    approvalPolicy: overrides.approvalPolicy,
    sandboxPolicy: overrides.sandboxPolicy,
    permissionProfile: overrides.permissionProfile,
    cwd: cwd,
    personality: overrides.personality,
    serviceTier: overrides.serviceTier,
    collaborationMode: overrides.collaborationMode,
  );
}

class _FilesTopBar extends StatelessWidget {
  const _FilesTopBar({
    required this.root,
    required this.sidebarVisible,
    required this.onToggleSidebar,
  });

  final String? root;
  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('workspace-files-sidebar-toggle'),
              tooltip: l10n.workspaceFilesSidebar,
              onPressed: onToggleSidebar,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size.square(36),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.menu),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.folder_copy_outlined,
              size: 19,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.workspaceFilesTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (root != null)
                    Text(
                      l10n.workspaceFilesRoot(root!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilesSidebar extends StatelessWidget {
  const _FilesSidebar({
    required this.overlay,
    required this.root,
    required this.rootController,
    required this.canSaveDefaultRoot,
    required this.onUseRoot,
    required this.onUseDefaultRoot,
    required this.onSaveDefaultRoot,
    required this.toolbar,
    required this.directory,
  });

  final bool overlay;
  final String? root;
  final TextEditingController rootController;
  final bool canSaveDefaultRoot;
  final VoidCallback onUseRoot;
  final VoidCallback onUseDefaultRoot;
  final VoidCallback onSaveDefaultRoot;
  final Widget? toolbar;
  final Widget? directory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: overlay ? 8 : 0,
      color: colorScheme.surfaceContainerLowest,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            end: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: ListView(
          key: const ValueKey('workspace-files-sidebar'),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          children: [
            _WorkspaceRootSelector(
              controller: rootController,
              canSaveDefaultRoot: canSaveDefaultRoot,
              onUseRoot: onUseRoot,
              onUseDefaultRoot: onUseDefaultRoot,
              onSaveDefaultRoot: onSaveDefaultRoot,
            ),
            if (toolbar != null) ...[const SizedBox(height: 8), toolbar!],
            if (directory != null) ...[const SizedBox(height: 10), directory!],
          ],
        ),
      ),
    );
  }
}

class _WorkspaceRootSelector extends StatelessWidget {
  const _WorkspaceRootSelector({
    required this.controller,
    required this.canSaveDefaultRoot,
    required this.onUseRoot,
    required this.onUseDefaultRoot,
    required this.onSaveDefaultRoot,
  });

  final TextEditingController controller;
  final bool canSaveDefaultRoot;
  final VoidCallback onUseRoot;
  final VoidCallback onUseDefaultRoot;
  final VoidCallback onSaveDefaultRoot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const ValueKey('workspace-files-root-selector'),
          initiallyExpanded: false,
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: const Icon(Icons.workspaces_outline, size: 20),
          title: Text(
            l10n.workspaceFilesRootLabel,
            style: theme.textTheme.titleSmall,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          children: [
            SizedBox(
              height: 36,
              child: TextField(
                key: const ValueKey('workspace-files-root-field'),
                controller: controller,
                onSubmitted: (_) => onUseRoot(),
                minLines: 1,
                maxLines: 1,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: l10n.workspaceFilesRootLabel,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('workspace-files-use-root'),
                    onPressed: onUseRoot,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(
                      l10n.workspaceFilesUseRoot,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  key: const ValueKey('workspace-files-use-default-root'),
                  onPressed: onUseDefaultRoot,
                  tooltip: l10n.workspaceFilesUseDefaultRoot,
                  icon: const Icon(Icons.restore),
                ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  key: const ValueKey('workspace-files-save-default-root'),
                  onPressed: canSaveDefaultRoot ? onSaveDefaultRoot : null,
                  tooltip: l10n.workspaceFilesSaveDefaultRoot,
                  icon: const Icon(Icons.push_pin_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final searchWidth = constraints.maxWidth < 260
            ? constraints.maxWidth
            : 112.0;
        return Row(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: searchWidth),
                child: SizedBox(
                  height: 22,
                  child: TextField(
                    key: const ValueKey('workspace-files-filter'),
                    controller: filterController,
                    textAlignVertical: TextAlignVertical.center,
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 13),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      hintText: l10n.workspaceFilesSearchHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _CompactFilesToolButton(
              key: const ValueKey('workspace-files-hidden-toggle'),
              onPressed: () => onIncludeHiddenChanged(!includeHidden),
              tooltip: l10n.workspaceFilesShowHidden,
              selected: includeHidden,
              selectedColor: colorScheme.secondaryContainer,
              selectedForeground: colorScheme.onSecondaryContainer,
              icon: includeHidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            _CompactFilesToolButton(
              key: const ValueKey('workspace-files-remote-search'),
              onPressed: onSearch,
              tooltip: l10n.mentionSearchHint,
              icon: Icons.manage_search,
            ),
            _CompactFilesToolButton(
              key: const ValueKey('workspace-files-refresh'),
              onPressed: onRefresh,
              tooltip: l10n.workspaceFilesRefresh,
              icon: Icons.refresh,
            ),
          ],
        );
      },
    );
  }
}

class _CompactFilesToolButton extends StatelessWidget {
  const _CompactFilesToolButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    required this.icon,
    this.selected = false,
    this.selectedColor,
    this.selectedForeground,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;
  final bool selected;
  final Color? selectedColor;
  final Color? selectedForeground;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 24,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? selectedColor
              : colorScheme.surfaceContainerHighest,
          foregroundColor: selected
              ? selectedForeground
              : colorScheme.onSurfaceVariant,
        ),
        icon: Icon(icon, size: 16),
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      root,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _WorkspaceEntryRow extends StatelessWidget {
  const _WorkspaceEntryRow({
    required this.entryKey,
    required this.entry,
    required this.displayPath,
    required this.depth,
    required this.expanded,
    required this.selected,
    required this.onTap,
    required this.onCopy,
  });

  final Key entryKey;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    return Material(
      key: entryKey,
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.52)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: 8.0 + depth * 18,
            end: 2,
            top: 4,
            bottom: 4,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: Icon(
                  isDirectory
                      ? expanded
                            ? Icons.expand_more
                            : Icons.chevron_right
                      : Icons.chevron_right,
                  size: 17,
                  color: isDirectory
                      ? colorScheme.onSurfaceVariant
                      : Colors.transparent,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                entry.isSymlink
                    ? Icons.link
                    : isDirectory
                    ? expanded
                          ? Icons.folder_open
                          : Icons.folder_outlined
                    : _fileIcon(entry.path),
                size: 18,
                color: selected ? colorScheme.primary : colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      details.join(' | '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: 30,
                child: IconButton(
                  onPressed: onCopy,
                  tooltip: l10n.workspaceFilesCopyPath,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const ValueKey('workspace-files-status-page'),
      color: colorScheme.surfaceContainerLowest,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 320),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 10.0 + depth * 18,
        end: 8,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
      dense: true,
      visualDensity: VisualDensity.compact,
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

bool _canRenderMarkdown(_FilePreviewState preview) {
  return preview.isMarkdown &&
      !preview.hasMore &&
      preview.sizeBytes <= _markdownRenderLimitBytes;
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
