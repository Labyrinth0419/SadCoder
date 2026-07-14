import '../protocol/codex_app_server_client.dart';
import 'plugin_list_reader.dart';
import 'plugin_skill_reader.dart';

class CodexPluginSkillReader implements PluginSkillReader {
  const CodexPluginSkillReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<PluginSkillDocument> readSkill({
    required PluginCatalogTarget target,
    required String skillName,
  }) async {
    final remoteMarketplaceName = target.remoteMarketplaceName;
    if (remoteMarketplaceName == null) {
      throw StateError(
        'plugin/skill/read only supports remote catalog plugins.',
      );
    }
    final normalizedSkillName = skillName.trim();
    if (normalizedSkillName.isEmpty) {
      throw ArgumentError.value(skillName, 'skillName', 'must not be blank');
    }
    final result = await _client.readPluginSkill(
      remoteMarketplaceName: remoteMarketplaceName,
      remotePluginId: target.requestPluginName,
      skillName: normalizedSkillName,
    );
    return PluginSkillDocument(
      pluginId: target.plugin.id,
      skillName: normalizedSkillName,
      contents: result['contents'] is String
          ? result['contents']! as String
          : null,
      raw: Map.unmodifiable(result),
    );
  }
}
