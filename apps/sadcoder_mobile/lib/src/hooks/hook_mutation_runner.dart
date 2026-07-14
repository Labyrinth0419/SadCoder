abstract interface class HookMutationRunner {
  Future<HookMutationResult> setHookEnabled({
    required String hookKey,
    required bool enabled,
  });

  Future<HookMutationResult> trustHook({
    required String hookKey,
    required String currentHash,
  });
}

class HookMutationResult {
  const HookMutationResult({required this.raw});

  final Map<String, Object?> raw;
}
