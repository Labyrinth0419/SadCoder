import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sadcoder_mobile/src/ssh/shared_preferences_ssh_profile_store.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  test('saves and loads the last profile without secrets', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesSshProfileStore();

    await store.saveLastProfile(
      const SshProfile(
        id: 'manual',
        name: 'Dev server',
        host: 'srv.dev',
        port: 2200,
        username: 'alice',
        authType: SshAuthType.privateKey,
        password: 'secret',
        privateKeyPem: 'private-key',
        passphrase: 'passphrase',
        agentCommand: 'sadcoder-agent --verbose',
        defaultCwd: '/repo',
      ),
    );

    final loaded = await store.loadLastProfile();

    expect(loaded?.name, 'Dev server');
    expect(loaded?.host, 'srv.dev');
    expect(loaded?.port, 2200);
    expect(loaded?.username, 'alice');
    expect(loaded?.authType, SshAuthType.privateKey);
    expect(loaded?.agentCommand, 'sadcoder-agent --verbose');
    expect(loaded?.defaultCwd, '/repo');
    expect(loaded?.password, isNull);
    expect(loaded?.privateKeyPem, isNull);
    expect(loaded?.passphrase, isNull);
  });

  test('returns null for missing or malformed data', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await SharedPreferencesSshProfileStore().loadLastProfile(), isNull);

    SharedPreferences.setMockInitialValues({
      'ssh.lastProfile.v1': jsonEncode([]),
    });
    expect(await SharedPreferencesSshProfileStore().loadLastProfile(), isNull);
  });

  test('saves and loads multiple profiles without secrets', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesSshProfileStore();

    await store.saveProfile(
      const SshProfile(
        id: 'alice@srv.dev:22',
        name: 'Dev',
        host: 'srv.dev',
        username: 'alice',
        password: 'secret',
      ),
    );
    await store.saveProfile(
      const SshProfile(
        id: 'root@prod.dev:2200',
        name: 'Prod',
        host: 'prod.dev',
        port: 2200,
        username: 'root',
        authType: SshAuthType.privateKey,
        privateKeyPem: 'private-key',
      ),
    );

    final profiles = await store.loadProfiles();
    final lastProfile = await store.loadLastProfile();

    expect(profiles.map((profile) => profile.id), [
      'root@prod.dev:2200',
      'alice@srv.dev:22',
    ]);
    expect(profiles.first.privateKeyPem, isNull);
    expect(profiles.last.password, isNull);
    expect(lastProfile?.id, 'root@prod.dev:2200');
  });

  test('loadProfiles falls back to the legacy last profile key', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesSshProfileStore();
    await store.saveLastProfile(
      const SshProfile(
        id: 'manual',
        name: 'Dev',
        host: 'srv.dev',
        username: 'alice',
      ),
    );

    final profiles = await store.loadProfiles();

    expect(profiles.single.id, 'manual');
  });

  test('deletes saved profiles and updates the last profile', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesSshProfileStore();
    await store.saveProfile(
      const SshProfile(
        id: 'alice@srv.dev:22',
        name: 'Dev',
        host: 'srv.dev',
        username: 'alice',
      ),
    );
    await store.saveProfile(
      const SshProfile(
        id: 'root@prod.dev:2200',
        name: 'Prod',
        host: 'prod.dev',
        port: 2200,
        username: 'root',
      ),
    );

    await store.deleteProfile('root@prod.dev:2200');

    expect((await store.loadProfiles()).map((profile) => profile.id), [
      'alice@srv.dev:22',
    ]);
    expect((await store.loadLastProfile())?.id, 'alice@srv.dev:22');

    await store.deleteProfile('alice@srv.dev:22');

    expect(await store.loadProfiles(), isEmpty);
    expect(await store.loadLastProfile(), isNull);
  });
}
