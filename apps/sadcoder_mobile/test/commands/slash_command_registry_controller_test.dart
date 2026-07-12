import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_manifest_reader.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_manifest_store.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_registry.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_registry_controller.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  test('loads remote slash command manifest for the active profile', () async {
    final reader = _FakeSlashCommandManifestReader(
      manifest: _manifest(
        command: 'remote-only',
        aliases: const ['ro'],
        description: 'remote command from agent manifest',
      ),
    );
    final controller = SlashCommandRegistryController(
      readerProvider: () => reader,
    );
    addTearDown(controller.dispose);

    await controller.refresh(_profile);

    expect(reader.profiles, [_profile]);
    expect(controller.status, SlashCommandRegistryLoadStatus.loaded);
    expect(controller.manifest?.source, 'test-agent');
    expect(controller.registry.find('/ro')?.command, 'remote-only');
  });

  test('saves a successfully loaded remote manifest to cache', () async {
    final manifest = _manifest(command: 'remote-only');
    final cacheStore = _RecordingSlashCommandManifestStore();
    final controller = SlashCommandRegistryController(
      readerProvider: () => _FakeSlashCommandManifestReader(manifest: manifest),
      cacheStore: cacheStore,
      cwdProvider: () => '/repo',
    );
    addTearDown(controller.dispose);

    await controller.refresh(_profile);

    expect(cacheStore.saved, hasLength(1));
    expect(cacheStore.saved.single.profileId, _profile.id);
    expect(cacheStore.saved.single.cwd, '/repo');
    expect(
      cacheStore.saved.single.manifest.commands.single.command,
      'remote-only',
    );
    expect(cacheStore.saved.single.cachedAtMs, greaterThan(0));
  });

  test(
    'keeps the built-in registry when remote manifest loading fails',
    () async {
      final controller = SlashCommandRegistryController(
        readerProvider: () => _FailingSlashCommandManifestReader(),
      );
      addTearDown(controller.dispose);

      await controller.refresh(_profile);

      expect(controller.status, SlashCommandRegistryLoadStatus.failed);
      expect(controller.error, isA<StateError>());
      expect(controller.registry.find('/model')?.command, 'model');
      expect(controller.registry.find('/remote-only'), isNull);
    },
  );

  test('uses cached manifest when remote manifest loading fails', () async {
    final cacheStore = _RecordingSlashCommandManifestStore(
      manifests: {
        'local\n/repo': _manifest(
          command: 'cached-only',
          aliases: const ['co'],
          description: 'cached command from previous connection',
        ),
      },
    );
    final controller = SlashCommandRegistryController(
      readerProvider: () => _FailingSlashCommandManifestReader(),
      cacheStore: cacheStore,
      cwdProvider: () => '/repo',
    );
    addTearDown(controller.dispose);

    await controller.refresh(_profile);

    expect(controller.status, SlashCommandRegistryLoadStatus.cached);
    expect(controller.error, isA<StateError>());
    expect(controller.manifest?.source, 'test-agent');
    expect(controller.registry.find('/co')?.command, 'cached-only');
    expect(controller.registry.find('/model'), isNull);
  });

  test(
    'does not reload an already loaded manifest for the same profile',
    () async {
      final reader = _FakeSlashCommandManifestReader(
        manifest: _manifest(command: 'remote-only'),
      );
      final controller = SlashCommandRegistryController(
        readerProvider: () => reader,
      );
      addTearDown(controller.dispose);

      await controller.refresh(_profile);
      await controller.refresh(_profile);

      expect(reader.profiles, [_profile]);
    },
  );

  test(
    'reset restores built-in registry and ignores stale refreshes',
    () async {
      final completer = Completer<SlashCommandManifest>();
      final controller = SlashCommandRegistryController(
        readerProvider: () => _CompleterSlashCommandManifestReader(completer),
      );
      addTearDown(controller.dispose);

      final refresh = controller.refresh(_profile);
      controller.reset();
      completer.complete(_manifest(command: 'remote-only'));
      await refresh;

      expect(controller.status, SlashCommandRegistryLoadStatus.builtIn);
      expect(controller.registry.find('/remote-only'), isNull);
      expect(controller.registry.find('/model')?.command, 'model');
    },
  );
}

class _RecordingSlashCommandManifestStore implements SlashCommandManifestStore {
  _RecordingSlashCommandManifestStore({
    Map<String, SlashCommandManifest>? manifests,
  }) : manifests = manifests ?? {};

  final Map<String, SlashCommandManifest> manifests;
  final saved = <_SavedSlashCommandManifest>[];

  @override
  Future<SlashCommandManifest?> loadManifest({
    required String profileId,
    String? cwd,
  }) async {
    return manifests['$profileId\n${cwd ?? ''}'];
  }

  @override
  Future<void> saveManifest({
    required String profileId,
    String? cwd,
    required SlashCommandManifest manifest,
    required int cachedAtMs,
  }) async {
    saved.add(
      _SavedSlashCommandManifest(
        profileId: profileId,
        cwd: cwd,
        manifest: manifest,
        cachedAtMs: cachedAtMs,
      ),
    );
  }
}

class _SavedSlashCommandManifest {
  const _SavedSlashCommandManifest({
    required this.profileId,
    required this.cwd,
    required this.manifest,
    required this.cachedAtMs,
  });

  final String profileId;
  final String? cwd;
  final SlashCommandManifest manifest;
  final int cachedAtMs;
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

SlashCommandManifest _manifest({
  required String command,
  List<String> aliases = const [],
  String description = 'remote command',
}) {
  return SlashCommandManifest(
    schemaVersion: 1,
    source: 'test-agent',
    commands: [
      SlashCommandSpec(
        command: command,
        aliases: aliases,
        description: description,
        mappingType: SlashCommandMappingType.appServer,
        mappingTarget: 'test',
        phase: SlashCommandPhase.mvp,
      ),
    ],
  );
}

class _FakeSlashCommandManifestReader implements SlashCommandManifestReader {
  _FakeSlashCommandManifestReader({required this.manifest});

  final SlashCommandManifest manifest;
  final profiles = <SshProfile>[];

  @override
  Future<SlashCommandManifest> readSlashCommands(SshProfile profile) async {
    profiles.add(profile);
    return manifest;
  }
}

class _FailingSlashCommandManifestReader implements SlashCommandManifestReader {
  @override
  Future<SlashCommandManifest> readSlashCommands(SshProfile profile) {
    throw StateError('manifest unavailable');
  }
}

class _CompleterSlashCommandManifestReader
    implements SlashCommandManifestReader {
  const _CompleterSlashCommandManifestReader(this.completer);

  final Completer<SlashCommandManifest> completer;

  @override
  Future<SlashCommandManifest> readSlashCommands(SshProfile profile) {
    return completer.future;
  }
}
