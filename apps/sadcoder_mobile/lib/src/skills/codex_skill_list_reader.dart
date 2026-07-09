import '../protocol/codex_app_server_client.dart';
import 'skill_list_reader.dart';

class CodexSkillListReader implements SkillListReader {
  const CodexSkillListReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<SkillListPage> listSkills({
    List<String> cwds = const [],
    bool forceReload = false,
  }) async {
    final response = await _client.listSkills(
      cwds: cwds,
      forceReload: forceReload,
    );
    return SkillListPage.fromJson(response);
  }
}
