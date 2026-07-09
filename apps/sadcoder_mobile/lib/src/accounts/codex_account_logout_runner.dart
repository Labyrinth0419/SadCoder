import '../protocol/codex_app_server_client.dart';
import 'account_logout_runner.dart';

class CodexAccountLogoutRunner implements AccountLogoutRunner {
  const CodexAccountLogoutRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<void> logout() async {
    await _client.logoutAccount();
  }
}
