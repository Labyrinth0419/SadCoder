import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/commands/codex_slash_command_manifest_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  test('reads slash command manifest through the agent proxy RPC', () async {
    final requests = <JsonRpcRequest>[];
    final client = CodexAppServerClient(
      MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {
          'schemaVersion': 1,
          'source': 'test-agent',
          'commands': [
            {
              'command': 'remote-only',
              'aliases': ['ro'],
              'description': 'remote command',
              'supportsInlineArgs': true,
              'availableDuringTask': true,
              'availableInSideConversation': false,
              'platformVisibility': 'all',
              'mappingType': 'appServer',
              'mappingTarget': 'test',
              'phase': 'mvp',
              'riskLevel': 'low',
            },
          ],
        };
      }),
    );
    final reader = CodexSlashCommandManifestReader(client);

    final manifest = await reader.readSlashCommands(_profile);

    expect(requests.single.method, 'agent/slashCommands/list');
    expect(requests.single.params, isNull);
    expect(manifest.source, 'test-agent');
    expect(manifest.asRegistry().find('/ro')?.command, 'remote-only');
  });
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);
