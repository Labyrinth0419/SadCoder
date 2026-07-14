import 'dart:async';
import 'dart:convert';

import '../events/codex_event.dart';
import '../protocol/codex_app_server_client.dart';
import 'codex_workspace_path_guard.dart';
import 'workspace_file_failure.dart';
import 'workspace_file_kind.dart';
import 'workspace_file_reader.dart';
import 'workspace_path.dart';

class WorkspaceFileWriteResult {
  const WorkspaceFileWriteResult({
    required this.root,
    required this.path,
    required this.contentVersion,
    required this.stat,
  });

  final String root;
  final String path;
  final String? contentVersion;
  final WorkspaceFileStat stat;
}

class WorkspaceFileConflictException implements Exception {
  const WorkspaceFileConflictException({
    required this.path,
    required this.expectedContentVersion,
    required this.actualContentVersion,
  });

  final String path;
  final String? expectedContentVersion;
  final String? actualContentVersion;

  @override
  String toString() {
    return 'Workspace file changed since it was opened: $path';
  }
}

class WorkspaceFileMovePartialFailureException implements Exception {
  const WorkspaceFileMovePartialFailureException({
    required this.sourcePath,
    required this.destinationPath,
    required this.cause,
  });

  final String sourcePath;
  final String destinationPath;
  final Object cause;

  @override
  String toString() {
    return 'Workspace copy completed but removing the source failed: '
        '$sourcePath -> $destinationPath ($cause)';
  }
}

class WorkspaceFileChangedEvent {
  const WorkspaceFileChangedEvent({
    required this.watchId,
    required this.changedPaths,
  });

  final String watchId;
  final List<String> changedPaths;
}

abstract interface class WorkspaceFileWatch {
  String get watchId;

  String get root;

  String get path;

  Stream<WorkspaceFileChangedEvent> get events;

  Future<void> close();
}

abstract interface class WorkspaceFileMutationRunner {
  Future<WorkspaceFileWriteResult> createFile({
    required String root,
    required String path,
    String content = '',
  });

  Future<void> createDirectory({required String root, required String path});

  Future<void> remove({required String root, required String path});

  Future<void> copy({
    required String root,
    required String sourcePath,
    required String destinationPath,
  });

  Future<void> move({
    required String root,
    required String sourcePath,
    required String destinationPath,
  });

  Future<WorkspaceFileWriteResult> writeText({
    required String root,
    required String path,
    required String content,
    required String expectedContent,
    String? expectedContentVersion,
  });

  Future<WorkspaceFileWatch> watch({
    required String root,
    required String path,
  });

  Future<void> close();
}

class CodexWorkspaceFileMutationRunner implements WorkspaceFileMutationRunner {
  CodexWorkspaceFileMutationRunner({
    required CodexAppServerClient client,
    required WorkspaceFileReader fileReader,
    required Stream<CodexEvent> events,
    this.maxEditableBytes = 4 * 1024 * 1024,
  }) : _client = client,
       _fileReader = fileReader,
       _eventSubscription = events
           .where((event) => event.kind == CodexEventKind.fsChanged)
           .listen(null) {
    _eventSubscription
      ..onData(_handleFileChanged)
      ..onError((Object error, StackTrace stackTrace) {});
  }

  final CodexAppServerClient _client;
  final WorkspaceFileReader _fileReader;
  final int maxEditableBytes;
  final StreamSubscription<CodexEvent> _eventSubscription;
  final Map<String, _CodexWorkspaceFileWatch> _watches = {};
  int _nextWatchId = 0;
  bool _closed = false;

