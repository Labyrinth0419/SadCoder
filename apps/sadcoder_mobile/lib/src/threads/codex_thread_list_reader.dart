import '../protocol/codex_app_server_client.dart';
import 'thread_list_reader.dart';
import 'thread_summary.dart';

class CodexThreadListReader implements ThreadListReader {
  const CodexThreadListReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ThreadListPage> listThreads({
    int limit = 20,
    bool archived = false,
  }) async {
    final result = await _client.listThreads(limit: limit, archived: archived);
    return ThreadListPage.fromJson(result);
  }
}
