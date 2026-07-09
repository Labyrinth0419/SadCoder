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
      requiresOpenaiAuth: json['requiresOpenaiAuth'] == true,
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
    if (value is! Map) {
      return null;
    }
    final map = value.map((key, value) => MapEntry(key.toString(), value));
    final type = _stringValue(map['type']);
    if (type == null) {
      return null;
    }
    return AccountSummary(
      type: type,
      email: _nullableStringValue(map['email']),
      planType: _stringValue(map['planType']),
      credentialSource: _stringValue(map['credentialSource']),
    );
  }

  final String type;
  final String? email;
  final String? planType;
  final String? credentialSource;

  String get label {
    return switch (type) {
      'apiKey' => 'API key',
      'chatgpt' => _chatGptLabel,
      'amazonBedrock' => _amazonBedrockLabel,
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

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String? _nullableStringValue(Object? value) {
  if (value == null) {
    return null;
  }
  return _stringValue(value);
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