  @override
  Future<WorkspaceFileWriteResult> createFile({
    required String root,
    required String path,
    String content = '',
  }) async {
    if (_closed) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.notConnected,
        'Workspace is not connected.',
      );
    }
    try {
      final workspacePath = await _prepareNewTarget(root, path);
      await _client.fsWriteFile(
        path: workspacePath.absolutePath,
        dataBase64: base64Encode(utf8.encode(content)),
      );
      final stat = await _fileReader.statFile(
        root: workspacePath.root,
        path: workspacePath.relativePath,
      );
      if (stat.kind != WorkspaceFileKind.file || stat.isSymlink) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.readFailed,
          'Created path is not a regular file.',
        );
      }
      return WorkspaceFileWriteResult(
        root: workspacePath.root,
        path: workspacePath.relativePath,
        contentVersion: stat.contentVersion,
        stat: stat,
      );
    } on WorkspaceFileException {
      rethrow;
    } on Object catch (error) {
      throw normalizeWorkspaceFileException(error);
    }
  }

  @override
  Future<void> createDirectory({
    required String root,
    required String path,
  }) async {
    if (_closed) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.notConnected,
        'Workspace is not connected.',
      );
    }
    try {
      final workspacePath = await _prepareNewTarget(root, path);
      await _client.fsCreateDirectory(
        path: workspacePath.absolutePath,
        recursive: false,
      );
    } on WorkspaceFileException {
      rethrow;
    } on Object catch (error) {
      throw normalizeWorkspaceFileException(error);
    }
  }

  @override
  Future<void> remove({required String root, required String path}) async {
    if (_closed) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.notConnected,
        'Workspace is not connected.',
      );
    }
    try {
      final workspacePath = await _prepareExistingTarget(root, path);
      final stat = await _fileReader.statFile(
        root: workspacePath.root,
        path: workspacePath.relativePath,
      );
      if (stat.isSymlink) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.pathOutsideRoot,
          'Workspace path is outside the workspace root.',
          detail: 'Symbolic links are not removed.',
        );
      }
      await _client.fsRemove(
        path: workspacePath.absolutePath,
        recursive: stat.kind == WorkspaceFileKind.directory,
        force: false,
      );
    } on WorkspaceFileException {
      rethrow;
    } on Object catch (error) {
      throw normalizeWorkspaceFileException(error);
    }
  }

  @override
  Future<void> copy({
    required String root,
    required String sourcePath,
    required String destinationPath,
  }) async {
    if (_closed) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.notConnected,
        'Workspace is not connected.',
      );
    }
    try {
      final source = await _prepareExistingTarget(root, sourcePath);
      final destination = await _prepareNewTarget(root, destinationPath);
      final sourceStat = await _fileReader.statFile(
        root: source.root,
        path: source.relativePath,
      );
      if (sourceStat.isSymlink) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.pathOutsideRoot,
          'Workspace path is outside the workspace root.',
          detail: 'Symbolic links are not copied.',
        );
      }
      await _client.fsCopy(
        sourcePath: source.absolutePath,
        destinationPath: destination.absolutePath,
        recursive: sourceStat.kind == WorkspaceFileKind.directory,
      );
    } on WorkspaceFileException {
      rethrow;
    } on Object catch (error) {
      throw normalizeWorkspaceFileException(error);
    }
  }

  @override
  Future<void> move({
    required String root,
    required String sourcePath,
    required String destinationPath,
  }) async {
    final source = WorkspacePath.fromRoot(root, sourcePath);
    final destination = WorkspacePath.fromRoot(root, destinationPath);
    if (source.relativePath == destination.relativePath) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.readFailed,
        'Source and destination must be different.',
      );
    }
    await copy(
      root: root,
      sourcePath: source.relativePath,
      destinationPath: destination.relativePath,
    );
    try {
      await remove(root: root, path: source.relativePath);
    } on Object catch (error) {
      throw WorkspaceFileMovePartialFailureException(
        sourcePath: source.relativePath,
        destinationPath: destination.relativePath,
        cause: error,
      );
    }
  }

  @override
  Future<WorkspaceFileWriteResult> writeText({
    required String root,
    required String path,
    required String content,
    required String expectedContent,
    String? expectedContentVersion,
  }) async {
    if (_closed) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.notConnected,
        'Workspace is not connected.',
      );
    }
    try {
      final workspacePath = WorkspacePath.fromRoot(root, path);
      if (workspacePath.relativePath.isEmpty) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.readFailed,
          'A file path is required.',
        );
      }
      await rejectSymlinkAncestors(
        _client,
        workspacePath,
        detail: 'Symbolic link ancestors are not edited.',
      );
      final currentStat = await _fileReader.statFile(
        root: workspacePath.root,
        path: workspacePath.relativePath,
      );
      if (currentStat.kind != WorkspaceFileKind.file ||
          currentStat.isSymlink ||
          currentStat.isBinary == true) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.binaryNotPreviewable,
          'Only text files can be edited.',
        );
      }

      final normalizedExpectedVersion = expectedContentVersion?.trim();
      if (normalizedExpectedVersion != null &&
          normalizedExpectedVersion.isNotEmpty &&
          currentStat.contentVersion != null) {
        if (currentStat.contentVersion != normalizedExpectedVersion) {
          throw WorkspaceFileConflictException(
            path: workspacePath.relativePath,
            expectedContentVersion: normalizedExpectedVersion,
            actualContentVersion: currentStat.contentVersion,
          );
        }
      } else {
        final currentContent = await _readText(workspacePath);
        if (currentContent != expectedContent) {
          throw WorkspaceFileConflictException(
            path: workspacePath.relativePath,
            expectedContentVersion: normalizedExpectedVersion,
            actualContentVersion: currentStat.contentVersion,
          );
        }
      }

      await _client.fsWriteFile(
        path: workspacePath.absolutePath,
        dataBase64: base64Encode(utf8.encode(content)),
      );
      final updatedStat = await _fileReader.statFile(
        root: workspacePath.root,
        path: workspacePath.relativePath,
      );
      return WorkspaceFileWriteResult(
        root: workspacePath.root,
        path: workspacePath.relativePath,
        contentVersion: updatedStat.contentVersion,
        stat: updatedStat,
      );
    } on WorkspaceFileConflictException {
      rethrow;
    } on WorkspaceFileException {
      rethrow;
    } on Object catch (error) {
      throw normalizeWorkspaceFileException(error);
    }
  }

  @override
  Future<WorkspaceFileWatch> watch({
    required String root,
    required String path,
  }) async {
    if (_closed) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.notConnected,
        'Workspace is not connected.',
      );
    }
    try {
      final workspacePath = WorkspacePath.fromRoot(root, path);
      await rejectSymlinkAncestors(
        _client,
        workspacePath,
        detail: 'Symbolic link ancestors are not watched.',
      );
      final stat = await _fileReader.statFile(
        root: workspacePath.root,
        path: workspacePath.relativePath,
      );
      if (stat.isSymlink) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.pathOutsideRoot,
          'Workspace path is outside the workspace root.',
          detail: 'Symbolic links are not watched.',
        );
      }
      final watchId = 'sadcoder-watch-${++_nextWatchId}';
      await _client.fsWatch(watchId: watchId, path: workspacePath.absolutePath);
      final handle = _CodexWorkspaceFileWatch(
        owner: this,
        watchId: watchId,
        root: workspacePath.root,
        path: workspacePath.relativePath,
      );
      _watches[watchId] = handle;
      return handle;
    } on WorkspaceFileException {
      rethrow;
    } on Object catch (error) {
      throw normalizeWorkspaceFileException(error);
    }
  }

  Future<String> _readText(WorkspacePath workspacePath) async {
    final buffer = StringBuffer();
    var offset = 0;
    var totalBytes = 0;
    while (true) {
      final chunk = await _fileReader.readFile(
        root: workspacePath.root,
        path: workspacePath.relativePath,
        offset: offset,
        limitBytes: 64 * 1024,
      );
      if (chunk.isBinary) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.binaryNotPreviewable,
          'Only text files can be edited.',
        );
      }
      totalBytes += chunk.bytesRead;
      if (totalBytes > maxEditableBytes) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.tooLarge,
          'Workspace file is too large to edit.',
        );
      }
      buffer.write(chunk.content);
      if (!chunk.hasMore) {
        return buffer.toString();
      }
      final nextOffset = chunk.nextOffset ?? offset + chunk.bytesRead;
      if (nextOffset <= offset) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.readFailed,
          'Workspace file range did not advance.',
        );
      }
      offset = nextOffset;
    }
  }

  Future<WorkspacePath> _prepareExistingTarget(String root, String path) async {
    final workspacePath = WorkspacePath.fromRoot(root, path);
    if (workspacePath.relativePath.isEmpty) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.readFailed,
        'The workspace root cannot be mutated by this operation.',
      );
    }
    await rejectSymlinkAncestors(
      _client,
      workspacePath,
      detail: 'Symbolic link ancestors are not mutated.',
    );
    return workspacePath;
  }

  Future<WorkspacePath> _prepareNewTarget(String root, String path) async {
    final workspacePath = await _prepareExistingTarget(root, path);
    try {
      await _fileReader.statFile(
        root: workspacePath.root,
        path: workspacePath.relativePath,
      );
    } on WorkspaceFileException catch (error) {
      if (error.code == WorkspaceFileFailureCode.notFound) {
        return workspacePath;
      }
      rethrow;
    }
    throw WorkspaceFileException(
      WorkspaceFileFailureCode.readFailed,
      'Workspace path already exists.',
      detail: workspacePath.relativePath,
    );
  }

  void _handleFileChanged(CodexEvent event) {
    final payload = event.payload ?? const <String, Object?>{};
    final watchId = _stringValue(payload['watchId'] ?? payload['watch_id']);
    if (watchId == null) {
      return;
    }
    final handle = _watches[watchId];
    if (handle == null) {
      return;
    }
    final paths = payload['changedPaths'] ?? payload['changed_paths'];
    final changedPaths = paths is List
        ? paths.whereType<String>().toList(growable: false)
        : const <String>[];
    handle.add(
      WorkspaceFileChangedEvent(watchId: watchId, changedPaths: changedPaths),
    );
  }

  Future<void> _closeWatch(_CodexWorkspaceFileWatch handle) async {
    if (!identical(_watches[handle.watchId], handle)) {
      return;
    }
    _watches.remove(handle.watchId);
    try {
      await _client.fsUnwatch(watchId: handle.watchId);
    } finally {
      await handle.dispose();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    final handles = _watches.values.toList(growable: false);
    _watches.clear();
    for (final handle in handles) {
      try {
        await _client.fsUnwatch(watchId: handle.watchId);
      } catch (_) {
        // The transport may already be closed.
      }
      await handle.dispose();
    }
    await _eventSubscription.cancel();
  }
}

class _CodexWorkspaceFileWatch implements WorkspaceFileWatch {
  _CodexWorkspaceFileWatch({
    required this.owner,
    required this.watchId,
    required this.root,
    required this.path,
  });

  final CodexWorkspaceFileMutationRunner owner;
  @override
  final String watchId;
  @override
  final String root;
  @override
  final String path;
  final StreamController<WorkspaceFileChangedEvent> _eventsController =
      StreamController.broadcast();
  bool _closed = false;

  @override
  Stream<WorkspaceFileChangedEvent> get events => _eventsController.stream;

  void add(WorkspaceFileChangedEvent event) {
    if (!_closed) {
      _eventsController.add(event);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    await owner._closeWatch(this);
  }

  Future<void> dispose() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _eventsController.close();
  }
}

String? _stringValue(Object? value) => value is String ? value : null;
