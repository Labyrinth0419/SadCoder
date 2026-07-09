import '../protocol/codex_app_server_client.dart';
import 'codex_config_snapshot.dart';
import 'codex_config_snapshot_reader.dart';

class CodexConfigSnapshotRemoteReader implements CodexConfigSnapshotReader {
  const CodexConfigSnapshotRemoteReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    final result = await _client.readConfig(
      includeLayers: includeLayers,
      cwd: cwd,
    );
    return CodexConfigSnapshot.fromJson(result);
  }
}
