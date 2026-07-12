import '../ssh/ssh_profile.dart';
import 'agent_snapshot.dart';

abstract interface class AgentSnapshotReader {
  Future<AgentSnapshot> readSnapshot(SshProfile profile, {String? sinceCursor});
}
