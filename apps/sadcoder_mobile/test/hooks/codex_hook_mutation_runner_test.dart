import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/hooks/codex_hook_mutation_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('writes hook enabled and trusted hash through hooks.state', () async {
    final requests = <JsonRpcRequest>[];
    final runner = CodexHookMutationRunner(
      CodexAppServerClient(
        MemoryJsonRpcTransport((request) {
          requests.add(request);
          return {'ok': true};
        }),
      ),
    );

    await runner.setHookEnabled(hookKey: 'quoted.key\\path', enabled: false);
    await runner.trustHook(
      hookKey: 'quoted.key\\path',
      currentHash: ' hash-1 ',
    );

    expect(requests, hasLength(2));
    expect(requests[0].method, 'config/batchWrite');
    expect(requests[0].params, {
      'edits': [
        {
          'keyPath': 'hooks.state',
          'value': {
            'quoted.key\\path': {'enabled': false},
          },
          'mergeStrategy': 'upsert',
        },
      ],
      'reloadUserConfig': true,
    });
    expect(requests[1].params?['edits'], [
      {
        'keyPath': 'hooks.state',
        'value': {
          'quoted.key\\path': {'trusted_hash': 'hash-1'},
        },
        'mergeStrategy': 'upsert',
      },
    ]);
  });

  test('rejects blank hook keys and trust hashes', () async {
    final runner = CodexHookMutationRunner(
      CodexAppServerClient(MemoryJsonRpcTransport((_) => {})),
    );

    expect(
      () => runner.setHookEnabled(hookKey: ' ', enabled: true),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => runner.trustHook(hookKey: 'hook', currentHash: ' '),
      throwsA(isA<ArgumentError>()),
    );
  });
}
