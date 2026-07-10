abstract interface class McpServerOAuthRunner {
  Future<McpServerOAuthLoginResult> startOAuthLogin({
    required String serverName,
  });
}

class McpServerOAuthLoginResult {
  const McpServerOAuthLoginResult({
    required this.serverName,
    required this.raw,
    this.message,
    this.authorizationUrl,
    this.verificationUri,
    this.verificationUriComplete,
    this.userCode,
  });

  factory McpServerOAuthLoginResult.fromJson({
    required String serverName,
    required Map<String, Object?> json,
  }) {
    return McpServerOAuthLoginResult(
      serverName: _stringValue(json['serverName']) ?? serverName,
      message: _stringValue(json['message']),
      authorizationUrl:
          _stringValue(json['authorizationUrl']) ??
          _stringValue(json['authUrl']) ??
          _stringValue(json['loginUrl']) ??
          _stringValue(json['url']),
      verificationUri:
          _stringValue(json['verificationUri']) ??
          _stringValue(json['verificationUrl']),
      verificationUriComplete:
          _stringValue(json['verificationUriComplete']) ??
          _stringValue(json['verificationUrlComplete']),
      userCode: _stringValue(json['userCode']),
      raw: Map.unmodifiable(json),
    );
  }

  final String serverName;
  final String? message;
  final String? authorizationUrl;
  final String? verificationUri;
  final String? verificationUriComplete;
  final String? userCode;
  final Map<String, Object?> raw;

  String? get bestUrl =>
      verificationUriComplete ?? verificationUri ?? authorizationUrl;
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
