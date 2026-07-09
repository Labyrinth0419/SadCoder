import '../protocol/codex_app_server_client.dart';
import 'app_list_reader.dart';

class CodexAppListReader implements AppListReader {
  const CodexAppListReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<AppListPage> listApps({
    String? cursor,
    int? limit,
    String? threadId,
    bool forceRefetch = false,
  }) async {
    final response = await _client.listApps(
      cursor: cursor,
      limit: limit,
      threadId: threadId,
      forceRefetch: forceRefetch,
    );
    return AppListPage.fromJson(response);
  }
}
