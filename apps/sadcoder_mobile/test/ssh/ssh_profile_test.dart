import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  test('displayName prefers alias and falls back to endpoint', () {
    const aliased = SshProfile(
      id: 'dev',
      name: 'Dev box',
      host: '192.0.2.10',
      username: 'alice',
    );
    const unnamed = SshProfile(
      id: 'raw',
      name: ' ',
      host: '192.0.2.11',
      username: 'bob',
      port: 2200,
    );

    expect(aliased.displayName, 'Dev box');
    expect(unnamed.displayName, 'bob@192.0.2.11:2200');
  });
}
