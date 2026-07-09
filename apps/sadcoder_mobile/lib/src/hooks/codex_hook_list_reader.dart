import '../protocol/codex_app_server_client.dart';
import 'hook_list_reader.dart';

class CodexHookListReader implements HookListReader {
  const CodexHookListReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<HookListPage> listHooks({List<String> cwds = const []}) async {
    final response = await _client.listHooks(cwds: cwds);
    return HookListPage.fromJson(response);
  }
}
