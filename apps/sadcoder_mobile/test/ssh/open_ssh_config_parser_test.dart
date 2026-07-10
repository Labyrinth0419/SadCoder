import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/ssh/open_ssh_config_parser.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  test('parses common OpenSSH host config fields into SSH profiles', () {
    const config = '''
Host *
  User default-user
  Port 2200

Host dev
  HostName dev.example.com
  User alice
  IdentityFile ~/.ssh/id_ed25519

Host prod prod-short
  HostName prod.example.com
  Port 22
''';

    final profiles = const OpenSshConfigParser().parseProfiles(config);

    expect(profiles, hasLength(3));
    expect(profiles.first.id, 'alice@dev.example.com:2200#dev');
    expect(profiles.first.name, 'dev');
    expect(profiles.first.host, 'dev.example.com');
    expect(profiles.first.port, 2200);
    expect(profiles.first.username, 'alice');
    expect(profiles.first.authType, SshAuthType.privateKey);
    expect(profiles[1].id, 'default-user@prod.example.com:22#prod');
    expect(profiles[1].name, 'prod');
    expect(profiles[1].username, 'default-user');
    expect(profiles[1].authType, SshAuthType.password);
    expect(profiles.last.id, 'default-user@prod.example.com:22#prod-short');
    expect(profiles.last.name, 'prod-short');
  });

  test('preserves multiple aliases for the same endpoint', () {
    const config = '''
Host dev staging
  HostName 10.0.0.12
  User alice
''';

    final profiles = const OpenSshConfigParser().parseProfiles(config);

    expect(profiles.map((profile) => profile.name), ['dev', 'staging']);
    expect(profiles.map((profile) => profile.host), ['10.0.0.12', '10.0.0.12']);
    expect(profiles.map((profile) => profile.id), [
      'alice@10.0.0.12:22#dev',
      'alice@10.0.0.12:22#staging',
    ]);
  });

  test(
    'skips wildcard hosts, tokenized hostnames, and entries without user',
    () {
      const config = '''
Host *.internal
  User ops

Host generated
  HostName %h.example.com
  User alice

Host missing-user
  HostName missing.example.com
''';

      final profiles = const OpenSshConfigParser().parseProfiles(config);

      expect(profiles, isEmpty);
    },
  );

  test('parses quoted values and inline comments', () {
    const config = '''
Host "quoted dev" # comment
  HostName "quoted.example.com"
  User 'dev user'
  Port 2222 # comment
''';

    final profiles = const OpenSshConfigParser().parseProfiles(config);

    expect(profiles.single.name, 'quoted dev');
    expect(profiles.single.host, 'quoted.example.com');
    expect(profiles.single.username, 'dev user');
    expect(profiles.single.port, 2222);
  });

  test('extracts PEM private key blocks from imported files', () {
    const fileText = '''
notes before
-----BEGIN OPENSSH PRIVATE KEY-----
abc
-----END OPENSSH PRIVATE KEY-----
notes after
''';

    expect(
      parseSshPrivateKeyPem(fileText),
      '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----',
    );
  });

  test('rejects files without private key blocks', () {
    expect(
      () => parseSshPrivateKeyPem('not a key'),
      throwsA(isA<FormatException>()),
    );
  });
}
