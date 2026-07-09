import '../protocol/codex_app_server_client.dart';
import 'thread_detail_reader.dart';
import 'thread_summary.dart';

class CodexThreadDetailReader implements ThreadDetailReader {
  const CodexThreadDetailReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async {
    final result = await _client.readThread(
      threadId: threadId,
      includeTurns: includeTurns,
    );
    return ThreadDetail.fromJson(result);
  }
}
