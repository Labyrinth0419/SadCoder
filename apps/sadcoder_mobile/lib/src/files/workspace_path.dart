import 'workspace_file_failure.dart';

class WorkspacePath {
  const WorkspacePath._({
    required this.root,
    required this.relativePath,
    required this.absolutePath,
  });

  factory WorkspacePath.fromRoot(String root, [String path = '']) {
    final normalizedRoot = _normalizeRoot(root);
    final normalizedPath = _normalizeRelativePath(path);
    return WorkspacePath._(
      root: normalizedRoot,
      relativePath: normalizedPath,
      absolutePath: _joinAbsolutePath(normalizedRoot, normalizedPath),
    );
  }

  final String root;
  final String relativePath;
  final String absolutePath;

  WorkspacePath child(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty ||
        trimmedName == '.' ||
        trimmedName == '..' ||
        name.contains('/') ||
        name.contains(r'\') ||
        name.contains('\u0000')) {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.pathOutsideRoot,
        'Workspace path is outside the workspace root.',
      );
    }
    final childPath = relativePath.isEmpty ? name : '$relativePath/$name';
    return WorkspacePath.fromRoot(root, childPath);
  }

  static bool isHiddenName(String name) => name.startsWith('.');
}

String _normalizeRoot(String root) {
  var normalized = root.trim();
  if (normalized.isEmpty || !_isAbsoluteRootPath(normalized)) {
    throw const WorkspaceFileException(
      WorkspaceFileFailureCode.noCwd,
      'Workspace root is not available.',
    );
  }
  while (normalized.length > 1 &&
      !_isWindowsDriveRoot(normalized) &&
      (normalized.endsWith('/') || normalized.endsWith(r'\'))) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

String _normalizeRelativePath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty || trimmed == '.') {
    return '';
  }
  if (_isAbsolutePath(trimmed) || trimmed.contains('\u0000')) {
    throw const WorkspaceFileException(
      WorkspaceFileFailureCode.pathOutsideRoot,
      'Workspace path is outside the workspace root.',
    );
  }

  final segments = <String>[];
  for (final segment in trimmed.replaceAll(r'\', '/').split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      throw const WorkspaceFileException(
        WorkspaceFileFailureCode.pathOutsideRoot,
        'Workspace path is outside the workspace root.',
      );
    }
    segments.add(segment);
  }
  return segments.join('/');
}

String _joinAbsolutePath(String root, String relativePath) {
  if (relativePath.isEmpty) {
    return root;
  }
  final separator = _separatorForRoot(root);
  final hostRelativePath = relativePath.replaceAll('/', separator);
  if (root.endsWith('/') || root.endsWith(r'\')) {
    return '$root$hostRelativePath';
  }
  return '$root$separator$hostRelativePath';
}

String _separatorForRoot(String root) {
  if (root.contains(r'\') && !root.contains('/')) {
    return r'\';
  }
  return '/';
}

bool _isAbsolutePath(String path) {
  if (path.startsWith('/') || path.startsWith(r'\')) {
    return true;
  }
  if (RegExp(r'^[A-Za-z]:').hasMatch(path)) {
    return true;
  }
  return false;
}

bool _isAbsoluteRootPath(String path) {
  if (path.startsWith('/')) {
    return true;
  }
  if (path.startsWith(r'\\')) {
    return true;
  }
  if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) {
    return true;
  }
  return false;
}

bool _isWindowsDriveRoot(String path) =>
    RegExp(r'^[A-Za-z]:[\\/]$').hasMatch(path);
