import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/workspace/codex_workspace_command_runner.dart';
import 'package:sadcoder_mobile/src/workspace/workspace_command_runner.dart';

void main() {
  test('CodexWorkspaceCommandRunner calls app-server command/exec', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'exitCode': 1, 'stdout': 'diff', 'stderr': 'warning'};
    });
    final runner = CodexWorkspaceCommandRunner(CodexAppServerClient(transport));

    final result = await runner.runCommand(
      const WorkspaceCommand(
        command: ['git', 'diff'],
        cwd: '/repo',
        env: {'GIT_CONFIG_COUNT': '0'},
        timeoutMs: 30000,
        disableOutputCap: true,
      ),
    );

    expect(result.exitCode, 1);
    expect(result.stdout, 'diff');
    expect(result.stderr, 'warning');
    expect(result.success, false);
    expect(requests.single.method, 'command/exec');
    expect(requests.single.params, {
      'command': ['git', 'diff'],
      'cwd': '/repo',
      'env': {'GIT_CONFIG_COUNT': '0'},
      'timeoutMs': 30000,
      'disableOutputCap': true,
    });
  });

  test('WorkspaceCommandResult parses alternate app-server field names', () {
    final result = WorkspaceCommandResult.fromJson({
      'exit_code': 2,
      'stdOut': 'output',
      'std_err': 'warning',
    });

    expect(result.exitCode, 2);
    expect(result.stdout, 'output');
    expect(result.stderr, 'warning');
    expect(result.success, false);
  });
}
