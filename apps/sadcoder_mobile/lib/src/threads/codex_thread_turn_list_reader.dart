import '../protocol/codex_app_server_client.dart';
import 'thread_summary.dart';
import 'thread_turn_list_reader.dart';

class CodexThreadTurnListReader implements ThreadTurnListReader {
  const CodexThreadTurnListReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ThreadTurnsPage> listTurns({
    required String threadId,
    String? cursor,
    int? limit,
    String? sortDirection,
    String? itemsView,
  }) async {
    final result = await _client.listThreadTurns(
      threadId: threadId,
      cursor: cursor,
      limit: limit,
      sortDirection: sortDirection,
      itemsView: itemsView,
    );
    return ThreadTurnsPage.fromJson(result);
  }
}
