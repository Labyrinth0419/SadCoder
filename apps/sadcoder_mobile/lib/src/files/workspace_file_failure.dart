import '../protocol/json_rpc.dart';

enum WorkspaceFileFailureCode {
  notConnected,
  noCwd,
  notFound,
  permissionDenied,
  pathOutsideRoot,
  binaryNotPreviewable,
  tooLarge,
  readFailed,
}

class WorkspaceFileException implements Exception {
  const WorkspaceFileException(this.code, this.message, {this.detail});

  final WorkspaceFileFailureCode code;
  final String message;
  final Object? detail;

  @override
  String toString() {
    final rawDetail = detail;
    if (rawDetail == null) {
      return message;
    }
    return '$message: $rawDetail';
  }
}

WorkspaceFileException normalizeWorkspaceFileException(
  Object error, {
  WorkspaceFileFailureCode fallbackCode = WorkspaceFileFailureCode.readFailed,
}) {
  if (error is WorkspaceFileException) {
    return error;
  }
  if (error is JsonRpcRemoteException) {
    final code =
        _codeFromJsonRpcErrorCode(error.code) ??
        _codeFromMessage(error.message.toLowerCase()) ??
        fallbackCode;
    return WorkspaceFileException(
      code,
      _messageForCode(code),
      detail: error.data ?? error.message,
    );
  }

  final rawMessage = error.toString();
  final message = rawMessage.toLowerCase();
  final code = _codeFromMessage(message) ?? fallbackCode;
  return WorkspaceFileException(
    code,
    _messageForCode(code),
    detail: rawMessage,
  );
}

WorkspaceFileFailureCode? _codeFromMessage(String message) {
  if (message.contains('not connected') ||
      message.contains('stream closed') ||
      message.contains('connection closed')) {
    return WorkspaceFileFailureCode.notConnected;
  }
  if (message.contains('no cwd') ||
      message.contains('workspace root is not available') ||
      message.contains('workspace root must be an absolute path')) {
    return WorkspaceFileFailureCode.noCwd;
  }
  if (message.contains('no such file') ||
      message.contains('not found') ||
      message.contains('enoent')) {
    return WorkspaceFileFailureCode.notFound;
  }
  if (message.contains('permission denied') ||
      message.contains('access is denied') ||
      message.contains('eacces') ||
      message.contains('eperm')) {
    return WorkspaceFileFailureCode.permissionDenied;
  }
  if (message.contains('outside') ||
      message.contains('traversal') ||
      message.contains('escape')) {
    return WorkspaceFileFailureCode.pathOutsideRoot;
  }
  if (message.contains('binary')) {
    return WorkspaceFileFailureCode.binaryNotPreviewable;
  }
  if (message.contains('too large')) {
    return WorkspaceFileFailureCode.tooLarge;
  }
  return null;
}

WorkspaceFileFailureCode? _codeFromJsonRpcErrorCode(int? code) =>
    switch (code) {
      -32020 => WorkspaceFileFailureCode.noCwd,
      -32021 => WorkspaceFileFailureCode.notFound,
      -32022 => WorkspaceFileFailureCode.permissionDenied,
      -32023 => WorkspaceFileFailureCode.pathOutsideRoot,
      -32024 => WorkspaceFileFailureCode.binaryNotPreviewable,
      -32025 => WorkspaceFileFailureCode.readFailed,
      -32026 => WorkspaceFileFailureCode.tooLarge,
      _ => null,
    };

String _messageForCode(WorkspaceFileFailureCode code) => switch (code) {
  WorkspaceFileFailureCode.notConnected => 'Workspace is not connected.',
  WorkspaceFileFailureCode.noCwd => 'Workspace root is not available.',
  WorkspaceFileFailureCode.notFound => 'Workspace path was not found.',
  WorkspaceFileFailureCode.permissionDenied =>
    'Workspace path cannot be read because permission was denied.',
  WorkspaceFileFailureCode.pathOutsideRoot =>
    'Workspace path is outside the workspace root.',
  WorkspaceFileFailureCode.binaryNotPreviewable =>
    'Binary files cannot be previewed as text.',
  WorkspaceFileFailureCode.tooLarge =>
    'Workspace file is too large to preview.',
  WorkspaceFileFailureCode.readFailed => 'Workspace file request failed.',
};
