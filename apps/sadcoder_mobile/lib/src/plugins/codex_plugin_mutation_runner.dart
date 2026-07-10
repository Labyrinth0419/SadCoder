import '../protocol/codex_app_server_client.dart';
import 'plugin_mutation_runner.dart';

class CodexPluginMutationRunner implements PluginMutationRunner {
  const CodexPluginMutationRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<PluginMutationResult> installPlugin({
    required String pluginId,
    List<String> cwds = const [],
  }) async {
    final normalized = pluginId.trim();
    final result = await _client.installPlugin(
      pluginId: normalized,
      cwds: cwds,
    );
    return PluginMutationResult.fromJson(
      operation: PluginMutationOperation.install,
      pluginId: normalized,
      json: result,
    );
  }

  @override
  Future<PluginMutationResult> uninstallPlugin({
    required String pluginId,
    List<String> cwds = const [],
  }) async {
    final normalized = pluginId.trim();
    final result = await _client.uninstallPlugin(
      pluginId: normalized,
      cwds: cwds,
    );
    return PluginMutationResult.fromJson(
      operation: PluginMutationOperation.uninstall,
      pluginId: normalized,
      json: result,
    );
  }
}
