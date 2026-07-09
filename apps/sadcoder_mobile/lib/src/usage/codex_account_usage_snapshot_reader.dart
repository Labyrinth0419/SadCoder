import '../protocol/codex_app_server_client.dart';
import 'account_usage_snapshot_reader.dart';

class CodexAccountUsageSnapshotReader implements AccountUsageSnapshotReader {
  const CodexAccountUsageSnapshotReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<AccountUsageSnapshot> readUsage() async {
    final results = await Future.wait([
      _client.readAccountUsage(),
      _client.readAccountRateLimits(),
    ]);
    return AccountUsageSnapshot.fromJson(
      usageJson: results[0],
      rateLimitsJson: results[1],
    );
  }
}
