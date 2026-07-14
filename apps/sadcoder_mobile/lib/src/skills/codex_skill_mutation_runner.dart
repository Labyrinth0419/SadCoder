import '../protocol/codex_app_server_client.dart';
import 'skill_mutation_runner.dart';

class CodexSkillMutationRunner implements SkillMutationRunner {
  const CodexSkillMutationRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<SkillMutationResult> setSkillEnabled({
    String? path,
    String? name,
    required bool enabled,
  }) async {
    final result = await _client.writeSkillConfig(
      path: path,
      name: name,
      enabled: enabled,
    );
    return SkillMutationResult.fromJson(result);
  }
}
