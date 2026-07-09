import 'ssh_profile.dart';

abstract interface class SshProfileStore {
  Future<SshProfile?> loadLastProfile();

  Future<void> saveLastProfile(SshProfile profile);
}
