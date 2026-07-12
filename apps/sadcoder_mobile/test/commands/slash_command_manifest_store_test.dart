import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_manifest_store.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and loads a slash command manifest', () async {
    const store = SharedPreferencesSlashCommandManifestStore();
    final manifest = _manifest(command: 'remote-only');

    await store.saveManifest(
      profileId: 'profile-a',
      manifest: manifest,
      cachedAtMs: 123,
    );

    final loaded = await store.loadManifest(profileId: 'profile-a');

    expect(loaded?.source, 'test-agent');
    expect(loaded?.commands.single.command, 'remote-only');
  });

  test('separates cached manifests by profile and cwd', () async {
    const store = SharedPreferencesSlashCommandManifestStore();

    await store.saveManifest(
      profileId: 'profile-a',
      cwd: '/repo/a',
      manifest: _manifest(command: 'command-a'),
      cachedAtMs: 123,
    );
    await store.saveManifest(
      profileId: 'profile-a',
      cwd: '/repo/b',
      manifest: _manifest(command: 'command-b'),
      cachedAtMs: 456,
    );
    await store.saveManifest(
      profileId: 'profile-b',
      cwd: '/repo/a',
      manifest: _manifest(command: 'command-c'),
      cachedAtMs: 789,
    );

    final profileARepoA = await store.loadManifest(
      profileId: 'profile-a',
      cwd: '/repo/a',
    );
    final profileARepoB = await store.loadManifest(
      profileId: 'profile-a',
      cwd: '/repo/b',
    );
    final profileBRepoA = await store.loadManifest(
      profileId: 'profile-b',
      cwd: '/repo/a',
    );

    expect(profileARepoA?.commands.single.command, 'command-a');
    expect(profileARepoB?.commands.single.command, 'command-b');
    expect(profileBRepoA?.commands.single.command, 'command-c');
  });

  test('deletes all cached manifests for a profile', () async {
    const store = SharedPreferencesSlashCommandManifestStore();

    await store.saveManifest(
      profileId: 'profile-a',
      cwd: '/repo/a',
      manifest: _manifest(command: 'command-a'),
      cachedAtMs: 123,
    );
    await store.saveManifest(
      profileId: 'profile-a',
      cwd: '/repo/b',
      manifest: _manifest(command: 'command-b'),
      cachedAtMs: 456,
    );
    await store.saveManifest(
      profileId: 'profile-b',
      cwd: '/repo/a',
      manifest: _manifest(command: 'command-c'),
      cachedAtMs: 789,
    );

    await store.deleteProfileManifests('profile-a');

    expect(
      await store.loadManifest(profileId: 'profile-a', cwd: '/repo/a'),
      isNull,
    );
    expect(
      await store.loadManifest(profileId: 'profile-a', cwd: '/repo/b'),
      isNull,
    );
    expect(
      (await store.loadManifest(
        profileId: 'profile-b',
        cwd: '/repo/a',
      ))?.commands.single.command,
      'command-c',
    );
  });

  test('ignores malformed cached JSON', () async {
    SharedPreferences.setMockInitialValues({
      _cacheKey(profileId: 'profile-a'): 'not json',
    });
    const store = SharedPreferencesSlashCommandManifestStore();

    expect(await store.loadManifest(profileId: 'profile-a'), isNull);
  });
}

String _cacheKey({required String profileId, String cwd = ''}) {
  return 'slash.commandManifest.v1.'
      '${base64Url.encode(utf8.encode('$profileId\n$cwd'))}';
}

SlashCommandManifest _manifest({required String command}) {
  return SlashCommandManifest(
    schemaVersion: 1,
    source: 'test-agent',
    commands: [
      SlashCommandSpec(
        command: command,
        description: 'remote command',
        mappingType: SlashCommandMappingType.appServer,
        mappingTarget: 'test',
        phase: SlashCommandPhase.mvp,
      ),
    ],
  );
}
