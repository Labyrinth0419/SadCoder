import '../workspace/workspace_command_runner.dart';
import 'git_diff_reader.dart';

class CodexGitDiffReader implements GitDiffReader {
  const CodexGitDiffReader(this._runner);

  static const _probeTimeoutMs = 5000;
  static const _diffTimeoutMs = 30000;
  static const _probeOutputCap = 64 * 1024;
  static const _disableHooksConfig = 'core.hooksPath=/dev/null';
  static const _executableFilterPattern = r'^filter\..*\.(clean|process)$';

  final WorkspaceCommandRunner _runner;

  @override
  Future<GitDiffResult> readDiff({String? cwd}) async {
    final normalizedCwd = _normalizeCwd(cwd);
    if (!await _insideGitRepository(normalizedCwd)) {
      return const GitDiffResult(isGitRepository: false, stat: '', diff: '');
    }

    final filterEnv = await _filterOverrideEnv(normalizedCwd);
    final stat = await _runGitDiffCapture(
      normalizedCwd,
      ['diff', ..._diffSafetyArgs, '--stat'],
      env: filterEnv,
      disableOutputCap: false,
    );
    final trackedDiff = await _runGitDiffCapture(
      normalizedCwd,
      ['diff', ..._diffSafetyArgs, '--no-color'],
      env: filterEnv,
      disableOutputCap: true,
    );
    final untrackedFiles = await _untrackedFiles(normalizedCwd);
    final untrackedDiffs = <String>[];
    for (final file in untrackedFiles) {
      untrackedDiffs.add(
        await _runUntrackedDiff(normalizedCwd, file, env: filterEnv),
      );
    }

    return GitDiffResult(
      isGitRepository: true,
      stat: stat,
      diff: [trackedDiff, ...untrackedDiffs].join(),
    );
  }

  Future<bool> _insideGitRepository(String? cwd) async {
    final output = await _runGit(
      cwd,
      ['rev-parse', '--is-inside-work-tree'],
      timeoutMs: _probeTimeoutMs,
      outputBytesCap: _probeOutputCap,
    );
    return output.success;
  }

  Future<Map<String, String?>> _filterOverrideEnv(String? cwd) async {
    final output = await _runGit(
      cwd,
      [
        'config',
        '--null',
        '--name-only',
        '--get-regexp',
        _executableFilterPattern,
      ],
      timeoutMs: _probeTimeoutMs,
      outputBytesCap: _probeOutputCap,
    );
    if (output.exitCode != 0 && output.exitCode != 1) {
      throw StateError(
        'git config filter probe failed with status ${output.exitCode}',
      );
    }

    final drivers =
        output.stdout
            .split('\u0000')
            .map((key) {
              if (key.endsWith('.clean')) {
                return key.substring(0, key.length - '.clean'.length);
              }
              if (key.endsWith('.process')) {
                return key.substring(0, key.length - '.process'.length);
              }
              return '';
            })
            .where((driver) => driver.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (drivers.isEmpty) {
      return const {};
    }

    final env = <String, String?>{'GIT_CONFIG_COUNT': '${drivers.length * 3}'};
    var index = 0;
    for (final driver in drivers) {
      env['GIT_CONFIG_KEY_$index'] = '$driver.clean';
      env['GIT_CONFIG_VALUE_$index'] = '';
      index++;
      env['GIT_CONFIG_KEY_$index'] = '$driver.process';
      env['GIT_CONFIG_VALUE_$index'] = '';
      index++;
      env['GIT_CONFIG_KEY_$index'] = '$driver.required';
      env['GIT_CONFIG_VALUE_$index'] = 'false';
      index++;
    }
    return env;
  }

  Future<String> _runGitDiffCapture(
    String? cwd,
    List<String> args, {
    Map<String, String?> env = const {},
    required bool disableOutputCap,
  }) async {
    final output = await _runGit(
      cwd,
      args,
      env: env,
      timeoutMs: _diffTimeoutMs,
      disableOutputCap: disableOutputCap,
      outputBytesCap: disableOutputCap ? null : _probeOutputCap,
    );
    if (output.success || output.exitCode == 1) {
      return output.stdout;
    }
    throw StateError(
      'git ${args.join(' ')} failed with status ${output.exitCode}',
    );
  }

  Future<List<String>> _untrackedFiles(String? cwd) async {
    final output = await _runGit(
      cwd,
      ['ls-files', '--others', '--exclude-standard', '-z'],
      timeoutMs: _probeTimeoutMs,
      outputBytesCap: _probeOutputCap,
    );
    if (!output.success) {
      throw StateError('git ls-files failed with status ${output.exitCode}');
    }
    return output.stdout
        .split('\u0000')
        .where((file) => file.trim().isNotEmpty)
        .toList();
  }

  Future<String> _runUntrackedDiff(
    String? cwd,
    String file, {
    Map<String, String?> env = const {},
  }) async {
    try {
      return await _runGitDiffCapture(
        cwd,
        [
          'diff',
          ..._diffSafetyArgs,
          '--no-color',
          '--no-index',
          '--',
          '/dev/null',
          file,
        ],
        env: env,
        disableOutputCap: true,
      );
    } on StateError {
      return _runGitDiffCapture(
        cwd,
        [
          'diff',
          ..._diffSafetyArgs,
          '--no-color',
          '--no-index',
          '--',
          'NUL',
          file,
        ],
        env: env,
        disableOutputCap: true,
      );
    }
  }

  Future<WorkspaceCommandResult> _runGit(
    String? cwd,
    List<String> args, {
    Map<String, String?> env = const {},
    int? timeoutMs,
    int? outputBytesCap,
    bool disableOutputCap = false,
  }) {
    return _runner.runCommand(
      WorkspaceCommand(
        command: [
          'git',
          '-c',
          'core.fsmonitor=false',
          '-c',
          _disableHooksConfig,
          ...args,
        ],
        cwd: cwd,
        env: env,
        timeoutMs: timeoutMs,
        outputBytesCap: outputBytesCap,
        disableOutputCap: disableOutputCap,
      ),
    );
  }

  String? _normalizeCwd(String? cwd) {
    final trimmed = cwd?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

const _diffSafetyArgs = [
  '--no-textconv',
  '--no-ext-diff',
  '--submodule=short',
  '--ignore-submodules=dirty',
];
