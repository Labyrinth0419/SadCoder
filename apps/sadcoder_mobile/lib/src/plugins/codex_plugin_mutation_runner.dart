import '../protocol/codex_app_server_client.dart';
import 'plugin_list_reader.dart';
import 'plugin_mutation_runner.dart';

class CodexPluginMutationRunner implements PluginMutationRunner {
  const CodexPluginMutationRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<PluginMutationResult> installPlugin({
    required PluginCatalogTarget target,
  }) async {
    final result = await _client.installPlugin(
      pluginName: target.requestPluginName,
      marketplacePath: target.marketplacePath,
      remoteMarketplaceName: target.remoteMarketplaceName,
    );
    return PluginMutationResult.fromJson(
      operation: PluginMutationOperation.install,
      pluginId: target.plugin.id,
      json: result,
    );
  }

  @override
  Future<PluginMutationResult> uninstallPlugin({
    required String pluginId,
  }) async {
    final normalized = pluginId.trim();
    final result = await _client.uninstallPlugin(pluginId: normalized);
    return PluginMutationResult.fromJson(
      operation: PluginMutationOperation.uninstall,
      pluginId: normalized,
      json: result,
    );
  }
}
