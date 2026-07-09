import '../protocol/codex_app_server_client.dart';
import 'plugin_list_reader.dart';

class CodexPluginListReader implements PluginListReader {
  const CodexPluginListReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<PluginListPage> listPlugins({
    List<String> cwds = const [],
    List<PluginMarketplaceKind> marketplaceKinds = const [],
  }) async {
    final response = await _client.listPlugins(
      cwds: cwds,
      marketplaceKinds: [for (final kind in marketplaceKinds) kind.wireName],
    );
    return PluginListPage.fromJson(response);
  }
}
