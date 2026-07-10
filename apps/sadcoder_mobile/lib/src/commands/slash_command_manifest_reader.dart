import '../ssh/ssh_profile.dart';
import 'slash_command_registry.dart';

abstract interface class SlashCommandManifestReader {
  Future<SlashCommandManifest> readSlashCommands(SshProfile profile);
}
