import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/hooks/codex_hook_list_reader.dart';
import 'package:sadcoder_mobile/src/hooks/hook_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('HookListPage parses hook inventory payloads', () {
    final page = HookListPage.fromJson({
      'data': [
        {
          'cwd': '/repo',
          'hooks': [
            {
              'key': 'pre-tool-use-shell',
              'eventName': 'preToolUse',
              'handlerType': 'command',
              'matcher': 'shell',
              'command': 'scripts/check.sh',
              'timeoutSec': 30,
              'statusMessage': 'Checking shell command',
              'sourcePath': '/repo/.codex/hooks.json',
              'source': 'project',
              'pluginId': 'guardrails',
              'displayOrder': 2,
              'enabled': false,
              'isManaged': true,
              'currentHash': 'abc123',
              'trustStatus': 'modified',
            },
            {'eventName': 'missing-key'},
          ],
          'warnings': ['deprecated hook shape'],
          'errors': [
            {'path': '/repo/.codex/bad-hooks.json', 'message': 'invalid hook'},
          ],
        },
        {'hooks': []},
      ],
    });

    expect(page.entries, hasLength(1));
    final entry = page.entries.single;
    expect(entry.cwd, '/repo');
    expect(entry.warnings, ['deprecated hook shape']);
    expect(entry.errors.single.message, 'invalid hook');
    expect(entry.hooks, hasLength(1));

    final hook = entry.hooks.single;
    expect(hook.key, 'pre-tool-use-shell');
    expect(hook.eventName, 'preToolUse');
    expect(hook.handlerType, 'command');
    expect(hook.matcher, 'shell');
    expect(hook.command, 'scripts/check.sh');
    expect(hook.timeoutSec, 30);
    expect(hook.statusMessage, 'Checking shell command');
    expect(hook.sourcePath, '/repo/.codex/hooks.json');
    expect(hook.source, 'project');
    expect(hook.pluginId, 'guardrails');
    expect(hook.displayOrder, 2);
    expect(hook.enabled, false);
    expect(hook.isManaged, true);
    expect(hook.currentHash, 'abc123');
    expect(hook.trustStatus, 'modified');
  });

  test('CodexHookListReader calls app-server hooks/list', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'data': [
          {
            'cwd': '/repo',
            'hooks': [
              {
                'key': 'post-tool-use',
                'eventName': 'postToolUse',
                'handlerType': 'command',
                'timeoutSec': 10,
                'sourcePath': '/repo/.codex/hooks.json',
                'source': 'project',
                'displayOrder': 1,
                'enabled': true,
                'isManaged': false,
                'currentHash': 'abc',
                'trustStatus': 'trusted',
              },
            ],
          },
        ],
      };
    });
    final reader = CodexHookListReader(CodexAppServerClient(transport));

    final page = await reader.listHooks(cwds: [' /repo ', ' ']);

    expect(page.entries.single.hooks.single.key, 'post-tool-use');
    expect(requests.single.method, 'hooks/list');
    expect(requests.single.params, {
      'cwds': ['/repo'],
    });
  });
}
