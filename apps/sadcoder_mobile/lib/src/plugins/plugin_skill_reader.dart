import 'plugin_list_reader.dart';

abstract interface class PluginSkillReader {
  Future<PluginSkillDocument> readSkill({
    required PluginCatalogTarget target,
    required String skillName,
  });
}

class PluginSkillDocument {
  const PluginSkillDocument({
    required this.pluginId,
    required this.skillName,
    required this.raw,
    this.contents,
  });

  final String pluginId;
  final String skillName;
  final String? contents;
  final Map<String, Object?> raw;
}
