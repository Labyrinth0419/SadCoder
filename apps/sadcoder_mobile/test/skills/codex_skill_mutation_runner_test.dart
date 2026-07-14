import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/skills/codex_skill_mutation_runner.dart';

void main() {
  test('writes skill enabled state by path', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'effectiveEnabled': false};
    });
    addTearDown(transport.close);

    final runner = CodexSkillMutationRunner(CodexAppServerClient(transport));
    final result = await runner.setSkillEnabled(
      path: ' /repo/.codex/skills/review/SKILL.md ',
      enabled: false,
    );

    expect(requests.single.method, 'skills/config/write');
    expect(requests.single.params, {
      'path': '/repo/.codex/skills/review/SKILL.md',
      'enabled': false,
    });
    expect(result.effectiveEnabled, isFalse);
  });

  test('rejects malformed mutation responses', () async {
    final transport = MemoryJsonRpcTransport((_) => <String, Object?>{});
    addTearDown(transport.close);
    final runner = CodexSkillMutationRunner(CodexAppServerClient(transport));

    await expectLater(
      runner.setSkillEnabled(name: 'review', enabled: true),
      throwsA(isA<FormatException>()),
    );
  });
}
