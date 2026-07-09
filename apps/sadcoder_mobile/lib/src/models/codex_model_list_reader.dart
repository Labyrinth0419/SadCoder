import '../protocol/codex_app_server_client.dart';
import 'model_list_reader.dart';

class CodexModelListReader implements ModelListReader {
  const CodexModelListReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ModelListPage> listModels() async {
    final result = await _client.listModels();
    return ModelListPage.fromJson(result);
  }
}
