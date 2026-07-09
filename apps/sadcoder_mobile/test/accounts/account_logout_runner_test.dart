import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/codex_account_logout_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('CodexAccountLogoutRunner calls app-server account/logout', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });
    final runner = CodexAccountLogoutRunner(CodexAppServerClient(transport));

    await runner.logout();

    expect(requests.single.method, 'account/logout');
    expect(requests.single.params, isNull);
  });
}
