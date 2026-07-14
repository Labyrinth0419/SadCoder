import '../protocol/codex_app_server_client.dart';
import '../protocol/json_rpc.dart';
import 'collaboration_mode_list_reader.dart';

class CodexCollaborationModeListReader implements CollaborationModeListReader {
  const CodexCollaborationModeListReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<CollaborationModeCatalog> listCollaborationModes() async {
    try {
      final response = await _client.listCollaborationModes();
      return CollaborationModeCatalog.fromJson(response);
    } on JsonRpcRemoteException catch (error) {
      if (error.code != -32601) {
        rethrow;
      }
      return CollaborationModeCatalog.unsupported;
    }
  }
}
