import '../protocol/codex_app_server_client.dart';
import 'plugin_detail_reader.dart';
import 'plugin_list_reader.dart';

class CodexPluginDetailReader implements PluginDetailReader {
  const CodexPluginDetailReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<PluginDetail> readPlugin({required PluginCatalogTarget target}) async {
    final result = await _client.readPlugin(
      pluginName: target.requestPluginName,
      marketplacePath: target.marketplacePath,
      remoteMarketplaceName: target.remoteMarketplaceName,
    );
    return PluginDetail.fromJson(pluginId: target.plugin.id, json: result);
  }
}
