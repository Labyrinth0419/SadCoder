import 'dart:convert';

class LogRedactor {
  const LogRedactor({this.replacement = '[REDACTED]'});

  final String replacement;

  static const defaultRedactor = LogRedactor();

  Object? redactValue(Object? value) {
    return switch (value) {
      Map<Object?, Object?> map => {
        for (final entry in map.entries)
          entry.key: _isSensitiveKey(entry.key)
              ? replacement
              : redactValue(entry.value),
      },
      Iterable<Object?> values => [
        for (final value in values) redactValue(value),
      ],
      _ => value,
    };
  }

  String redactJsonString(String text) {
    try {
      return jsonEncode(redactValue(jsonDecode(text)));
    } on FormatException {
      return redactText(text);
    }
  }

  String redactText(String text) {
    var redacted = text;
    redacted = redacted.replaceAll(_privateKeyBlockPattern, replacement);
    redacted = redacted.replaceAllMapped(
      _cookieHeaderPattern,
      (match) => '${match.group(1)}${match.group(2)}$replacement',
    );
    redacted = redacted.replaceAllMapped(
      _quotedJsonStringPattern,
      (match) =>
          '${match.group(1)}${match.group(2)}$replacement${match.group(2)}',
    );
    redacted = redacted.replaceAllMapped(
      _bareKeyValuePattern,
      (match) => '${match.group(1)}${match.group(2)}$replacement',
    );
    redacted = redacted.replaceAllMapped(_authorizationBearerPattern, (match) {
      final scheme = match.group(2);
      return '${match.group(1)}${scheme == null ? '' : '$scheme '}$replacement';
    });
    return redacted.replaceAll(_openAiApiKeyPattern, replacement);
  }

  bool _isSensitiveKey(Object? key) {
    if (key == null) {
      return false;
    }
    final normalized = _normalizeKey(key.toString());
    if (_sensitiveExactKeys.contains(normalized)) {
      return true;
    }
    return normalized.endsWith('password') ||
        normalized.endsWith('passphrase') ||
        normalized.endsWith('apikey') ||
        normalized.endsWith('accesstoken') ||
        normalized.endsWith('refreshtoken') ||
        normalized.endsWith('idtoken') ||
        normalized.endsWith('privatekey') ||
        normalized.endsWith('privatekeypem') ||
        normalized.endsWith('cookie') ||
        normalized.endsWith('secret');
  }
}

const _sensitiveExactKeys = {
  'authorization',
  'cookie',
  'setcookie',
  'password',
  'passphrase',
  'privatekey',
  'privatekeypem',
  'apikey',
  'openaiapikey',
  'accesskey',
  'accesstoken',
  'refreshtoken',
  'idtoken',
  'token',
  'secret',
  'clientsecret',
};

final _privateKeyBlockPattern = RegExp(
  r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----',
  multiLine: true,
);

final _cookieHeaderPattern = RegExp(
  r'\b(Cookie|Set-Cookie)(\s*[:=]\s*)([^\r\n]+)',
  caseSensitive: false,
  multiLine: true,
);

final _authorizationBearerPattern = RegExp(
  r'\b(Authorization\s*[:=]\s*)(Bearer|Basic)?\s*([^\s,;]+)',
  caseSensitive: false,
);

final _quotedJsonStringPattern = RegExp(
  '(["\\\'](?:password|passphrase|private[_-]?key(?:[_-]?pem)?|api[_-]?key|openai[_-]?api[_-]?key|access[_-]?token|refresh[_-]?token|id[_-]?token|authorization|cookie|set-cookie|token|secret|client[_-]?secret)["\\\']\\s*:\\s*)(["\\\'])(?:\\\\.|(?!\\2).)*\\2',
  caseSensitive: false,
);

final _bareKeyValuePattern = RegExp(
  r'\b(password|passphrase|private[_-]?key(?:[_-]?pem)?|api[_-]?key|openai[_-]?api[_-]?key|access[_-]?token|refresh[_-]?token|id[_-]?token|token|secret|client[_-]?secret)(\s*[:=]\s*)([^\s,;]+)',
  caseSensitive: false,
);

final _openAiApiKeyPattern = RegExp(r'\bsk-[A-Za-z0-9_-]{16,}\b');

String _normalizeKey(String key) {
  return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
