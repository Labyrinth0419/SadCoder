import '../protocol/codex_app_server_client.dart';
import '../ssh/ssh_profile.dart';
import 'slash_command_manifest_reader.dart';
import 'slash_command_registry.dart';

class CodexSlashCommandManifestReader implements SlashCommandManifestReader {
  const CodexSlashCommandManifestReader(this._client);

  final CodexAppServerClient _client;

  @override
  Future<SlashCommandManifest> readSlashCommands(SshProfile profile) async {
    final response = await _client.agentSlashCommandsList();
    return SlashCommandManifest.fromJson(response);
  }
}
