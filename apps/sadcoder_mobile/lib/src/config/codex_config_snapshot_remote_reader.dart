import '../protocol/codex_app_server_client.dart';
import '../protocol/json_rpc.dart';
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
    final snapshot = CodexConfigSnapshot.fromJson(result);
    try {
      final requirementsResult = await _client.readConfigRequirements();
      return snapshot.withRequirements(
        supported: true,
        value: _objectMapOrNull(requirementsResult['requirements']),
      );
    } on JsonRpcRemoteException catch (error) {
      if (error.code != -32601) {
        rethrow;
      }
      return snapshot.withRequirements(supported: false, value: null);
    }
  }
}

Map<String, Object?>? _objectMapOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value as Object?)),
    );
  }
  return const {};
}
