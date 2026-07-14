import 'plugin_list_reader.dart';

abstract interface class PluginMutationRunner {
  Future<PluginMutationResult> installPlugin({
    required PluginCatalogTarget target,
  });

  Future<PluginMutationResult> uninstallPlugin({required String pluginId});
}

enum PluginMutationOperation { install, uninstall }

class PluginMutationResult {
  const PluginMutationResult({
    required this.operation,
    required this.pluginId,
    required this.raw,
    this.message,
  });

  factory PluginMutationResult.fromJson({
    required PluginMutationOperation operation,
    required String pluginId,
    required Map<String, Object?> json,
  }) {
    return PluginMutationResult(
      operation: operation,
      pluginId: pluginId,
      message: _stringValue(json['message']),
      raw: Map.unmodifiable(json),
    );
  }

  final PluginMutationOperation operation;
  final String pluginId;
  final String? message;
  final Map<String, Object?> raw;
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
