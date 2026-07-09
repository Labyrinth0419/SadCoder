import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/diffs/codex_git_diff_reader.dart';
import 'package:sadcoder_mobile/src/workspace/workspace_command_runner.dart';

void main() {
  test('returns not-git result when cwd is outside a repository', () async {
    final runner = _FakeWorkspaceCommandRunner([
      const WorkspaceCommandResult(exitCode: 128, stdout: '', stderr: ''),
    ]);
    final reader = CodexGitDiffReader(runner);

    final result = await reader.readDiff(cwd: ' /repo ');

    expect(result.isGitRepository, false);
    expect(result.hasChanges, false);
    expect(runner.commands.single.cwd, '/repo');
    expect(runner.commands.single.command, contains('rev-parse'));
  });

  test('reads tracked and untracked git diffs', () async {
    final runner = _FakeWorkspaceCommandRunner([
      const WorkspaceCommandResult(exitCode: 0, stdout: 'true\n', stderr: ''),
      const WorkspaceCommandResult(exitCode: 1, stdout: '', stderr: ''),
      const WorkspaceCommandResult(
        exitCode: 0,
        stdout: ' lib/main.dart | 2 +-\n',
        stderr: '',
      ),
      const WorkspaceCommandResult(
        exitCode: 0,
        stdout: 'diff --git a/lib/main.dart b/lib/main.dart\n',
        stderr: '',
      ),
      const WorkspaceCommandResult(
        exitCode: 0,
        stdout: 'new.txt\u0000',
        stderr: '',
      ),
      const WorkspaceCommandResult(
        exitCode: 1,
        stdout: 'diff --git a/new.txt b/new.txt\n',
        stderr: '',
      ),
    ]);
    final reader = CodexGitDiffReader(runner);

    final result = await reader.readDiff(cwd: '/repo');

    expect(result.isGitRepository, true);
    expect(result.stat, ' lib/main.dart | 2 +-\n');
    expect(
      result.diff,
      'diff --git a/lib/main.dart b/lib/main.dart\n'
      'diff --git a/new.txt b/new.txt\n',
    );
    expect(runner.commands, hasLength(6));
    expect(runner.commands[3].disableOutputCap, true);
    expect(runner.commands[3].command, contains('--no-color'));
    expect(runner.commands[5].command, contains('--no-index'));
    expect(runner.commands[5].command.last, 'new.txt');
  });

  test(
    'disables configured executable git filters for diff commands',
    () async {
      final runner = _FakeWorkspaceCommandRunner([
        const WorkspaceCommandResult(exitCode: 0, stdout: 'true\n', stderr: ''),
        const WorkspaceCommandResult(
          exitCode: 0,
          stdout: 'filter.evil.clean\u0000filter.evil.process\u0000',
          stderr: '',
        ),
        const WorkspaceCommandResult(exitCode: 0, stdout: '', stderr: ''),
        const WorkspaceCommandResult(
          exitCode: 0,
          stdout: 'tracked\n',
          stderr: '',
        ),
        const WorkspaceCommandResult(exitCode: 0, stdout: '', stderr: ''),
      ]);
      final reader = CodexGitDiffReader(runner);

      await reader.readDiff(cwd: '/repo');

      expect(runner.commands[2].env, {
        'GIT_CONFIG_COUNT': '3',
        'GIT_CONFIG_KEY_0': 'filter.evil.clean',
        'GIT_CONFIG_VALUE_0': '',
        'GIT_CONFIG_KEY_1': 'filter.evil.process',
        'GIT_CONFIG_VALUE_1': '',
        'GIT_CONFIG_KEY_2': 'filter.evil.required',
        'GIT_CONFIG_VALUE_2': 'false',
      });
      expect(runner.commands[3].env, runner.commands[2].env);
    },
  );

  test('throws when git diff exits with an unexpected status', () async {
    final runner = _FakeWorkspaceCommandRunner([
      const WorkspaceCommandResult(exitCode: 0, stdout: 'true\n', stderr: ''),
      const WorkspaceCommandResult(exitCode: 1, stdout: '', stderr: ''),
      const WorkspaceCommandResult(exitCode: 0, stdout: '', stderr: ''),
      const WorkspaceCommandResult(exitCode: 2, stdout: '', stderr: ''),
    ]);
    final reader = CodexGitDiffReader(runner);

    await expectLater(
      reader.readDiff(cwd: '/repo'),
      throwsA(isA<StateError>()),
    );
  });
}

class _FakeWorkspaceCommandRunner implements WorkspaceCommandRunner {
  _FakeWorkspaceCommandRunner(List<WorkspaceCommandResult> results)
    : _results = Queue.of(results);

  final Queue<WorkspaceCommandResult> _results;
  final commands = <WorkspaceCommand>[];

  @override
  Future<WorkspaceCommandResult> runCommand(WorkspaceCommand command) async {
    commands.add(command);
    return _results.removeFirst();
  }
}
