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
}
