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
}
