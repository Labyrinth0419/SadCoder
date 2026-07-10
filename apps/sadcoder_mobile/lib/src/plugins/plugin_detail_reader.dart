import 'plugin_list_reader.dart';

abstract interface class PluginDetailReader {
  Future<PluginDetail> readPlugin({
    required String pluginId,
    List<String> cwds = const [],
  });
}

class PluginDetail {
  const PluginDetail({
    required this.plugin,
    required this.raw,
    this.marketplaceName,
    this.marketplacePath,
    this.readme,
  });

  factory PluginDetail.fromJson({
    required String pluginId,
    required Map<String, Object?> json,
  }) {
    final pluginJson = _objectMap(json['plugin']);
    final plugin = PluginSummary.fromJson(
      pluginJson.isEmpty ? json : pluginJson,
    );
    if (plugin == null) {
      throw FormatException('Plugin detail response missing plugin $pluginId.');
    }
    final marketplace = _objectMap(json['marketplace']);
    return PluginDetail(
      plugin: plugin,
      marketplaceName:
          _stringValue(json['marketplaceName'] ?? json['marketplace_name']) ??
          _stringValue(marketplace['name']),
      marketplacePath:
          _stringValue(json['marketplacePath'] ?? json['marketplace_path']) ??
          _stringValue(marketplace['path']),
      readme: _stringValue(
        json['readme'] ??
            json['readmeMarkdown'] ??
            json['readme_markdown'] ??
            json['markdown'],
      ),
      raw: Map.unmodifiable(json),
    );
  }

  final PluginSummary plugin;
  final String? marketplaceName;
  final String? marketplacePath;
  final String? readme;
  final Map<String, Object?> raw;
}

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
