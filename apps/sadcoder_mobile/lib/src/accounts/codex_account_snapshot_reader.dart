import '../protocol/codex_app_server_client.dart';
import 'account_snapshot_reader.dart';

class CodexAccountSnapshotReader implements AccountSnapshotReader {
  const CodexAccountSnapshotReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<AccountSnapshot> readAccount({bool refreshToken = false}) async {
    final result = await _client.readAccount(refreshToken: refreshToken);
    return AccountSnapshot.fromJson(result);
  }
}
