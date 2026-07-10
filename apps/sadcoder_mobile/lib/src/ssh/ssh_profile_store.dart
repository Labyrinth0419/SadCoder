import 'ssh_profile.dart';

abstract interface class SshProfileStore {
  Future<SshProfile?> loadLastProfile();

  Future<void> saveLastProfile(SshProfile profile);
}

abstract interface class SshProfileListStore implements SshProfileStore {
  Future<List<SshProfile>> loadProfiles();

  Future<void> saveProfile(SshProfile profile);

  Future<void> deleteProfile(String profileId);
}
