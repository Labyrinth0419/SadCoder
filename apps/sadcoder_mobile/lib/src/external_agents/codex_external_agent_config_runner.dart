import '../protocol/codex_app_server_client.dart';
import 'external_agent_config_runner.dart';

class CodexExternalAgentConfigRunner implements ExternalAgentConfigRunner {
  const CodexExternalAgentConfigRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ExternalAgentConfigDetection> detect({
    bool includeHome = true,
    List<String> cwds = const [],
  }) async {
    final response = await _client.detectExternalAgentConfig(
      includeHome: includeHome,
      cwds: cwds,
    );
    return ExternalAgentConfigDetection.fromJson(response);
  }

  @override
  Future<List<ExternalAgentConfigImportHistory>> readImportHistories() async {
    final response = await _client.readExternalAgentConfigImportHistories();
    return _list(response['data'])
        .map(ExternalAgentConfigImportHistory.fromJson)
        .nonNulls
        .toList(growable: false);
  }

  @override
  Future<ExternalAgentConfigImportStart> startImport({
    required List<ExternalAgentConfigMigrationItem> items,
    String? source,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'items must not be empty');
    }
    final response = await _client.importExternalAgentConfig(
      migrationItems: [for (final item in items) item.toJson()],
      source: source,
    );
    return ExternalAgentConfigImportStart.fromJson(response);
  }
}

List<Object?> _list(Object? value) => value is List ? value : const [];
