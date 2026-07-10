import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_failure.dart';
import 'package:sadcoder_mobile/src/files/workspace_path.dart';

void main() {
  test('normalizes Unix and Windows absolute workspace roots', () {
    final unixPath = WorkspacePath.fromRoot('/repo/', 'lib/main.dart');
    expect(unixPath.root, '/repo');
    expect(unixPath.relativePath, 'lib/main.dart');
    expect(unixPath.absolutePath, '/repo/lib/main.dart');

    final windowsPath = WorkspacePath.fromRoot(r'C:\repo\', 'lib/main.dart');
    expect(windowsPath.root, r'C:\repo');
    expect(windowsPath.relativePath, 'lib/main.dart');
    expect(windowsPath.absolutePath, r'C:\repo\lib\main.dart');
  });

  test('rejects drive-relative workspace roots as unavailable cwd', () {
    expect(
      () => WorkspacePath.fromRoot(r'C:repo', 'lib/main.dart'),
      throwsA(
        isA<WorkspaceFileException>().having(
          (error) => error.code,
          'code',
          WorkspaceFileFailureCode.noCwd,
        ),
      ),
    );
  });

  test('rejects path traversal and absolute replacement paths', () {
    for (final path in ['../secret.txt', '/tmp/secret.txt', r'C:secret.txt']) {
      expect(
        () => WorkspacePath.fromRoot('/repo', path),
        throwsA(
          isA<WorkspaceFileException>().having(
            (error) => error.code,
            'code',
            WorkspaceFileFailureCode.pathOutsideRoot,
          ),
        ),
      );
    }
  });

  test('rejects unsafe child path names from directory responses', () {
    final root = WorkspacePath.fromRoot('/repo');
    for (final name in ['.', '..', 'lib/main.dart', r'lib\main.dart', '']) {
      expect(
        () => root.child(name),
        throwsA(
          isA<WorkspaceFileException>().having(
            (error) => error.code,
            'code',
            WorkspaceFileFailureCode.pathOutsideRoot,
          ),
        ),
      );
    }
  });
}
