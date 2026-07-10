import '../protocol/codex_app_server_client.dart';
import 'thread_item_list_reader.dart';
import 'thread_summary.dart';

class CodexThreadItemListReader implements ThreadItemListReader {
  const CodexThreadItemListReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ThreadItemsPage> listItems({
    required String threadId,
    String? turnId,
    String? cursor,
    int? limit,
    String? sortDirection,
  }) async {
    final result = await _client.listThreadItems(
      threadId: threadId,
      turnId: turnId,
      cursor: cursor,
      limit: limit,
      sortDirection: sortDirection,
    );
    return ThreadItemsPage.fromJson(result);
  }
}
