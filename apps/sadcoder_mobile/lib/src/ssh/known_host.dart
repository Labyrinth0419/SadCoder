class KnownHostEntry {
  const KnownHostEntry({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprintSha256,
    required this.verifiedAt,
  });

  factory KnownHostEntry.fromJson(Map<String, Object?> json) {
    return KnownHostEntry(
      host: _stringValue(json['host']) ?? '',
      port: _intValue(json['port']) ?? 22,
      keyType: _stringValue(json['keyType']) ?? '',
      fingerprintSha256: _stringValue(json['fingerprintSha256']) ?? '',
      verifiedAt: DateTime.fromMillisecondsSinceEpoch(
        _intValue(json['verifiedAtMs']) ?? 0,
        isUtc: true,
      ),
    );
  }

  final String host;
  final int port;
  final String keyType;
  final String fingerprintSha256;
  final DateTime verifiedAt;

  String get endpoint => '$host:$port';

  bool matches(SshHostKeyChallenge challenge) {
    return _normalizeHost(host) == _normalizeHost(challenge.host) &&
        port == challenge.port &&
        keyType == challenge.keyType &&
        fingerprintSha256 == challenge.fingerprintSha256;
  }

  Map<String, Object?> toJson() => {
    'host': host,
    'port': port,
    'keyType': keyType,
    'fingerprintSha256': fingerprintSha256,
    'verifiedAtMs': verifiedAt.millisecondsSinceEpoch,
  };
}

class SshHostKeyChallenge {
  const SshHostKeyChallenge({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprintSha256,
  });

  final String host;
  final int port;
  final String keyType;
  final String fingerprintSha256;

  String get endpoint => '$host:$port';

  KnownHostEntry toKnownHostEntry(DateTime verifiedAt) {
    return KnownHostEntry(
      host: _normalizeHost(host),
      port: port,
      keyType: keyType,
      fingerprintSha256: fingerprintSha256,
      verifiedAt: verifiedAt.toUtc(),
    );
  }
}

abstract interface class KnownHostStore {
  Future<KnownHostEntry?> readKnownHost({
    required String host,
    required int port,
    required String keyType,
  });

  Future<KnownHostEntry?> readKnownHostForEndpoint({
    required String host,
    required int port,
  });

  Future<void> saveKnownHost(KnownHostEntry entry);
}

String knownHostStoreKey({
  required String host,
  required int port,
  required String keyType,
}) {
  return '${_normalizeHost(host)}:$port:$keyType';
}

String knownHostEndpointKey({required String host, required int port}) {
  return '${_normalizeHost(host)}:$port';
}

String _normalizeHost(String host) => host.trim().toLowerCase();

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
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
