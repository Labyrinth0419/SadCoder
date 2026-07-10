import '../protocol/codex_app_server_client.dart';
import 'workspace_path.dart';

class WorkspaceDirectoryApiResponse {
  const WorkspaceDirectoryApiResponse({
    required this.body,
    required this.serverPaginated,
  });

  final Map<String, Object?> body;
  final bool serverPaginated;
}

Future<WorkspaceDirectoryApiResponse> readWorkspaceDirectoryWithFallback(
  CodexAppServerClient client,
  WorkspacePath workspacePath, {
  required int limit,
  required String? cursor,
  required bool includeHidden,
}) async {
  try {
    return WorkspaceDirectoryApiResponse(
      body: await client.workspaceDirectoryList(
        root: workspacePath.root,
        path: workspacePath.relativePath,
        limit: limit,
        cursor: cursor,
        includeHidden: includeHidden,
      ),
      serverPaginated: true,
    );
  } catch (error) {
    if (!_isUnsupportedWorkspaceMethod(error)) {
      rethrow;
    }
    return WorkspaceDirectoryApiResponse(
      body: await client.fsReadDirectory(path: workspacePath.absolutePath),
      serverPaginated: false,
    );
  }
}

Future<Map<String, Object?>> readWorkspaceMetadataWithFallback(
  CodexAppServerClient client,
  WorkspacePath workspacePath,
) async {
  try {
    return await client.workspaceFileStat(
      root: workspacePath.root,
      path: workspacePath.relativePath,
    );
  } catch (error) {
    if (!_isUnsupportedWorkspaceMethod(error)) {
      rethrow;
    }
    return client.fsGetMetadata(path: workspacePath.absolutePath);
  }
}

Future<Map<String, Object?>> readWorkspaceFileWithFallback(
  CodexAppServerClient client,
  WorkspacePath workspacePath, {
  required int offset,
  required int limitBytes,
  required String encoding,
}) async {
  try {
    return await client.workspaceFileRead(
      root: workspacePath.root,
      path: workspacePath.relativePath,
      offset: offset,
      limitBytes: limitBytes,
      encoding: encoding,
    );
  } catch (error) {
    if (!_isUnsupportedWorkspaceMethod(error)) {
      rethrow;
    }
    return client.fsReadFile(
      path: workspacePath.absolutePath,
      offset: offset,
      limitBytes: limitBytes,
      encoding: encoding,
    );
  }
}

bool _isUnsupportedWorkspaceMethod(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('method not found') ||
      message.contains('method_not_found') ||
      message.contains('unknown method') ||
      message.contains('unknown request') ||
      message.contains('not implemented') ||
      message.contains('unimplemented');
}
