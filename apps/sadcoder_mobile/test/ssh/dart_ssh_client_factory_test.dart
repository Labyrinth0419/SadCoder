import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/ssh/dart_ssh_client_factory.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_key_generator.dart';

void main() {
  test('accepts an empty passphrase for an unencrypted private key', () async {
    final keyPair = await _generateEd25519KeyPair();

    final parsed = parseSshPrivateKey(keyPair.privateKeyPem, '');

    expect(parsed, hasLength(1));
  });

  test('preserves non-empty passphrases', () async {
    final keyPair = await _generateEd25519KeyPair();

    expect(
      () => parseSshPrivateKey(keyPair.privateKeyPem, 'passphrase'),
      throwsArgumentError,
    );
  });

  test('does not trim passphrases', () async {
    final keyPair = await _generateEd25519KeyPair();

    expect(
      () => parseSshPrivateKey(keyPair.privateKeyPem, ' '),
      throwsArgumentError,
    );
  });
}

Future<GeneratedSshKeyPair> _generateEd25519KeyPair() {
  return const DartSshKeyGenerator().generate(
    algorithm: SshKeyGenerationAlgorithm.ed25519,
  );
}
