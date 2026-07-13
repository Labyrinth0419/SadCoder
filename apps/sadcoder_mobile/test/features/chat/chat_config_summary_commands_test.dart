import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_config_summary_commands.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test(
    'debug config command refreshes first cwd and renders summary',
    () async {
      final reader = _RecordingConfigSnapshotReader(
        snapshot: CodexConfigSnapshot.fromJson({
          'config': {'model': 'gpt-5-codex'},
          'origins': {
            'model': {
              'name': {'type': 'project', 'dot_codex_folder': '/repo/.codex'},
            },
          },
          'layers': const [],
        }),
      );
      final controller = CodexConfigSnapshotController(
        readerProvider: () => reader,
      );
      addTearDown(controller.dispose);

      final summary = await buildDebugConfigSummaryFromCommand(
        l10n: l10n,
        controller: controller,
        cwds: const ['/repo', '/other'],
        arguments: '',
      );

      expect(summary, contains('Debug config'));
      expect(summary, contains('model: gpt-5-codex'));
      expect(reader.calls, hasLength(1));
      expect(reader.calls.single.cwd, '/repo');
    },
  );

  test('debug config command rejects unsupported arguments', () async {
    final reader = _RecordingConfigSnapshotReader(
      snapshot: const CodexConfigSnapshot(config: {}, origins: {}, layers: []),
    );
    final controller = CodexConfigSnapshotController(
      readerProvider: () => reader,
    );
    addTearDown(controller.dispose);

    final summary = await buildDebugConfigSummaryFromCommand(
      l10n: l10n,
      controller: controller,
      cwds: const ['/repo'],
      arguments: 'verbose',
    );

    expect(summary, isNull);
    expect(reader.calls, isEmpty);
  });

  test(
    'experimental command refreshes without cwd and reports failures',
    () async {
      final reader = _RecordingConfigSnapshotReader(
        snapshot: const CodexConfigSnapshot(
          config: {},
          origins: {},
          layers: [],
        ),
        error: StateError('boom'),
      );
      final controller = CodexConfigSnapshotController(
        readerProvider: () => reader,
      );
      addTearDown(controller.dispose);

      final summary = await buildExperimentalSummaryFromCommand(
        l10n: l10n,
        controller: controller,
        cwds: const [],
        arguments: '',
      );

      expect(summary, contains('Experimental'));
      expect(summary, contains('Failed to load experimental config'));
      expect(summary, contains('boom'));
      expect(reader.calls.single.cwd, isNull);
    },
  );

  test(
    'memories command passes thread raw and renders memory config',
    () async {
      final reader = _RecordingConfigSnapshotReader(
        snapshot: CodexConfigSnapshot.fromJson({
          'config': {
            'memories': {'use_memories': true},
          },
          'origins': {
            'memories': {'name': 'user'},
          },
          'layers': const [],
        }),
      );
      final controller = CodexConfigSnapshotController(
        readerProvider: () => reader,
      );
      addTearDown(controller.dispose);

      final summary = await buildMemoriesSummaryFromCommand(
        l10n: l10n,
        controller: controller,
        cwds: const ['/repo'],
        threadRaw: const {'memoryMode': 'project'},
        arguments: '',
      );

      expect(summary, contains('Memories'));
      expect(summary, contains('Thread memory mode: project'));
      expect(summary, contains('use_memories: true'));
      expect(reader.calls.single.cwd, '/repo');
    },
  );

  test(
    'config summary commands render unavailable without a controller',
    () async {
      final summary = await buildExperimentalSummaryFromCommand(
        l10n: l10n,
        controller: null,
        cwds: const ['/repo'],
        arguments: '',
      );

      expect(summary, contains('Connect to a host'));
    },
  );
}

class _RecordingConfigSnapshotReader implements CodexConfigSnapshotReader {
  _RecordingConfigSnapshotReader({required this.snapshot, this.error});

  final CodexConfigSnapshot snapshot;
  final Object? error;
  final calls = <({bool includeLayers, String? cwd})>[];

  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    calls.add((includeLayers: includeLayers, cwd: cwd));
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return snapshot;
  }
}
