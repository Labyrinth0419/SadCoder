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

  factory SshProfile.fromJson(Map<String, Object?> json) {
    return SshProfile(
      id: _stringValue(json['id']) ?? 'manual',
      name: _stringValue(json['name']) ?? '',
      host: _stringValue(json['host']) ?? '',
      port: _intValue(json['port']) ?? 22,
      username: _stringValue(json['username']) ?? '',
      authType: _authTypeValue(json['authType']),
      password: _stringValue(json['password']),
      privateKeyPem: _stringValue(json['privateKeyPem']),
      passphrase: _stringValue(json['passphrase']),
      agentCommand: _stringValue(json['agentCommand']) ?? 'sadcoder-agent',
      defaultCwd: _stringValue(json['defaultCwd']),
    );
  }

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

  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }
    final trimmedHost = host.trim();
    return trimmedHost.isEmpty ? endpoint : trimmedHost;
  }

  SshProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    SshAuthType? authType,
    String? password,
    String? privateKeyPem,
    String? passphrase,
    String? agentCommand,
    String? defaultCwd,
  }) {
    return SshProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      password: password ?? this.password,
      privateKeyPem: privateKeyPem ?? this.privateKeyPem,
      passphrase: passphrase ?? this.passphrase,
      agentCommand: agentCommand ?? this.agentCommand,
      defaultCwd: defaultCwd ?? this.defaultCwd,
    );
  }

  Map<String, Object?> toJson({bool includeSecrets = false}) => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'authType': authType.name,
    'agentCommand': agentCommand,
    if (defaultCwd != null && defaultCwd!.trim().isNotEmpty)
      'defaultCwd': defaultCwd,
    if (includeSecrets && password != null) 'password': password,
    if (includeSecrets && privateKeyPem != null) 'privateKeyPem': privateKeyPem,
    if (includeSecrets && passphrase != null) 'passphrase': passphrase,
  };
}

String sshProfileId({
  required String host,
  required int port,
  required String username,
  String? name,
}) {
  final normalizedHost = host.trim().toLowerCase();
  final normalizedUsername = username.trim().toLowerCase();
  if (normalizedHost.isEmpty || normalizedUsername.isEmpty) {
    return 'manual';
  }
  final endpointId = '$normalizedUsername@$normalizedHost:$port';
  final normalizedName = name?.trim().toLowerCase();
  if (normalizedName == null || normalizedName.isEmpty) {
    return endpointId;
  }
  return '$endpointId#${Uri.encodeComponent(normalizedName)}';
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

SshAuthType _authTypeValue(Object? value) {
  if (value is String) {
    for (final authType in SshAuthType.values) {
      if (authType.name == value) {
        return authType;
      }
    }
  }
  return SshAuthType.password;
}
