import '../protocol/codex_app_server_client.dart';
import 'file_search_reader.dart';

class CodexFileSearchReader implements FileSearchReader {
  const CodexFileSearchReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<FileSearchResultPage> searchFiles({
    required String query,
    List<String> roots = const [],
    String? cancellationToken,
  }) async {
    final response = await _client.searchFiles(
      query: query,
      roots: roots,
      cancellationToken: cancellationToken,
    );
    return FileSearchResultPage.fromJson(response);
  }
}
