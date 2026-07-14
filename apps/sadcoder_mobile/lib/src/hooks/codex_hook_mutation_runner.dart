import '../protocol/codex_app_server_client.dart';
import 'hook_mutation_runner.dart';

class CodexHookMutationRunner implements HookMutationRunner {
  const CodexHookMutationRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<HookMutationResult> setHookEnabled({
    required String hookKey,
    required bool enabled,
  }) {
    return _writeHookState(hookKey, {'enabled': enabled});
  }

  @override
  Future<HookMutationResult> trustHook({
    required String hookKey,
    required String currentHash,
  }) {
    final normalizedHash = currentHash.trim();
    if (normalizedHash.isEmpty) {
      throw ArgumentError.value(
        currentHash,
        'currentHash',
        'currentHash must not be blank',
      );
    }
    return _writeHookState(hookKey, {'trusted_hash': normalizedHash});
  }

  Future<HookMutationResult> _writeHookState(
    String hookKey,
    Map<String, Object?> state,
  ) async {
    final normalizedKey = hookKey.trim();
    if (normalizedKey.isEmpty) {
      throw ArgumentError.value(
        hookKey,
        'hookKey',
        'hookKey must not be blank',
      );
    }
    final response = await _client.batchWriteConfig(
      edits: [
        {
          'keyPath': 'hooks.state',
          'value': {normalizedKey: state},
          'mergeStrategy': 'upsert',
        },
      ],
      reloadUserConfig: true,
    );
    return HookMutationResult(raw: response);
  }
}
