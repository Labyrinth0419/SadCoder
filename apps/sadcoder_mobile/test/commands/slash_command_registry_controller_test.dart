import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_manifest_reader.dart';
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
