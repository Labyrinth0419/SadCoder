import 'dart:convert';
import 'dart:math';

import '../protocol/codex_app_server_client.dart';
import 'workspace_file_failure.dart';
import 'workspace_file_kind.dart';
import 'workspace_file_reader.dart';
import 'workspace_path.dart';

class CodexWorkspaceFileReader implements WorkspaceFileReader {
  const CodexWorkspaceFileReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<WorkspaceFileStat> statFile({
    required String root,
    required String path,
  }) async {
    try {
      final workspacePath = WorkspacePath.fromRoot(root, path);
      final response = await _client.fsGetMetadata(
        path: workspacePath.absolutePath,
      );
      return _statFromMetadata(response, workspacePath);
    } catch (error) {
      throw normalizeWorkspaceFileException(error);
    }
  }

  @override
  Future<WorkspaceFileReadChunk> readFile({
    required String root,
    required String path,
    int offset = 0,
    int limitBytes = 64 * 1024,
    String encoding = 'utf-8',
  }) async {
    try {
      if (offset < 0) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.readFailed,
          'Workspace file request failed.',
          detail: 'Offset must be non-negative.',
        );
      }
      if (limitBytes <= 0) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.readFailed,
          'Workspace file request failed.',
          detail: 'Read limit must be positive.',
        );
      }
      final normalizedEncoding = _normalizeEncoding(encoding);
      final workspacePath = WorkspacePath.fromRoot(root, path);
      final metadata = await _client.fsGetMetadata(
        path: workspacePath.absolutePath,
      );
      final stat = _statFromMetadata(metadata, workspacePath);
      _ensurePreviewableFile(stat);

      final response = await _client.fsReadFile(
        path: workspacePath.absolutePath,
      );
      final dataBase64 = _stringValue(
        response['dataBase64'] ?? response['data_base64'],
      );
      if (dataBase64 == null) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.readFailed,
          'Workspace file request failed.',
          detail: 'Missing file content.',
        );
      }

      final bytes = _decodeBase64(dataBase64);
      if (_looksBinary(bytes)) {
        throw const WorkspaceFileException(
          WorkspaceFileFailureCode.binaryNotPreviewable,
          'Binary files cannot be previewed as text.',
        );
      }
      final slice = _sliceUtf8(bytes, offset: offset, limitBytes: limitBytes);
      return WorkspaceFileReadChunk(
        root: workspacePath.root,
        path: workspacePath.relativePath,
        sizeBytes: bytes.length,
        offset: slice.offset,
        bytesRead: slice.bytesRead,
        nextOffset: slice.nextOffset,
        hasMore: slice.hasMore,
        encoding: normalizedEncoding,
        isBinary: false,
        content: slice.content,
      );
    } catch (error) {
      throw normalizeWorkspaceFileException(error);
    }
  }

  WorkspaceFileStat _statFromMetadata(
    Map<String, Object?> response,
    WorkspacePath workspacePath,
  ) {
    final isSymlink = _boolValue(
      response['isSymlink'] ?? response['is_symlink'],
    );
    final kind = _kindFromMetadata(response);
    final stat = WorkspaceFileStat(
      root: workspacePath.root,
      path: workspacePath.relativePath,
      kind: kind,
      sizeBytes: _intValue(
        response['sizeBytes'] ?? response['size_bytes'] ?? response['size'],
      ),
      modifiedAt: _dateFromUnixMilliseconds(
        _intValue(response['modifiedAtMs'] ?? response['modified_at_ms']),
      ),
      isSymlink: isSymlink,
      isBinary: _optionalBool(response['isBinary'] ?? response['is_binary']),
      mimeType: _stringValue(response['mimeType'] ?? response['mime_type']),
      language:
          _stringValue(response['language']) ??
          _languageFromPath(workspacePath.relativePath),
      contentVersion: _stringValue(
        response['contentVersion'] ??
            response['content_version'] ??
            response['hash'] ??
            response['version'],
      ),
    );
    if (stat.isSymlink) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.pathOutsideRoot,
        'Workspace path is outside the workspace root.',
        detail: 'Symbolic links are not previewed.',
      );
    }
    return stat;
  }
}

WorkspaceFileKind _kindFromMetadata(Map<String, Object?> response) {
  if (response['isDirectory'] == true || response['is_directory'] == true) {
    return WorkspaceFileKind.directory;
  }
  if (response['isFile'] == true || response['is_file'] == true) {
    return WorkspaceFileKind.file;
  }
  return WorkspaceFileKind.unknown;
}

void _ensurePreviewableFile(WorkspaceFileStat stat) {
  if (stat.kind == WorkspaceFileKind.directory) {
    throw const WorkspaceFileException(
      WorkspaceFileFailureCode.readFailed,
      'Workspace file request failed.',
      detail: 'Path is a directory.',
    );
  }
  if (stat.kind != WorkspaceFileKind.file) {
    throw const WorkspaceFileException(
      WorkspaceFileFailureCode.notFound,
      'Workspace path was not found.',
    );
  }
  if (stat.isBinary == true) {
    throw const WorkspaceFileException(
      WorkspaceFileFailureCode.binaryNotPreviewable,
      'Binary files cannot be previewed as text.',
    );
  }
}

