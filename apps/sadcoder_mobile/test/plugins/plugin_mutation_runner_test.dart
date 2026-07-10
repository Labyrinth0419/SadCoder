import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/plugins/codex_plugin_mutation_runner.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_mutation_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('installPlugin calls app-server plugin/install', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'pluginId': 'linear', 'message': 'installed'};
    });
    final runner = CodexPluginMutationRunner(CodexAppServerClient(transport));

    final result = await runner.installPlugin(
      pluginId: ' linear ',
      cwds: [' /repo ', ' '],
    );

    expect(result.operation, PluginMutationOperation.install);
    expect(result.pluginId, 'linear');
    expect(result.message, 'installed');
    expect(requests.single.method, 'plugin/install');
    expect(requests.single.params, {
      'pluginId': 'linear',
      'cwds': ['/repo'],
    });
  });

  test('uninstallPlugin calls app-server plugin/uninstall', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'pluginId': 'linear', 'message': 'uninstalled'};
    });
    final runner = CodexPluginMutationRunner(CodexAppServerClient(transport));

    final result = await runner.uninstallPlugin(
      pluginId: ' linear ',
      cwds: [' /repo ', ' '],
    );

    expect(result.operation, PluginMutationOperation.uninstall);
    expect(result.pluginId, 'linear');
    expect(result.message, 'uninstalled');
    expect(requests.single.method, 'plugin/uninstall');
    expect(requests.single.params, {
      'pluginId': 'linear',
      'cwds': ['/repo'],
    });
  });
}
