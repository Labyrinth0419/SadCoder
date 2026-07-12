import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_debug_config_summary.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test('buildDebugConfigSummary renders values origins and layers', () async {
    final controller = CodexConfigSnapshotController(
      readerProvider: () => _FakeConfigSnapshotReader(
        CodexConfigSnapshot.fromJson({
          'config': {
            'model': 'gpt-5-codex',
            'approval_policy': {'type': 'on-request'},
          },
          'origins': {
            'model': {
              'name': {'type': 'user', 'file': '/home/me/.codex/config.toml'},
              'version': 'v1',
            },
            'approval_policy': {
              'name': {'type': 'project', 'dot_codex_folder': '/repo/.codex'},
            },
          },
          'layers': [
            {
              'version': 'v1',
              'name': {'type': 'user'},
              'config': {'model': 'gpt-5-codex'},
            },
          ],
        }),
      ),
    );
    addTearDown(controller.dispose);
    await controller.refresh(cwd: '/repo');

    final summary = buildDebugConfigSummary(l10n: l10n, controller: controller);

    expect(summary, contains('Debug config'));
    expect(summary, contains('Effective values'));
    expect(summary, contains('model: gpt-5-codex'));
    expect(summary, contains('approval_policy: on-request'));
    expect(summary, contains('Origins'));
    expect(summary, contains('model: user: /home/me/.codex/config.toml [v1]'));
    expect(summary, contains('approval_policy: project: /repo/.codex'));
    expect(summary, contains('Config layers: 1'));
    expect(summary, contains('Layer 1: v1'));
    expect(summary, contains('config: {"model":"gpt-5-codex"}'));
    expect(
      summary,
      contains('metadata: {"version":"v1","name":{"type":"user"}}'),
    );
  });

  test(
    'buildDebugConfigSummary renders unavailable and failed states',
    () async {
      expect(
        buildDebugConfigSummary(l10n: l10n, controller: null),
        'Debug config\nConnect to a host, then run /debug-config.',
      );

      final controller = CodexConfigSnapshotController(
        readerProvider: () => _FailingConfigSnapshotReader(),
      );
      addTearDown(controller.dispose);
      await controller.refresh();

      final summary = buildDebugConfigSummary(
        l10n: l10n,
        controller: controller,
      );

      expect(
        summary,
        contains('Failed to load debug config: Bad state: failed'),
      );
    },
  );

  test(
    'buildDebugConfigSummary localizes unknown config layer labels',
    () async {
      const zh = AppLocalizations(Locale('zh', 'CN'));
      final controller = CodexConfigSnapshotController(
        readerProvider: () => _FakeConfigSnapshotReader(
          CodexConfigSnapshot.fromJson({
            'config': const {},
            'layers': [const <String, Object?>{}],
          }),
        ),
      );
      addTearDown(controller.dispose);
      await controller.refresh(cwd: '/repo');

      final summary = buildDebugConfigSummary(l10n: zh, controller: controller);

      expect(summary, contains('第 1 层: 未知层'));
    },
  );
}

class _FakeConfigSnapshotReader implements CodexConfigSnapshotReader {
  const _FakeConfigSnapshotReader(this.snapshot);

  final CodexConfigSnapshot snapshot;

  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    return snapshot;
  }
}

class _FailingConfigSnapshotReader implements CodexConfigSnapshotReader {
  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    throw StateError('failed');
  }
}