String _normalizeEncoding(String encoding) {
  final normalized = encoding.trim().toLowerCase().replaceAll('_', '-');
  if (normalized == 'utf-8' || normalized == 'utf8') {
    return 'utf-8';
  }
  throw WorkspaceFileException(
    WorkspaceFileFailureCode.readFailed,
    'Workspace file request failed.',
    detail: 'Unsupported encoding: $encoding.',
  );
}

List<int> _decodeBase64(String dataBase64) {
  try {
    return base64.decode(dataBase64);
  } on FormatException catch (error) {
    throw WorkspaceFileException(
      WorkspaceFileFailureCode.readFailed,
      'Workspace file request failed.',
      detail: error,
    );
  }
}

bool _looksBinary(List<int> bytes) {
  if (bytes.isEmpty) {
    return false;
  }
  final sampleLength = min(bytes.length, 8000);
  var suspicious = 0;
  for (var index = 0; index < sampleLength; index++) {
    final byte = bytes[index];
    if (byte == 0) {
      return true;
    }
    final allowedControl =
        byte == 7 ||
        byte == 8 ||
        byte == 9 ||
        byte == 10 ||
        byte == 12 ||
        byte == 13 ||
        byte == 27;
    if (byte < 32 && !allowedControl) {
      suspicious++;
    }
  }
  return suspicious / sampleLength > 0.3;
}

_Utf8Slice _sliceUtf8(
  List<int> bytes, {
  required int offset,
  required int limitBytes,
}) {
  final sizeBytes = bytes.length;
  var start = offset.clamp(0, sizeBytes);
  while (start < sizeBytes && _isUtf8ContinuationByte(bytes[start])) {
    start++;
  }
  if (start == sizeBytes) {
    return _Utf8Slice(
      offset: start,
      bytesRead: 0,
      nextOffset: null,
      hasMore: false,
      content: '',
    );
  }

  final requestedEnd = min(sizeBytes, start + limitBytes);
  for (var candidateEnd = requestedEnd; candidateEnd > start; candidateEnd--) {
    final content = _tryDecodeUtf8(bytes, start, candidateEnd);
    if (content != null) {
      return _Utf8Slice(
        offset: start,
        bytesRead: candidateEnd - start,
        nextOffset: candidateEnd < sizeBytes ? candidateEnd : null,
        hasMore: candidateEnd < sizeBytes,
        content: content,
      );
    }
  }

  final extendedEnd = min(sizeBytes, start + 4);
  for (
    var candidateEnd = requestedEnd + 1;
    candidateEnd <= extendedEnd;
    candidateEnd++
  ) {
    final content = _tryDecodeUtf8(bytes, start, candidateEnd);
    if (content != null) {
      return _Utf8Slice(
        offset: start,
        bytesRead: candidateEnd - start,
        nextOffset: candidateEnd < sizeBytes ? candidateEnd : null,
        hasMore: candidateEnd < sizeBytes,
        content: content,
      );
    }
  }

  throw const WorkspaceFileException(
    WorkspaceFileFailureCode.binaryNotPreviewable,
    'Binary files cannot be previewed as text.',
    detail: 'File content is not valid UTF-8.',
  );
}

String? _tryDecodeUtf8(List<int> bytes, int start, int end) {
  try {
    return utf8.decode(bytes.sublist(start, end), allowMalformed: false);
  } on FormatException {
    return null;
  }
}

bool _isUtf8ContinuationByte(int byte) => byte >= 0x80 && byte <= 0xbf;

DateTime? _dateFromUnixMilliseconds(int? value) {
  if (value == null || value <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
}

String? _languageFromPath(String path) {
  final fileName = path.split('/').last;
  final dotIndex = fileName.lastIndexOf('.');
  final extension = dotIndex == -1 || dotIndex == fileName.length - 1
      ? null
      : fileName.substring(dotIndex + 1);
  return switch (extension?.toLowerCase()) {
    'dart' => 'dart',
    'rs' => 'rust',
    'md' || 'markdown' => 'markdown',
    'txt' => 'text',
    'json' => 'json',
    'yaml' || 'yml' => 'yaml',
    'toml' => 'toml',
    'js' => 'javascript',
    'ts' => 'typescript',
    'jsx' => 'javascriptreact',
    'tsx' => 'typescriptreact',
    'html' => 'html',
    'css' => 'css',
    'sh' || 'bash' => 'shell',
    'ps1' => 'powershell',
    'py' => 'python',
    _ => null,
  };
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

bool _boolValue(Object? value) => value == true;

bool? _optionalBool(Object? value) => value is bool ? value : null;

class _Utf8Slice {
  const _Utf8Slice({
    required this.offset,
    required this.bytesRead,
    required this.nextOffset,
    required this.hasMore,
    required this.content,
  });

  final int offset;
  final int bytesRead;
  final int? nextOffset;
  final bool hasMore;
  final String content;
}
