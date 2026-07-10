import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_key_generator.dart';

void main() {
  test('generates parseable OpenSSH ED25519 key pairs', () async {
    const generator = DartSshKeyGenerator();

    final result = await generator.generate(
      algorithm: SshKeyGenerationAlgorithm.ed25519,
      comment: 'unit@example',
    );

    expect(result.algorithm, SshKeyGenerationAlgorithm.ed25519);
    expect(result.privateKeyPem, contains('BEGIN OPENSSH PRIVATE KEY'));
    expect(result.publicKeyOpenSsh, startsWith('ssh-ed25519 '));
    expect(result.publicKeyOpenSsh, endsWith(' unit@example'));
    _expectPublicKeyMatchesPrivateKey(result);
  });

  test('generates parseable OpenSSH RSA key pairs', () async {
    const generator = DartSshKeyGenerator(rsaBits: 1024);

    final result = await generator.generate(
      algorithm: SshKeyGenerationAlgorithm.rsa,
      comment: 'unit@example',
    );

    expect(result.algorithm, SshKeyGenerationAlgorithm.rsa);
    expect(result.privateKeyPem, contains('BEGIN OPENSSH PRIVATE KEY'));
    expect(result.publicKeyOpenSsh, startsWith('ssh-rsa '));
    expect(result.publicKeyOpenSsh, endsWith(' unit@example'));
    _expectPublicKeyMatchesPrivateKey(result);
  });
}

void _expectPublicKeyMatchesPrivateKey(GeneratedSshKeyPair result) {
  final parsed = SSHKeyPair.fromPem(result.privateKeyPem).single;
  final publicKeyBlob = parsed.toPublicKey().encode();

  expect(
    result.publicKeyOpenSsh,
    startsWith('${parsed.name} ${base64.encode(publicKeyBlob)} '),
  );
}
