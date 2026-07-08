enum SshAuthType { password, privateKey }

class SshProfile {
  const SshProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.username,
    this.port = 22,
    this.authType = SshAuthType.password,
    this.password,
    this.privateKeyPem,
    this.passphrase,
    this.agentCommand = 'sadcoder-agent',
    this.defaultCwd,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final SshAuthType authType;
  final String? password;
  final String? privateKeyPem;
  final String? passphrase;
  final String agentCommand;
  final String? defaultCwd;

  String get endpoint => '$username@$host:$port';
}
