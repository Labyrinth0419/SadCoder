import '../protocol/codex_app_server_client.dart';
import 'workspace_file_failure.dart';
import 'workspace_path.dart';

Future<void> rejectSymlinkAncestors(
  CodexAppServerClient client,
  WorkspacePath workspacePath, {
  required String detail,
}) async {
  final relativePath = workspacePath.relativePath;
  if (relativePath.isEmpty) {
    return;
  }

  final segments = relativePath.split('/');
  if (segments.length < 2) {
    return;
  }

  var currentPath = WorkspacePath.fromRoot(workspacePath.root);
  for (var index = 0; index < segments.length - 1; index++) {
    currentPath = currentPath.child(segments[index]);
    final metadata = await client.fsGetMetadata(path: currentPath.absolutePath);
    if (_metadataIsSymlink(metadata)) {
      throw WorkspaceFileException(
        WorkspaceFileFailureCode.pathOutsideRoot,
        'Workspace path is outside the workspace root.',
        detail: detail,
      );
    }
  }
}

bool _metadataIsSymlink(Map<String, Object?> metadata) {
  return metadata['isSymlink'] == true || metadata['is_symlink'] == true;
}
