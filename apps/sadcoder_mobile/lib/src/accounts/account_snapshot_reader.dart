abstract interface class AccountSnapshotReader {
  Future<AccountSnapshot> readAccount({bool refreshToken = false});
}

class AccountSnapshot {
  const AccountSnapshot({
    required this.account,
    required this.requiresOpenaiAuth,
  });

  factory AccountSnapshot.fromJson(Map<String, Object?> json) {
    return AccountSnapshot(
      account: AccountSummary.fromJson(json['account']),
      requiresOpenaiAuth:
          _boolField(json, ['requiresOpenaiAuth', 'requires_openai_auth']) ??
          false,
    );
  }

  final AccountSummary? account;
  final bool requiresOpenaiAuth;

  bool get isAuthenticated => account != null;
}

class AccountSummary {
  const AccountSummary({
    required this.type,
    this.email,
    this.planType,
    this.credentialSource,
  });

  static AccountSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    final type = _stringValue(map['type']);
    if (type == null) {
      return null;
    }
    return AccountSummary(
      type: type,
      email: _nullableStringValue(map['email']),
      planType: _stringField(map, ['planType', 'plan_type']),
      credentialSource: _stringField(map, [
        'credentialSource',
        'credential_source',
      ]),
    );
  }

  final String type;
  final String? email;
  final String? planType;
  final String? credentialSource;

  String get label {
    return switch (type) {
      'apiKey' || 'api_key' => 'API key',
      'chatgpt' => _chatGptLabel,
      'amazonBedrock' || 'amazon_bedrock' => _amazonBedrockLabel,
      _ => type,
    };
  }

  String get _chatGptLabel {
    final parts = <String>['ChatGPT'];
    if (_hasText(email)) {
      parts.add(email!.trim());
    }
    if (_hasText(planType)) {
      parts.add(planType!.trim());
    }
    return parts.join(' / ');
  }

  String get _amazonBedrockLabel {
    if (_hasText(credentialSource)) {
      return 'Amazon Bedrock / ${credentialSource!.trim()}';
    }
    return 'Amazon Bedrock';
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String? _stringField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _stringValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

String? _nullableStringValue(Object? value) {
  if (value == null) {
    return null;
  }
  return _stringValue(value);
}

bool? _boolValue(Object? value) => value is bool ? value : null;

bool? _boolField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _boolValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
