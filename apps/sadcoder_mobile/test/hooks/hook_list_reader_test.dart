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

  test('HookListPage parses snake_case hook fields', () {
    final page = HookListPage.fromJson({
      'data': [
        {
          'cwd': '/repo',
          'hooks': [
            {
              'key': 'post-tool-use-shell',
              'event_name': 'postToolUse',
              'handler_type': 'command',
              'matcher': 'shell',
              'command': 'scripts/report.sh',
              'timeout_sec': 45,
              'status_message': 'Reporting shell command',
              'source_path': '/repo/.codex/hooks.json',
              'source': 'project',
              'plugin_id': 'audit',
              'display_order': 5,
              'enabled': true,
              'is_managed': false,
              'current_hash': 'def456',
              'trust_status': 'trusted',
            },
          ],
        },
      ],
    });

    final hook = page.entries.single.hooks.single;
    expect(hook.eventName, 'postToolUse');
    expect(hook.handlerType, 'command');
    expect(hook.timeoutSec, 45);
    expect(hook.statusMessage, 'Reporting shell command');
    expect(hook.sourcePath, '/repo/.codex/hooks.json');
    expect(hook.pluginId, 'audit');
    expect(hook.displayOrder, 5);
    expect(hook.isManaged, false);
    expect(hook.currentHash, 'def456');
    expect(hook.trustStatus, 'trusted');
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
