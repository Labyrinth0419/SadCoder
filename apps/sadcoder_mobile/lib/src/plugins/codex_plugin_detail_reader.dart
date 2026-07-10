import '../protocol/codex_app_server_client.dart';
import 'plugin_detail_reader.dart';

class CodexPluginDetailReader implements PluginDetailReader {
  const CodexPluginDetailReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<PluginDetail> readPlugin({
    required String pluginId,
    List<String> cwds = const [],
  }) async {
    final normalized = pluginId.trim();
    final result = await _client.readPlugin(pluginId: normalized, cwds: cwds);
    return PluginDetail.fromJson(pluginId: normalized, json: result);
  }
}
