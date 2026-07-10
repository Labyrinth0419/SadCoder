import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_failure.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('normalizes workspace JSON-RPC error codes', () {
    final cases = <int, WorkspaceFileFailureCode>{
      -32020: WorkspaceFileFailureCode.noCwd,
      -32021: WorkspaceFileFailureCode.notFound,
      -32022: WorkspaceFileFailureCode.permissionDenied,
      -32023: WorkspaceFileFailureCode.pathOutsideRoot,
      -32024: WorkspaceFileFailureCode.binaryNotPreviewable,
      -32025: WorkspaceFileFailureCode.readFailed,
      -32026: WorkspaceFileFailureCode.tooLarge,
    };

    for (final entry in cases.entries) {
      final exception = normalizeWorkspaceFileException(
        JsonRpcRemoteException(
          'workspace error',
          code: entry.key,
          data: {'path': 'README.md'},
        ),
      );

      expect(exception.code, entry.value);
      expect(exception.detail, {'path': 'README.md'});
    }
  });

  test(
    'falls back to JSON-RPC error message when code is not workspace-specific',
    () {
      final exception = normalizeWorkspaceFileException(
        const JsonRpcRemoteException('permission denied', code: -32603),
      );

      expect(exception.code, WorkspaceFileFailureCode.permissionDenied);
    },
  );

  test('normalizes structured workspace JSON-RPC error data', () {
    final exception = normalizeWorkspaceFileException(
      const JsonRpcRemoteException(
        'internal error',
        code: -32603,
        data: {
          'code': 'path-outside-root',
          'message': 'workspace path is outside the workspace root',
          'detail': '../secrets.txt escapes the workspace root',
        },
      ),
    );

    expect(exception.code, WorkspaceFileFailureCode.pathOutsideRoot);
    expect(exception.detail, '../secrets.txt escapes the workspace root');
  });

  test('prefers structured workspace data over legacy numeric code', () {
    final exception = normalizeWorkspaceFileException(
      const JsonRpcRemoteException(
        'workspace error',
        code: -32021,
        data: {
          'code': 'permission-denied',
          'detail': 'private.txt cannot be read',
        },
      ),
    );

    expect(exception.code, WorkspaceFileFailureCode.permissionDenied);
    expect(exception.detail, 'private.txt cannot be read');
  });

  test('uses structured workspace message when detail is absent', () {
    final exception = normalizeWorkspaceFileException(
      const JsonRpcRemoteException(
        'remote fallback',
        data: {
          'code': 'too-large',
          'message': 'workspace file is too large to preview: 12 MiB',
        },
      ),
    );

    expect(exception.code, WorkspaceFileFailureCode.tooLarge);
    expect(exception.detail, 'workspace file is too large to preview: 12 MiB');
  });
}
