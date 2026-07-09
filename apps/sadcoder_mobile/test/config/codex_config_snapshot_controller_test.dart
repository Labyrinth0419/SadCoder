import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';

void main() {
  test('refresh loads the current server config snapshot', () async {
    final reader = _FakeConfigSnapshotReader(
      snapshot: const CodexConfigSnapshot(
        config: {'model': 'gpt-5-codex'},
        origins: {},
        layers: [],
      ),
    );
    final controller = CodexConfigSnapshotController(
      readerProvider: () => reader,
    );
    addTearDown(controller.dispose);
    final statuses = <CodexConfigSnapshotStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.refresh(cwd: '/repo');

    expect(reader.cwdValues, ['/repo']);
    expect(controller.status, CodexConfigSnapshotStatus.loaded);
    expect(controller.snapshot?.displayValueFor('model'), 'gpt-5-codex');
    expect(statuses, [
      CodexConfigSnapshotStatus.loading,
      CodexConfigSnapshotStatus.loaded,
    ]);
  });

  test(
    'refresh without a reader returns to idle without clearing cache',
    () async {
      _FakeConfigSnapshotReader? reader = _FakeConfigSnapshotReader(
        snapshot: const CodexConfigSnapshot(
          config: {'model': 'gpt-5-codex'},
          origins: {},
          layers: [],
        ),
      );
      final controller = CodexConfigSnapshotController(
        readerProvider: () => reader,
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      reader = null;
      await controller.refresh();

      expect(controller.status, CodexConfigSnapshotStatus.idle);
      expect(controller.snapshot?.displayValueFor('model'), 'gpt-5-codex');
    },
  );

  test('refresh records failures', () async {
    final controller = CodexConfigSnapshotController(
      readerProvider: () => _FailingConfigSnapshotReader(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.status, CodexConfigSnapshotStatus.failed);
    expect(controller.error, isA<StateError>());
  });
}

class _FakeConfigSnapshotReader implements CodexConfigSnapshotReader {
  _FakeConfigSnapshotReader({required this.snapshot});

  final CodexConfigSnapshot snapshot;
  final cwdValues = <String?>[];

  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    cwdValues.add(cwd);
    return snapshot;
  }
}

class _FailingConfigSnapshotReader implements CodexConfigSnapshotReader {
  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) {
    throw StateError('config read failed');
  }
}
