import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' as ed25519;
import 'package:pointycastle/pointycastle.dart' as pc;

enum SshKeyGenerationAlgorithm { ed25519, rsa }

class GeneratedSshKeyPair {
  const GeneratedSshKeyPair({
    required this.algorithm,
    required this.privateKeyPem,
    required this.publicKeyOpenSsh,
  });

  final SshKeyGenerationAlgorithm algorithm;
  final String privateKeyPem;
  final String publicKeyOpenSsh;
}

abstract interface class SshKeyGenerator {
  Future<GeneratedSshKeyPair> generate({
    required SshKeyGenerationAlgorithm algorithm,
    String comment = 'sadcoder-mobile',
  });
}

class DartSshKeyGenerator implements SshKeyGenerator {
  const DartSshKeyGenerator({this.rsaBits = 3072, this.randomSeedBytes = 32});

  final int rsaBits;
  final int randomSeedBytes;

  @override
  Future<GeneratedSshKeyPair> generate({
    required SshKeyGenerationAlgorithm algorithm,
    String comment = 'sadcoder-mobile',
  }) async {
    return switch (algorithm) {
      SshKeyGenerationAlgorithm.ed25519 => _generateEd25519(comment),
      SshKeyGenerationAlgorithm.rsa => _generateRsa(comment),
    };
  }

  GeneratedSshKeyPair _generateEd25519(String comment) {
    final signingKey = ed25519.SigningKey.fromSeed(_secureBytes(32));
    final pair = OpenSSHEd25519KeyPair(
      signingKey.verifyKey.asTypedList,
      signingKey.asTypedList,
      comment,
    );
    return _result(SshKeyGenerationAlgorithm.ed25519, pair, comment);
  }

  GeneratedSshKeyPair _generateRsa(String comment) {
    final random = pc.SecureRandom('Fortuna')
      ..seed(pc.KeyParameter(_secureBytes(randomSeedBytes)));
    final generator = pc.KeyGenerator('RSA')
      ..init(
        pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.from(65537), rsaBits, 64),
          random,
        ),
      );
    final keyPair = generator.generateKeyPair();
    final publicKey = keyPair.publicKey as pc.RSAPublicKey;
    final privateKey = keyPair.privateKey as pc.RSAPrivateKey;
    final p = privateKey.p!;
    final q = privateKey.q!;
    final pair = OpenSSHRsaKeyPair(
      publicKey.modulus!,
      publicKey.publicExponent!,
      privateKey.privateExponent!,
      q.modInverse(p),
      p,
      q,
      comment,
    );
    return _result(SshKeyGenerationAlgorithm.rsa, pair, comment);
  }

  GeneratedSshKeyPair _result(
    SshKeyGenerationAlgorithm algorithm,
    SSHKeyPair pair,
    String comment,
  ) {
    final publicKey = pair.toPublicKey().encode();
    return GeneratedSshKeyPair(
      algorithm: algorithm,
      privateKeyPem: pair.toPem(),
      publicKeyOpenSsh:
          '${pair.name} ${base64.encode(publicKey)} ${comment.trim()}'.trim(),
    );
  }

  Uint8List _secureBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList([
      for (var i = 0; i < length; i++) random.nextInt(256),
    ]);
  }
}
