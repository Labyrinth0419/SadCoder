import '../protocol/codex_app_server_client.dart';
import 'model_list_reader.dart';

class CodexModelListReader implements ModelListReader {
  const CodexModelListReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ModelListPage> listModels({
    String? cursor,
    int? limit,
    bool includeHidden = false,
  }) async {
    final models = <CodexModelSummary>[];
    String? nextCursor = cursor;
    final seenCursors = <String>{};
    do {
      final result = await _client.listModels(
        cursor: nextCursor,
        limit: limit,
        includeHidden: includeHidden,
      );
      final page = ModelListPage.fromJson(result);
      models.addAll(page.models);
      nextCursor = page.nextCursor;
      if (nextCursor != null && !seenCursors.add(nextCursor)) {
        throw StateError('model/list returned a repeated cursor');
      }
    } while (nextCursor != null);

    return ModelListPage(models: List.unmodifiable(models));
  }
}
