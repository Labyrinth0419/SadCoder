import 'codex_config_snapshot.dart';

abstract interface class CodexConfigSnapshotReader {
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  });
}
