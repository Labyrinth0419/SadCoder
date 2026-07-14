abstract interface class SkillMutationRunner {
  Future<SkillMutationResult> setSkillEnabled({
    String? path,
    String? name,
    required bool enabled,
  });
}

class SkillMutationResult {
  const SkillMutationResult({
    required this.effectiveEnabled,
    required this.raw,
  });

  factory SkillMutationResult.fromJson(Map<String, Object?> json) {
    final effectiveEnabled = json['effectiveEnabled'];
    if (effectiveEnabled is! bool) {
      throw const FormatException(
        'skills/config/write response is missing effectiveEnabled',
      );
    }
    return SkillMutationResult(
      effectiveEnabled: effectiveEnabled,
      raw: Map.unmodifiable(json),
    );
  }

  final bool effectiveEnabled;
  final Map<String, Object?> raw;
}
