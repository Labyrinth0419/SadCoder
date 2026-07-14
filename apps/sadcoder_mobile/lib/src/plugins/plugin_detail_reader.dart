import 'plugin_list_reader.dart';

abstract interface class PluginDetailReader {
  Future<PluginDetail> readPlugin({required PluginCatalogTarget target});
}

class PluginDetail {
  const PluginDetail({
    required this.plugin,
    required this.raw,
    this.skills = const [],
    this.marketplaceName,
    this.marketplacePath,
    this.description,
    this.readme,
  });

  factory PluginDetail.fromJson({
    required String pluginId,
    required Map<String, Object?> json,
  }) {
    final envelope = _objectMap(json['plugin']);
    final detailJson = envelope.isEmpty ? json : envelope;
    final summaryJson = _objectMap(detailJson['summary']);
    final plugin = PluginSummary.fromJson(
      summaryJson.isEmpty ? detailJson : summaryJson,
    );
    if (plugin == null) {
      throw FormatException('Plugin detail response missing plugin $pluginId.');
    }
    final marketplace = _objectMap(detailJson['marketplace']);
    return PluginDetail(
      plugin: plugin,
      skills: _list(
        detailJson['skills'],
      ).map(PluginSkillSummary.fromJson).nonNulls.toList(growable: false),
      marketplaceName:
          _stringValue(
            detailJson['marketplaceName'] ?? detailJson['marketplace_name'],
          ) ??
          _stringValue(json['marketplaceName'] ?? json['marketplace_name']) ??
          _stringValue(marketplace['name']),
      marketplacePath:
          _stringValue(
            detailJson['marketplacePath'] ?? detailJson['marketplace_path'],
          ) ??
          _stringValue(json['marketplacePath'] ?? json['marketplace_path']) ??
          _stringValue(marketplace['path']),
      description: _stringValue(
        detailJson['description'] ?? json['description'],
      ),
      readme: _stringValue(
        detailJson['readme'] ??
            detailJson['readmeMarkdown'] ??
            detailJson['readme_markdown'] ??
            detailJson['markdown'] ??
            json['readme'] ??
            json['readmeMarkdown'] ??
            json['readme_markdown'] ??
            json['markdown'],
      ),
      raw: Map.unmodifiable(json),
    );
  }

  final PluginSummary plugin;
  final List<PluginSkillSummary> skills;
  final String? marketplaceName;
  final String? marketplacePath;
  final String? description;
  final String? readme;
  final Map<String, Object?> raw;
}

class PluginSkillSummary {
  const PluginSkillSummary({
    required this.name,
    required this.enabled,
    required this.raw,
    this.description,
    this.shortDescription,
    this.path,
  });

  static PluginSkillSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    final name = _stringValue(map['name']);
    if (name == null) {
      return null;
    }
    return PluginSkillSummary(
      name: name,
      description: _stringValue(map['description']),
      shortDescription: _stringValue(
        map['shortDescription'] ?? map['short_description'],
      ),
      path: _stringValue(map['path']),
      enabled: map['enabled'] is bool ? map['enabled']! as bool : true,
      raw: map,
    );
  }

  final String name;
  final String? description;
  final String? shortDescription;
  final String? path;
  final bool enabled;
  final Map<String, Object?> raw;

  String get displayDescription => shortDescription ?? description ?? '';
}

List<Object?> _list(Object? value) => value is List ? value : const [];

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
